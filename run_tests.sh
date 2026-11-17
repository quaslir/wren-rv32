#!/usr/bin/env bash
cd "$(dirname "$0")"

rm -f work-obj08.cf
ghdl -i --std=08 rtl/*.vhd tb/*.vhd

pass=0; fail=0; failed=()

run() {
    local name="$1"; shift
    if ghdl -m --std=08 "$name" >/dev/null 2>&1 &&
       ghdl -r --std=08 "$name" --ieee-asserts=disable-at-0 "$@" > "/tmp/$name.log" 2>&1; then
        echo "PASS  $name $*"; pass=$((pass + 1))
    else
        echo "FAIL  $name $*  (лог: /tmp/$name.log)"; fail=$((fail + 1)); failed+=("$name")
    fi
}

for tb in $(grep -hoP '^entity\s+\K\w+' tb/*.vhd); do
    [ "$tb" = tb_cpu_prog ] && continue
    run "$tb"
done

run tb_cpu_prog -gPROG=sw/main.hex  -gEXPECTED=6765
run tb_cpu_prog -gPROG=sw/fib.hex   -gEXPECTED=6765
run tb_cpu_prog -gPROG=sw/magic.hex -gEXPECTED=6765

echo "-----"
echo "passed: $pass, failed: $fail"
[ $fail -eq 0 ]