#!/usr/bin/env bash
set -euo pipefail
 
SRC="${1:-sw/ctest.c}"
NAME="$(basename "${SRC%.*}")"
OUT="${OUT:-build/$NAME}"
MEM_WORDS="${MEM_WORDS:-1024}"
OPT="${OPT:--O1}"
CPU_GENERICS="${CPU_GENERICS:--gMEM_DEPTH=$MEM_WORDS}"
STOP_TIME="${STOP_TIME:-50ms}"
NO_SIM="${NO_SIM:-0}"
 
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
step()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die()   { red "ERROR: $*"; exit 1; }
 
[ -f "$SRC" ] || die "source not found: $SRC"
[ -d rtl ] && [ -d tb ] || die "run from the repository root"
 
CROSS="${CROSS:-}"
if [ -z "$CROSS" ]; then
    for p in riscv64-elf- riscv64-unknown-elf- riscv32-unknown-elf- riscv32-elf-; do
        if command -v "${p}gcc" >/dev/null 2>&1; then CROSS="$p"; break; fi
    done
fi
[ -n "$CROSS" ] || die "no RISC-V cross compiler found (set CROSS=prefix-)"
CC="${CROSS}gcc"
OBJDUMP="${CROSS}objdump"
OBJCOPY="${CROSS}objcopy"
SIZE="${CROSS}size"
ARCH=(-march=rv32i -mabi=ilp32)
 
LIBGCC="$("$CC" "${ARCH[@]}" -print-libgcc-file-name)"
[ -f "$LIBGCC" ] || die "no rv32i/ilp32 libgcc ($LIBGCC); multiplication/division will not link"
case "$LIBGCC" in
    *rv32i/ilp32*) ;;
    *) red "WARNING: libgcc path does not look like rv32i/ilp32: $LIBGCC" ;;
esac
 
mkdir -p "$OUT"
MEM_BYTES=$((MEM_WORDS * 4))
 
step "startup code and linker script"
cat > "$OUT/start.s" <<EOF
    .section .text.start, "ax"
    .globl _start
_start:
    li   sp, $MEM_BYTES
    call main
    add  a0, a0, x0
halt:
    beq  x0, x0, halt
EOF
 
cat > "$OUT/link.ld" <<EOF
ENTRY(_start)
SECTIONS
{
    . = 0;
    .text : { *(.text.start) *(.text .text.*) }
    .rodata : { *(.rodata .rodata.* .srodata .srodata.*) }
    .data : { *(.data .data.* .sdata .sdata.*) }
    .bss : { *(.bss .bss.* .sbss .sbss.* COMMON) }
    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}
EOF
echo "unified memory: $MEM_BYTES bytes (MEM_WORDS=$MEM_WORDS), code+data from 0, stack from $MEM_BYTES down"
 
step "compile ($CC $OPT)"
"$CC" "${ARCH[@]}" "$OPT" -ffreestanding -fno-builtin -fno-jump-tables \
    -fno-tree-loop-distribute-patterns -fstack-usage -Wall -Wextra \
    -nostdlib -nostartfiles -T "$OUT/link.ld" \
    "$OUT/start.s" "$SRC" -lgcc -o "$OUT/$NAME.elf"
