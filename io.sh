#!/usr/bin/env bash
set -euo pipefail
 
SRC="${1:-sw/io.c}"
NAME="$(basename "${SRC%.*}")"
OUT="build/$NAME"
MEM_WORDS="${MEM_WORDS:-1024}"
 
[ -d rtl ] && [ -d tb ] || { echo "run from the repository root"; exit 1; }
 
EXPECTED=0 NO_SIM=1 MEM_WORDS="$MEM_WORDS" ./ctest.sh "$SRC"
 
printf '\n\033[1m== simulation (tb_cpu_io)\033[0m\n'
WORK="$OUT/ghdl"
mkdir -p "$WORK"
ghdl -i --std=08 --workdir="$WORK" rtl/*/*.vhd tb/*.vhd
ghdl -m --std=08 --workdir="$WORK" tb_cpu_io
LOG="$OUT/io_sim.log"
set +e
timeout 300 ghdl -r --std=08 --workdir="$WORK" tb_cpu_io \
    -gPROG="$OUT/$NAME.hex" -gMEM_DEPTH="$MEM_WORDS" \
    --assert-level=error --ieee-asserts=disable-at-0 --stop-time=50ms > "$LOG" 2>&1
RC=$?
set -e
tail -n 4 "$LOG"
if [ $RC -ne 0 ] || grep -q "stop-time" "$LOG"; then
    printf '\033[31mFAIL: %s (log: %s, disassembly: %s)\033[0m\n' "$NAME" "$LOG" "$OUT/$NAME.dis"
    exit 1
fi
printf '\033[32mPASS: %s\033[0m\n' "$NAME"
 