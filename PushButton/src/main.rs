
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

    // 1. Acquire STM32 peripherals
    let dp = pac::Peripherals::take().unwrap();

    // 2. Configure RCC
    let mut rcc = dp.RCC.constrain();

    // 3. Enable GPIOA clock
    let mut gpioa = dp.GPIOA.split(&mut rcc.ahb2);

    // 4. Enable GPIOC clock
    let mut gpioc = dp.GPIOC.split(&mut rcc.ahb2);

    // 5. Configure PA5 as LED output
    let mut led = gpioa.pa5.into_push_pull_output(
        &mut gpioa.moder,
        &mut gpioa.otyper,
    );

    // 6. Configure PC13 as button input
    // Internal pull-up resistor enabled
    let button = gpioc.pc13.into_pull_up_input(
        &mut gpioc.moder,
        &mut gpioc.pupdr,
    );

    // 7. Monitor button continuously
    loop {

        // Button pressed = LOW
        if button.is_low() {

            led.set_high();

        } else {

            led.set_low();
        }
    }
}