mv -f ./*.su "$OUT/" 2>/dev/null || true
"$OBJDUMP" -d -M no-aliases "$OUT/$NAME.elf" > "$OUT/$NAME.dis"
"$OBJDUMP" -t "$OUT/$NAME.elf" | awk '$4==".text" && $2=="g" || $3=="F" {print}' | sort > "$OUT/$NAME.sym" || true
green "ok: $OUT/$NAME.elf"
 
step "check: only supported instructions"
ALLOWED="add sub sll slt sltu xor srl sra or and addi slti sltiu xori ori andi slli srli srai lb lh lw lbu lhu sb sh sw beq bne blt bge bltu bgeu jal jalr lui auipc"
USED="$(awk -F'\t' 'NF>=3 && $1 ~ /^ *[0-9a-f]+:$/ {split($3,a," "); print a[1]}' "$OUT/$NAME.dis" | sort -u)"
BAD=""
for m in $USED; do
    case " $ALLOWED " in
        *" $m "*) ;;
        *) BAD="$BAD $m" ;;
    esac
done
echo "used: $(echo $USED | tr '\n' ' ')"
[ -z "$BAD" ] || { grep -nE "\s($(echo $BAD | tr ' ' '|'))\s" "$OUT/$NAME.dis" | head -20; die "unsupported instructions:$BAD"; }
green "ok: all instructions are supported"
 
step "check: image fits into memory"
IMAGE_END="$("$SIZE" -A -d "$OUT/$NAME.elf" | awk 'NR>2 && $1 ~ /^\./ && $2>0 && $3+$2>m {m=$3+$2} END {print m+0}')"
"$SIZE" -A "$OUT/$NAME.elf" | awk 'NR>2 && $2>0 && $1 ~ /^\.(text|rodata|data|bss)/ {printf "  %-8s %6d bytes\n", $1, $2}'
MAXFRAME="$(cat "$OUT"/*.su 2>/dev/null | awk '{if ($2>m) m=$2} END {print m+0}')"
FREE=$((MEM_BYTES - IMAGE_END))
echo "image ends at $IMAGE_END, free for stack: $FREE bytes (largest frame: $MAXFRAME)"
[ "$IMAGE_END" -le "$MEM_BYTES" ] || die "program does not fit into memory (MEM_WORDS=$MEM_WORDS)"
[ "$FREE" -ge 512 ] || die "less than 512 bytes left for the stack; increase MEM_WORDS"
green "ok"
 
step "hex"
"$OBJCOPY" -O binary -R .bss -R .sbss "$OUT/$NAME.elf" "$OUT/$NAME.bin"
od -An -v -tx4 -w4 "$OUT/$NAME.bin" | tr -d ' ' > "$OUT/$NAME.hex"
echo "$OUT/$NAME.hex ($(wc -l < "$OUT/$NAME.hex") words)"
 
step "expected result (host gcc)"
if [ -n "${EXPECTED:-}" ]; then
    echo "EXPECTED given: $EXPECTED"
else
    command -v cc >/dev/null 2>&1 || die "no host cc; pass EXPECTED=<number>"
    cat > "$OUT/host_main.c" <<'EOF'
#include <stdio.h>
int wren_main(void);
int main(void) { printf("%d\n", wren_main()); return 0; }
EOF
    cc -O1 -Dmain=wren_main -w -c -o "$OUT/host_$NAME.o" "$SRC"
    cc -O1 -w -o "$OUT/host_$NAME" "$OUT/host_$NAME.o" "$OUT/host_main.c"
    EXPECTED="$("$OUT/host_$NAME")"
    echo "EXPECTED = $EXPECTED (0x$(printf '%08X' "$EXPECTED"))"
fi
 
if [ "$NO_SIM" = "1" ]; then
    echo; echo "NO_SIM=1: skipping simulation"
    exit 0
fi
 
step "simulation (tb_cpu_prog)"
WORK="$OUT/ghdl"
mkdir -p "$WORK"
ghdl -i --std=08 --workdir="$WORK" rtl/*.vhd tb/*.vhd
ghdl -m --std=08 --workdir="$WORK" tb_cpu_prog
LOG="$OUT/sim.log"
set +e
timeout 300 ghdl -r --std=08 --workdir="$WORK" tb_cpu_prog \
    -gPROG="$OUT/$NAME.hex" -gEXPECTED="$EXPECTED" $CPU_GENERICS \
    --assert-level=error --ieee-asserts=disable-at-0 --stop-time="$STOP_TIME" > "$LOG" 2>&1
RC=$?
set -e
tail -n 5 "$LOG"
if [ $RC -ne 0 ]; then
    die "simulation failed (exit $RC), log: $LOG; disassembly: $OUT/$NAME.dis"
fi
if grep -q "stop-time" "$LOG"; then
    die "simulation hit --stop-time=$STOP_TIME without halt (log: $LOG)"
fi
green "PASS: $NAME = $EXPECTED"
 