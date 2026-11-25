#!/usr/bin/env bash
# Runs every testbench in tb/ with GHDL (VHDL-2008).
# Exit code is non-zero if analysis fails or any testbench fails.
# Logs: $LOG_DIR/<name>.log (default /tmp).
# Program testbenches (tb_cpu_io, tb_cpu_irq) need a compiled hex and EXPECTED:
# they are run by io.sh and irq.sh, not here.
set -uo pipefail   # no -e: failures are counted, not fatal
cd "$(dirname "$0")"

LOG_DIR="${LOG_DIR:-/tmp}"
mkdir -p "$LOG_DIR"

SKIP=(tb_cpu_prog tb_cpu_io tb_cpu_irq)

rm -f work-obj08.cf
if ! ghdl -i --std=08 rtl/*.vhd tb/*.vhd; then
    echo "FAIL  ghdl -i (import/analysis)"
    exit 1
fi

pass=0; fail=0; failed=()

run() {
    local name="$1" logname="$2"; shift 2
    local log="$LOG_DIR/$logname.log"
    local rc reason=""
    if ! ghdl -m --std=08 "$name" > "$log" 2>&1; then
        reason="elaboration"
    else
        timeout 60 ghdl -r --std=08 "$name" --ieee-asserts=disable-at-0 --assert-level=error --stop-time=10ms "$@" >> "$log" 2>&1
        rc=$?
        if [ "$rc" -eq 124 ]; then
            reason="timeout"
        elif [ "$rc" -ne 0 ]; then
            reason="exit $rc"
        elif grep -q 'simulation stopped by --stop-time' "$log"; then
            reason="stop-time"
        fi
    fi
    if [ -z "$reason" ]; then
        echo "PASS  $name $*"; pass=$((pass + 1))
    else
        echo "FAIL ($reason)  $name $*  (log: $log)"; fail=$((fail + 1)); failed+=("$logname")
    fi
}

skipped() {
    local x
    for x in "${SKIP[@]}"; do
        [ "$x" = "$1" ] && return 0
    done
    return 1
}

for tb in $(grep -hoP '^entity\s+\K\w+' tb/*.vhd); do
    if skipped "$tb"; then
        echo "SKIP  $tb"
        continue
    fi
    run "$tb" "$tb"
done

if grep -qP '^entity\s+tb_cpu_prog\b' tb/*.vhd; then
    run tb_cpu_prog tb_cpu_prog_main -gPROG=sw/main.hex -gEXPECTED=6765
fi

echo "-----"
echo "passed: $pass, failed: $fail"
[ "$fail" -gt 0 ] && echo "failed: ${failed[*]}"
[ "$fail" -eq 0 ]