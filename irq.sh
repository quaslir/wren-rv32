#!/usr/bin/env bash
set -euo pipefail

SRC=${1:-sw/irq.c}
MEM_WORDS=${MEM_WORDS:-1024}
N_RUNS=${N_RUNS:-3}
NAME=$(basename "$SRC" .c)
OUT=build/$NAME

if command -v riscv64-elf-gcc >/dev/null; then
    CROSS=riscv64-elf
else
    CROSS=riscv64-unknown-elf
fi

mkdir -p "$OUT"

echo "== startup code and linker script"
cat > "$OUT/start.s" <<EOF
    .section .text.start
    .globl _start
_start:
    li sp, $((MEM_WORDS * 4))
    call main
    add a0, a0, x0
halt:
    beq x0, x0, halt
EOF

cat > "$OUT/link.ld" <<EOF
ENTRY(_start)
SECTIONS
{
    . = 0;
    .text : { *(.text.start) *(.text*) }
    .rodata : { *(.rodata*) *(.srodata*) }
    .data : { *(.data*) *(.sdata*) }
    .bss : { *(.bss*) *(.sbss*) *(COMMON) }
    _end = .;
}
EOF

echo "== compile ($CROSS-gcc -O1, rv32i_zicsr)"
$CROSS-gcc -march=rv32i_zicsr -mabi=ilp32 -O1 -fno-jump-tables -fno-tree-loop-distribute-patterns \
    -ffreestanding -nostdlib -nostartfiles -T "$OUT/link.ld" \
    -o "$OUT/$NAME.elf" "$OUT/start.s" "$SRC" -lgcc

echo "== check: only supported instructions"
USED=$($CROSS-objdump -d -M no-aliases "$OUT/$NAME.elf" | awk -F'\t' 'NF >= 3 { split($3, a, " "); print a[1] }' | sort -u)
echo "used:" $USED
SUPPORTED="add addi and andi auipc beq bge bgeu blt bltu bne csrrc csrrci csrrs csrrsi csrrw csrrwi jal jalr lb lbu lh lhu lui lw mret or ori sb sh sll slli slt slti sltiu sltu sra srai srl srli sub sw xor xori"
for i in $USED; do
    if ! grep -qw "$i" <<< "$SUPPORTED"; then
        echo "FAIL: unsupported instruction $i"
        exit 1
    fi
done
echo "ok"

echo "== check: image fits into memory"
END=$((0x$($CROSS-nm "$OUT/$NAME.elf" | awk '$3 == "_end" { print $1 }')))
LIMIT=$((MEM_WORDS * 4 - 512))
echo "image ends at $END, limit $LIMIT"
if [ "$END" -gt "$LIMIT" ]; then
    echo "FAIL: image too large"
    exit 1
fi

echo "== hex"
$CROSS-objcopy -O binary -j .text -j .rodata -j .data "$OUT/$NAME.elf" "$OUT/$NAME.bin"
python3 - "$OUT/$NAME.bin" "$OUT/$NAME.hex" <<'EOF'
import sys
data = open(sys.argv[1], 'rb').read()
data += b'\0' * (-len(data) % 4)
with open(sys.argv[2], 'w') as f:
    for i in range(0, len(data), 4):
        f.write('%08x\n' % int.from_bytes(data[i:i + 4], 'little'))
print(sys.argv[2], '(%d words)' % (len(data) // 4))
EOF

echo "== expected result (host gcc)"
gcc -DHOST -O1 -o "$OUT/${NAME}_host" -x c - <<EOF
#include <stdio.h>
#define main wren_main
#include "$PWD/$SRC"
#undef main
int main(void) { printf("%d\n", wren_main()); return 0; }
EOF
EXPECTED=$("$OUT/${NAME}_host")
echo "EXPECTED = $EXPECTED"

echo "== analyze"
WORK=build/ghdl
mkdir -p "$WORK"
GH="--std=08 --workdir=$WORK"
ghdl -i $GH rtl/*/*.vhd tb/tb_cpu.vhd tb/tb_cpu_irq.vhd

echo "== simulation without external interrupts (tb_cpu_prog)"
ghdl -m $GH tb_cpu_prog >/dev/null
ghdl -r $GH tb_cpu_prog -gPROG="$OUT/$NAME.hex" -gEXPECTED="$EXPECTED" -gMEM_DEPTH="$MEM_WORDS" \
    --ieee-asserts=disable-at-0 --assert-level=error

echo "== simulation with random button presses (tb_cpu_irq)"
ghdl -m $GH tb_cpu_irq >/dev/null
for seed in $(seq 1 "$N_RUNS"); do
    ghdl -r $GH tb_cpu_irq -gPROG="$OUT/$NAME.hex" -gEXPECTED="$EXPECTED" -gMEM_DEPTH="$MEM_WORDS" \
        -gSEED="$seed" --ieee-asserts=disable-at-0 --assert-level=error
done
echo "PASS: $NAME"