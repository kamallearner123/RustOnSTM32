import pypandoc

md = r"""# STM32L476RG LED Blinking with Rust

A step-by-step bare-metal Rust guide for the **NUCLEO-L476RG** development board.

This guide covers the toolchain, project creation, Cargo dependencies, GPIO configuration, linker memory map, compilation, flashing, and troubleshooting.

---

## 1. Hardware and expected result

- Board: **NUCLEO-L476RG**
- MCU: **STM32L476RG**, ARM Cortex-M4F
- Onboard user LED: **LD2**
- LD2 GPIO connection: **PA5**
- LED logic: PA5 HIGH turns LD2 ON; PA5 LOW turns LD2 OFF
- Debug/programming interface: onboard ST-LINK

Use the green user LED marked **LD2**. Do not confuse it with the ST-LINK status LEDs.

## 2. Install the Rust ARM target

Open a terminal:

```bash
rustup target add thumbv7em-none-eabihf
```

The target means:

- `thumb`: ARM Thumb instruction set
- `v7em`: ARMv7E-M architecture, used by Cortex-M4
- `none`: bare-metal target without an operating system
- `eabihf`: hard-float ABI, suitable for the Cortex-M4F

Check the installed target:

```bash
rustup target list --installed
```

## 3. Install probe-rs

`probe-rs` communicates with the ST-LINK debugger and programs the microcontroller.

```bash
cargo install probe-rs-tools --locked
```

Check the installation:

```bash
probe-rs --version
probe-rs list
```

Connect the NUCLEO board to USB. `probe-rs list` should show the connected debug probe.

If the probe is not detected, check the USB cable, USB port, ST-LINK drivers/permissions, and whether another debugging program is using the probe.

## 4. Create the Rust project

```bash
cargo new stm32_led
cd stm32_led
```

The project initially looks like this:

```text
stm32_led/
├── Cargo.toml
└── src/
    └── main.rs
```

We will add a linker memory map, a build script, and Cargo target configuration.

## 5. Configure Cargo.toml

Replace the contents of `Cargo.toml` with:

```toml
[package]
name = "stm32_led"
version = "0.1.0"
edition = "2021"
build = "build.rs"

[dependencies]
cortex-m = "0.7"
cortex-m-rt = "0.7"
panic-halt = "0.2"

stm32l4xx-hal = { version = "0.7.1", features = ["stm32l476", "rt"] }
```

Important: for `stm32l4xx-hal` version `0.7.1`, the feature used for this MCU is `stm32l476`, not `stm32l4x6`.

What the dependencies do:

| Crate | Purpose |
|---|---|
| `cortex-m` | Cortex-M core support and low-level instructions |
| `cortex-m-rt` | Cortex-M startup/runtime and entry-point support |
| `panic-halt` | Stops execution if a panic occurs |
| `stm32l4xx-hal` | Hardware abstraction layer for STM32L4 peripherals |

## 6. Add the memory map

Create `memory.x` in the project root, alongside `Cargo.toml`:

```text
MEMORY
{
    FLASH : ORIGIN = 0x08000000, LENGTH = 1024K
    RAM   : ORIGIN = 0x20000000, LENGTH = 96K
}
```

For this STM32L476RG configuration:

- Flash starts at `0x08000000` and has 1 MiB.
- SRAM1 starts at `0x20000000` and has 96 KiB.
- This minimal memory map uses SRAM1. The MCU also has additional SRAM2; this example does not place sections there.

The linker uses this map to decide where code, constants, initialized data, and other sections reside.

## 7. Add build.rs

Create `build.rs` in the project root:

```rust
fn main() {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();

    println!("cargo:rustc-link-search={manifest_dir}");
    println!("cargo:rerun-if-changed=memory.x");
}
```

This adds the project root to the linker's search path so the embedded runtime linker script can find `memory.x`.

## 8. Configure the linker

Create the Cargo configuration directory and file:

```bash
mkdir -p .cargo
```

Create `.cargo/config.toml`:

```toml
[target.thumbv7em-none-eabihf]
rustflags = [
    "-C", "link-arg=-Tlink.x",
]
```

The `cortex-m-rt` dependency supplies `link.x`. That linker script uses the `memory.x` file to place firmware sections in the MCU's memory regions.

Your project should now look like this:

```text
stm32_led/
├── .cargo/
│   └── config.toml
├── src/
│   └── main.rs
├── Cargo.toml
├── build.rs
└── memory.x
```

## 9. Write the LED program

Replace `src/main.rs` with:

```rust
#![no_std]
#![no_main]

use cortex_m_rt::entry;
use panic_halt as _;

use stm32l4xx_hal::{
    pac,
    prelude::*,
};

#[entry]
fn main() -> ! {
    // 1. Obtain ownership of the STM32 peripheral handles.
    let dp = pac::Peripherals::take().unwrap();

    // 2. Constrain the Reset and Clock Control peripheral.
    let mut rcc = dp.RCC.constrain();

    // 3. Enable the GPIOA bus clock and split GPIOA into pin handles.
    let mut gpioa = dp.GPIOA.split(&mut rcc.ahb2);

    // 4. Configure PA5 as a push-pull digital output.
    let mut led = gpioa.pa5.into_push_pull_output(
        &mut gpioa.moder,
        &mut gpioa.otyper,
    );

    // 5. Repeatedly turn the LED on and off.
    loop {
        led.set_high();
        cortex_m::asm::delay(40_000_000);

        led.set_low();
        cortex_m::asm::delay(40_000_000);
    }
}
```

### Important note about the delay

`cortex_m::asm::delay(n)` is a CPU-cycle-based busy wait, not a calibrated millisecond timer. Its real duration depends on the actual core clock and instruction overhead. The example does not explicitly configure the system clock to 80 MHz, so do not assume that `40_000_000` always equals 500 ms.

The loop should still produce visible ON/OFF intervals. For precise timing, configure the clock and use a hardware timer or a calibrated system tick.

## 10. Understand the important Rust and STM32 concepts

### `#![no_std]`

```rust
#![no_std]
```

A bare-metal microcontroller application normally does not have an operating system. The Rust standard library (`std`) assumes operating-system services. `no_std` makes the application use the smaller `core` library instead.

### `#![no_main]` and `#[entry]`

```rust
#![no_main]

#[entry]
fn main() -> ! {
```

The Cortex-M runtime provides the startup code and calls the function marked with `#[entry]`. The `!` return type means the function never returns.

### PAC and peripheral ownership

```rust
let dp = pac::Peripherals::take().unwrap();
```

PAC means Peripheral Access Crate. It provides access to hardware peripheral registers. `take()` gives the application the peripheral handles while helping prevent multiple safe owners of the same peripheral.

### RCC and AHB2

```rust
let mut rcc = dp.RCC.constrain();
let mut gpioa = dp.GPIOA.split(&mut rcc.ahb2);
```

RCC means Reset and Clock Control. GPIOA is connected to the AHB2 bus. The HAL's `split` method receives the AHB2 clock controller so it can enable the GPIOA clock and create pin handles.

### MODER and OTYPER

```rust
let mut led = gpioa.pa5.into_push_pull_output(
    &mut gpioa.moder,
    &mut gpioa.otyper,
);
```

- `MODER` selects the pin mode: input, output, alternate function, or analog.
- `OTYPER` selects push-pull or open-drain output type.

The HAL method needs mutable access to these register abstractions to configure PA5.

### Setting the output

```rust
led.set_high(); // PA5 HIGH: LD2 ON
led.set_low();  // PA5 LOW: LD2 OFF
```

The HAL exposes typed operations instead of requiring the application to manipulate the GPIO registers directly.

## 11. Compile the firmware

From the project root:

```bash
cargo clean
cargo build --release --target thumbv7em-none-eabihf
```

A successful build should end with a message similar to:

```text
Finished `release` profile [optimized] target(s) in ...
```

The ELF file should be generated at:

```text
target/thumbv7em-none-eabihf/release/stm32_led
```

## 12. Inspect the ELF file if needed

Install GNU binutils:

```bash
sudo apt update
sudo apt install binutils
```

Inspect the ELF program headers:

```bash
readelf -l target/thumbv7em-none-eabihf/release/stm32_led
```

A correctly linked embedded ELF should contain loadable `LOAD` segments. If `probe-rs` reports `No loadable segments were found in the ELF file`, check that:

1. `.cargo/config.toml` is in the project root under `.cargo/`.
2. The target name in the configuration matches the build target exactly.
3. `memory.x` is in the project root.
4. `build.rs` is in the project root and is declared in `Cargo.toml`.
5. The linker argument `-Tlink.x` is being applied.
6. The build is for `thumbv7em-none-eabihf`, not the host target.

Then clean and rebuild.

## 13. Flash and run the firmware

Connect the board over USB and check the probe:

```bash
probe-rs list
```

Program and run:

```bash
probe-rs run \
    --chip STM32L476RG \
    target/thumbv7em-none-eabihf/release/stm32_led
```

Expected result: onboard green LED LD2 turns ON and OFF repeatedly.

`probe-rs run` programs the ELF and starts the target. If the command exits after programming, the target may still be executing; observe the board and use the troubleshooting tests below.

## 14. Troubleshooting

### Problem A: Cargo reports that `stm32l4x6` is not a feature

Use:

```toml
stm32l4xx-hal = { version = "0.7.1", features = ["stm32l476", "rt"] }
```

The feature name is `stm32l476` for this HAL release.

### Problem B: GPIO split expects AHB2, not RCC

Use:

```rust
let mut gpioa = dp.GPIOA.split(&mut rcc.ahb2);
```

Do not pass `&mut rcc` to this version's `split` method.

### Problem C: `into_push_pull_output()` requires two arguments

Use:

```rust
let mut led = gpioa.pa5.into_push_pull_output(
    &mut gpioa.moder,
    &mut gpioa.otyper,
);
```

This HAL version requires the GPIO mode and output-type register handles.

### Problem D: LD2 appears continuously ON

First make the LED change state slowly enough to observe. The original delay of 8,000,000 cycles may produce relatively fast blinking, depending on the clock.

Then isolate GPIO from timing by running two separate tests.

**Test 1 — force LED OFF:**

Replace the loop with:

```rust
loop {
    led.set_low();
}
```

Expected: LD2 remains OFF.

**Test 2 — force LED ON:**

Replace the loop with:

```rust
loop {
    led.set_high();
}
```

Expected: LD2 remains ON.

Interpretation:

| Force OFF test | Force ON test | Interpretation |
|---|---|---|
| OFF | ON | GPIO output behaves as expected; investigate the blink loop and timing |
| ON | ON | Investigate whether the observed LED is LD2, the pin configuration, or the board |
| OFF | OFF | Investigate the pin, board, or LED connection |

After each change, rebuild and flash again. Confirm that you are observing LD2, not an ST-LINK status LED.

### Problem E: Probe not detected

- Confirm the USB cable supports data, not only charging.
- Try another USB port.
- Run `probe-rs list`.
- Check Linux USB permissions and ST-LINK connection.
- Close other tools that may be using the debugger.

## 15. What each tool does

| Tool or file | Responsibility |
|---|---|
| Rust compiler | Compiles Rust source code |
| Cargo | Manages dependencies and build process |
| `thumbv7em-none-eabihf` | Selects the ARM Cortex-M4F target |
| PAC | Provides peripheral register access |
| HAL | Provides higher-level peripheral APIs |
| `cortex-m-rt` | Provides Cortex-M startup and runtime |
| `memory.x` | Defines Flash and RAM regions |
| `link.x` | Controls embedded linking and section placement |
| `build.rs` | Adds the memory-map directory to the linker search path |
| ST-LINK | Debug/programming hardware on the NUCLEO board |
| `probe-rs` | Communicates with the probe and flashes firmware |

## 16. Recommended exercises

Complete these in order:

| Exercise | Concept learned |
|---|---|
| 1. Force LED ON | GPIO output HIGH |
| 2. Force LED OFF | GPIO output LOW |
| 3. Blink LED | Repeated execution and timing |
| 4. Change blink interval | Delay and clock relationship |
| 5. Read a push button | GPIO input |
| 6. Button controls LED | Input/output interaction |
| 7. Alternate two LEDs | Multiple GPIO pins |
| 8. Use a hardware timer | Timer configuration |
| 9. Use an external interrupt | EXTI and NVIC |
| 10. Control LED brightness | PWM |

## 17. Key embedded Rust concepts to master

Before moving to I2C, SPI, UART, and CAN, understand:

1. `no_std` and `no_main`.
2. Cortex-M startup and vector table.
3. PAC versus HAL.
4. Peripheral ownership and Rust borrowing.
5. RCC and peripheral clock enabling.
6. GPIO registers: MODER, OTYPER, OSPEEDR, PUPDR, and IDR/ODR.
7. Linker scripts and the microcontroller memory map.
8. Flash, SRAM, stack, and static data.
9. Busy-wait delays versus hardware timers.
10. Debugging and inspecting firmware with probe-rs.

**Completion criterion:** The firmware compiles for the ARM target, the ELF contains loadable segments, probe-rs programs the STM32L476RG, and LD2 visibly turns ON and OFF at a repeatable interval.
"""

output_path = "/mnt/data/STM32L476RG_Rust_LED_Blinking_Guide.md"
pypandoc.convert_text(md, "md", format="md", outputfile=output_path, extra_args=["--standalone"])
print(f"Created: {output_path}")

