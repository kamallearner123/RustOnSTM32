
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

    // 1. Acquire STM32 hardware peripherals
    let dp = pac::Peripherals::take().unwrap();

    // 2. Obtain access to RCC
    let mut rcc = dp.RCC.constrain();

    // 3. Enable GPIOA clock and split GPIOA into pins
    let mut gpioa = dp.GPIOA.split(&mut rcc.ahb2);

    // 4. Configure PA5 as push-pull output
    let mut led = gpioa.pa5.into_push_pull_output(
        &mut gpioa.moder,
        &mut gpioa.otyper,
    );

    // 5. Continuously blink LED
    loop {

        // LED ON
        led.set_high();

        cortex_m::asm::delay(8_00_000);

        // LED OFF
        led.set_low();

        cortex_m::asm::delay(8_00_000);
    }
}

