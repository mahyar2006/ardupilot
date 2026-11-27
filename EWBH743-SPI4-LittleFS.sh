#!/usr/bin/env bash
set -euo pipefail
umask 077
case "${1:-}" in
    --check) mode=0; marker=LIVE_BLANK_CHECK_PASS;;
    --apply) mode=1; marker=SPI4_FULL_READBACK_PASS;;
    *) echo "Usage: bash $0 --check|--apply"; exit 2;;
esac
backup=/root/ewbh743-spi4-backup.oQfcaX/spi4-8MiB.bin
printf '%s  %s\n' '9f9b02f5ee6cbef5e018c1ee424095fc21a842ea6968c0d36114b5930dab2ba1' "$backup" | sha256sum -c -
lsusb -d 0483:3748
out=$(mktemp -d /tmp/ewbh743-littlefs.XXXXXX)
echo "Logs: $out"
cd "$out"
cat >spi.tcl <<'TCL'
init
reset halt
if {[lindex [reg pc force] end] != 0x08000db4} {error "STOP: unexpected reset vector"}
if {[lindex [read_memory 0xe000ed14 32 1] 0] & 0x30000} {error "STOP: CPU caches are active"}
# Stop at the reset vector if a spontaneous reset happens during the RAM session.
bp 0x08000db4 2 hw
mmw 0x580244e0 0x11 0
if {([lindex [read_memory 0x580244e0 32 1] 0] & 0x11) != 0x11} {error "GPIO clocks"}
mww 0x58020018 0x10
mmw 0x58020000 0x100 0x200
mww 0x58021018 0x00440010
mmw 0x58021000 0x1110 0x2e20
set words {
0xf3804802 0xf0008808 0x0000b87f 0x24080000 0x4603b570 0x20002108 0x26044a0d 0x2580f44f 0x0f80f013 0x0040ea4f 0x0343ea4f 0x2440bf14 0x0480f44f 0x3901b2c0 0xb2db6194 0x69146196 0xf3c46195 0xea401440 0xd1e90004 0xbf00bd70 0x58021000 0xf44fb510 0x4c051380 0x61a32005 0xffd6f7ff 0xf7ff2000 0x2310ffd3 0xbd1061a3 0x58021000 0xf44f4b0a 0xb2c01280 0x460cb510 0xf7ff619a 0xf3c4ffc5 0xf7ff4007 0xf3c4ffc1 0xf7ff2007 0xb2e0ffbd 0x4010e8bd 0xbf00e7b8 0x58021000 0x4604b5f8 0x4d15460e 0x44264601 0x44252003 0xf7ff4617 0x2000ffdd 0xffa8f7ff 0x2c3fb197 0x782bd807 0xd00f4298 0x22104b0d 0x619a2000 0xf5a4bdf8 0x2b3f3380 0xf5a5d804 0x3bc0437f 0xe7ef781b 0xe7ed23ff 0x35013401 0xd1e242b4 0x22104b03 0x619a2001 0xbf00e7ea 0x24004274 0x58021000 0x681d4b53 0x060cf3c5 0x689fb580 0xf0402e00 0x4b508093 0xf200429d 0x4b4f808f 0x06d8691b 0x808cf140 0x8134f8df 0x3010f8d8 0xf14006d9 0xf44f8085 0x209f1380 0x3018f8c8 0xff64f7ff 0xf7ff4630 0x0204ff61 0xf7ff4630 0x4304ff5d 0xf7ff4630 0x2310ff59 0xf8c80224 0x43043018 0x429c4b3f 0x2403d006 0x605c4b39 0x8f4ff3bf 0xe7febe00 0xff6af7ff 0x0403f010 0x2f01d1f3 0x463ad809 0x5100f44f 0xf7ff4628 0x2800ff87 0x2404bf08 0x4b33e7e8 0xd151429f 0x3380f435 0x4622d14e 0x7180f44f 0xf7ff4628 0x2800ff77 0xf44fd048 0x4e291380 0x61b32006 0xff24f7ff 0x61b32310 0xff42f7ff 0x0003f000 0xd13b2802 0xf1054f25 0x462e0840 0xf1a74629 0xf50709c0 0xf7ff477f 0x2e3fff43 0x5df0d81a 0xf7ff3601 0x4546ff0b 0x4b19d1f7 0xf44f2210 0x619a5600 0xff24f7ff 0xd41307c2 0xd41f0783 0xf44f2201 0x46287180 0xff42f7ff 0xbf082800 0xe7a32407 0x3380f5a6 0xbf942b3f 0x0009f816 0xe7dd20ff 0xd1e53e01 0xe7972408 0xe7952401 0xe7932402 0xe7912409 0xe78f2405 0xe78d2406 0xe78b2407 0x24003000 0x007fe000 0x58020000 0x58021000 0x00ef4017 0x50524731 0x23ff4374 0x00000001 0xf7ff0ff0 0x7474696c 0x7366656c 0x1000e02f 0x00020001 0x00010000 0x00000080 0x000000ff 0x7fffffff 0x000003fe 0x10fcef7f 0x00000100 0x015757de 0xcc00f00f 0xd4fd9cda 0x00000002 0xf7ff0ff0 0x7474696c 0x7366656c 0x1000e02f 0x00020001 0x00010000 0x00000080 0x000000ff 0x7fffffff 0x000003fe 0x10fcef7f 0x00000100 0x015757de 0xcc00f00f 0x50f8090a
}
write_memory 0x24004000 32 $words
set actual [read_memory 0x24004000 32 [llength $words]]
if {[llength $actual] != [llength $words]} {error "incomplete RAM upload"}
foreach got $actual expected $words {
    if {$got != $expected} {error "RAM upload mismatch"}
}

if {([lindex [read_memory 0x58004810 32 1] 0] & 0xfff) != 0xfff} {error "Unexpected IWDG window"}
proc check_block {addr mode} {
    mww 0x24003000 $addr
    mww 0x24003008 $mode
    mww 0x24003004 0xffffffff
    mww 0x58004800 0xaaaa
    resume 0x24004000
    wait_halt 2000
    set rc [lindex [read_memory 0x24003004 32 1] 0]
    if {$rc != 0} {error [format "STOP mode=%x offset=%06x result=%x" $mode $addr $rc]}
}
proc scan {mode} {
    for {set n 0} {$n<1024} {incr n} {
        check_block [expr {$n*8192}] $mode
        if {($n%128)==127} {echo [format "SCAN mode=%d blocks=%d/1024" $mode [expr {$n+1}]]}
    }
}
scan 0
echo LIVE_BLANK_CHECK_PASS
if {$apply} {
    check_block 0 0x50524731
    check_block 65536 0x50524731
    scan 1
    echo SPI4_FULL_READBACK_PASS
}
rbp 0x08000db4
shutdown
TCL
timeout -k 5s 40m openocd -f interface/stlink.cfg -c 'transport select hla_swd' -f target/stm32h7x_dual_bank.cfg \
    -c 'adapter speed 1000; reset_config srst_only srst_nogate connect_assert_srst' \
    -c 'gdb_port disabled; tcl_port disabled; telnet_port disabled' -c "set apply $mode" -f spi.tcl 2>&1 | tee openocd.log
grep -Fx "$marker" openocd.log
