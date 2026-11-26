#!/usr/bin/env bash
# Build the EWBH743 review drafts for offline debugging only.
set -euo pipefail

usage() {
    printf 'Usage: bash docs/EWBH743/build-offline.sh [--debug|--debug-symbols]\n' >&2
    exit 2
}

if (( $# > 1 )); then
    usage
fi
mode=${1:---debug}
case "$mode" in
    --debug|--debug-symbols) ;;
    *) usage ;;
esac

repo=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
cd "$repo"
draft=docs/EWBH743
board=EWBH743-Offline
board_id=65534
hwdef=libraries/AP_HAL_ChibiOS/hwdef/$board
boot_image=Tools/bootloaders/${board}_bl.bin
output="$repo/build/ewbh743-offline-${mode#--}"
jobs=${EWBH743_JOBS:-4}

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

submodules=$(git submodule status --recursive)
if [[ -z "$submodules" || ! -d modules/lwip/src/include/compat/posix ]] ||
   grep -Eq '^[-+U]' <<<"$submodules"; then
    printf '%s\n' "$submodules" >&2
    fail 'Initialize the pinned submodules with: git submodule sync --recursive && git submodule update --init --recursive'
fi

command -v arm-none-eabi-gcc >/dev/null || fail 'Put GNU Arm Embedded GCC on PATH.'
python3 -c 'import em, intelhex, lxml, pexpect, serial' ||
    fail 'Activate the ArduPilot Python environment and install its build dependencies, including empy 3.3.4 and intelhex.'
if [[ -e "$boot_image" || -L "$boot_image" ]]; then
    fail "Move the existing $boot_image aside before running this isolated build."
fi
if grep -Eq "^[^#]+[[:space:]]$board_id([[:space:]]|$)" Tools/AP_Bootloader/board_types.txt; then
    fail "Offline APJ ID $board_id now appears in the board registry."
fi

# Owning the staging directory prevents this script from removing a user's hwdef.
mkdir -- "$hwdef" || fail "Move the existing $hwdef aside before running this isolated build."
staged_boot_image=false
cleanup() {
    if "$staged_boot_image"; then
        rm -f -- "$boot_image"
    fi
    rm -f -- "$hwdef/hwdef.dat" "$hwdef/hwdef-bl.dat"
    rmdir -- "$hwdef"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for file in hwdef.dat hwdef-bl.dat; do
    if grep -Eq '^[[:space:]]*APJ_BOARD_ID[[:space:]]' "$draft/$file"; then
        fail "$draft/$file already has a board ID. Review this offline build workflow before using it."
    fi
    cp -- "$draft/$file" "$hwdef/$file"
    printf '\nAPJ_BOARD_ID %s\n' "$board_id" >> "$hwdef/$file"
done

mkdir -p -- "$output"
printf 'DEVELOPMENT ONLY — NOT APPROVED FOR FLASHING (temporary APJ ID %s).\n' "$board_id"
./waf configure --board "$board" --bootloader "$mode" --Werror --no-submodule-update \
    --out="$output/bootloader" 2>&1 | tee "$output/bootloader-configure.log"
./waf bootloader -j"$jobs" 2>&1 | tee "$output/bootloader-build.log"

# Waf embeds this exact, matching image in the application and combined HEX.
# Noclobber protects existing artifacts if another process used the staging path.
(set -o noclobber; cat "$output/bootloader/$board/bin/AP_Bootloader.bin" > "$boot_image")
staged_boot_image=true
./waf configure --board "$board" "$mode" --Werror --no-submodule-update \
    --out="$output/copter" 2>&1 | tee "$output/copter-configure.log"
./waf copter -j"$jobs" 2>&1 | tee "$output/copter-build.log"

printf 'Offline build outputs: %s\n' "$output"
