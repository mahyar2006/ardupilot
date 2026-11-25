# EWBH743 development-only review

These drafts describe the EWB-STM32H743-NANO-FULL V6.0 with an STM32H743IIT6, 2 MiB of internal flash, and a 25 MHz HSE crystal. They live outside Waf board discovery. Use them for independent review before on-board testing.

## Offline validation

The local test build inserted temporary APJ board ID `65534` into isolated copies of both definitions. Obtain a permanent EWB board ID before any installation or distribution. Neither draft assigns the temporary ID.

| Region | Sectors | Address range | Capacity |
| --- | --- | --- | ---: |
| Bootloader | 0 | `0x08000000–0x0801FFFF` | 128 KiB |
| Application | 1–13 | `0x08020000–0x081BFFFF` | 1,664 KiB |
| Parameters | 14–15 | `0x081C0000–0x081FFFFF` | 256 KiB |

The normal application updater excludes sectors 14–15. Bootloader ECC recovery can erase the parameter region on an uncorrectable error. SWD and ROM mass erase are outside the updater's protection. The offline compiler configuration resolved the system clock to 400 MHz, AHB to 200 MHz, and USB to 48 MHz.

GNU Arm GCC 10.2.1 built the bootloader (18,732 B flash, 17,420 B linked RAM before heap) and the draft ArduCopter application (1,322,664 B flash, 117,728 B linked RAM before heap) with no compiler or linker warnings. The build used the schematic-confirmed CP2104 USART1 routes in the application. The bootloader transport was native USB only.

## Hardware review still open

- SPI4 shares the onboard flash on PE4 nCS. The external MPU6500 nCS is proposed on PA4. Both initialize high in firmware. Verify physical bias and MISO release through power-up, reset, and ROM recovery.
- TIM4 outputs on PD12, PD13, PB8, and PB9 remain inactive in the drafts. Check fitted FMC and camera loads, ESC input thresholds, and signal idle states through reset and handoff.
- I²C2 on PH4/PH5 shares the AT24C02 bus. Confirm sensor IDs and addresses, orientation, pull-ups, and rise time. Check proposed serial and RF wiring against the [Phase 3 pin map](../EWBH743_PinMapping.csv).
- Verify crystal startup, native USB power and enumeration, SWD with NRST, BOOT0 and option bytes, and parameter retention during an update on the fitted board.

[Application draft](hwdef.dat) · [Bootloader draft](hwdef-bl.dat)
