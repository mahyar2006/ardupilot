# EWBH743 development-only review

These drafts describe the EWB-STM32H743-NANO-FULL V6.0 with an STM32H743IIT6, 2 MiB of internal flash, and a 25 MHz HSE crystal. They live outside Waf board discovery. Use them for independent review before on-board testing.

## Initial offline validation

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

## Reproduce the builds on Ubuntu WSL2

Use a fresh checkout on the Linux filesystem to preserve existing worktrees.
The script checks recursive submodule revisions before starting Waf. ChibiOS
configuration resolves `modules/lwip/src/include/compat/posix` even for this
board's USB-only bootloader.

```bash
git clone --branch dev/ewbh743-wsl-debug --single-branch \
  https://github.com/mahyar2006/ardupilot.git "$HOME/ardupilot-ewbh743-review"
cd "$HOME/ardupilot-ewbh743-review"
git submodule sync --recursive
git submodule update --init --recursive --jobs 4
git submodule status --recursive

sudo apt-get update
sudo apt-get install -y build-essential curl python3-venv python3-dev libxml2-dev libxslt1-dev
python3 -m venv .venv-ewbh743
source .venv-ewbh743/bin/activate
python -m pip install 'empy==3.3.4' intelhex lxml pexpect pyserial pymavlink \
  future dronecan numpy pyparsing psutil packaging
```

Select GNU Arm Embedded GCC 10.2.1. If it is already installed, prepend its
`bin` directory to `PATH`. For an x86-64 WSL installation without it, the
following uses the archive and checksum from the repository prerequisite script.

```bash
toolchain_dir="$HOME/.local/opt"
archive=gcc-arm-none-eabi-10-2020-q4-major-x86_64-linux.tar.bz2
mkdir -p "$toolchain_dir"
(
  set -e
  cd "$toolchain_dir"
  curl -fLO "https://firmware.ardupilot.org/Tools/STM32-tools/$archive"
  printf '%s  %s\n' \
    21134caa478bbf5352e239fbc6e2da3038f8d2207e089efc96c3b55f1edcd618 "$archive" \
    | sha256sum -c -
  tar -xjf "$archive"
)
export PATH="$toolchain_dir/gcc-arm-none-eabi-10-2020-q4-major/bin:$PATH"
arm-none-eabi-gcc --version
```

Run the offline build helper from the repository. It stages the two drafts as
`EWBH743-Offline`, builds the matching USB bootloader first, then supplies
`Tools/bootloaders/EWBH743-Offline_bl.bin` while Waf configures and packages
Copter. The helper removes its temporary board files and staged bootloader on
exit. The logs, ELF files, and linker maps stay under
`build/ewbh743-offline-<mode>/`.

```bash
bash docs/EWBH743/build-offline.sh --debug
```

The cloud reproduction of `--debug` used GNU Arm GCC 10.2.1 with effective
`-Og` and debug symbols for both targets. The bootloader was 20,748 bytes
and ArduCopter with MPU6500 was 1,494,168 bytes, within their 128 KiB and
1,664 KiB regions. The combined HEX matched both images and ended below the
parameter sectors. Neither build emitted compiler or linker warnings.

Use `--debug-symbols` to keep normal optimization and add debug information.
These files use temporary APJ ID 65534 and are **development-only and not
approved for flashing**.

## Diagnose communication on the fitted board

- Native USB application CDC is `SERIAL0` on PA11/PA12. The bootloader uses the
  same physical USB connection and a separate `-BL` product name. It speaks the
  bootloader protocol, so a MAVLink heartbeat is expected only after successful
  application startup.
- The CP2104 bridge is `SERIAL1` on PA9/PA10. The application defaults to
  MAVLink2 at 57,600 baud, which corresponds to `SERIAL1_PROTOCOL=2` and
  `SERIAL1_BAUD=57`. Saved parameters can override those defaults. Check the
  bridge's TX/RX jumpers, the host COM port, and the actual saved parameters.
  The current bootloader listens on native USB.
- Verify USB power and enumeration, the HSE and reset behavior, SWD and BOOT0
  recovery, and safe chip-select levels. If the application stops during
  startup, capture its panic message or halt it over SWD. The MPU6500 is the
  only configured IMU. Check its supply and SPI4 WHO_AM_I readback before
  diagnosing a missing heartbeat as a serial configuration fault.
