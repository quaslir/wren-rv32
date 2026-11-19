#include <stdint.h>

#define NOINLINE __attribute__((noipa))

NOINLINE int opaque(int x)
{
    return x;
}

NOINLINE int fib(int n)
{
    if (n < 2) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

NOINLINE int sum_bytes_signed(int start, int step)
{
    signed char buf[16];
    int v = start;
    for (int i = 0; i < 16; i++) {
        buf[i] = (signed char)v;
        v += step;
    }
    int s = 0;
    for (int i = 0; i < 16; i++) {
        s += buf[i];
    }
    return s;
}

NOINLINE int sum_bytes_unsigned(int start, int step)
{
    unsigned char buf[16];
    int v = start;
    for (int i = 0; i < 16; i++) {
        buf[i] = (unsigned char)v;
        v += step;
    }
    int s = 0;
    for (int i = 0; i < 16; i++) {
        s += buf[i];
    }
    return s;
}

NOINLINE int sum_halves(int start, int step)
{
    short sh[8];
    unsigned short uh[8];
    int v = start;
    for (int i = 0; i < 8; i++) {
        sh[i] = (short)v;
        uh[i] = (unsigned short)v;
        v += step;
    }
    int s = 0;
    for (int i = 0; i < 8; i++) {
        s += sh[i];
        s ^= uh[i];
    }
    return s;
}

NOINLINE int mul_div(int a, int b)
{
    int p = a * b;
    int q = p / (b - 3);
    int r = p % 11;
    unsigned u = (unsigned)p / 7u;
    return p + q + r + (int)u;
}

NOINLINE int op_add(int a, int b) { return a + b; }
NOINLINE int op_sub(int a, int b) { return a - b; }
NOINLINE int op_xor(int a, int b) { return a ^ b; }

NOINLINE int call_indirect(int sel, int a, int b)
{
    int (*fn)(int, int);
    if (sel == 0) {
        fn = op_add;
    } else if (sel == 1) {
        fn = op_sub;
    } else {
        fn = op_xor;
    }
    return fn(a, b);
}

NOINLINE int classify(int x)
{
    switch (x & 7) {
    case 0: return 11;
    case 1: return -22;
    case 2: return 333;
    case 3: return x << 3;
    case 5: return x >> 2;
    case 6: return (int)((unsigned)x >> 4);
    default: return 7;
    }
}

NOINLINE int compares(int a, int b)
{
    unsigned ua = (unsigned)a;
    unsigned ub = (unsigned)b;
    int r = 0;
    if (a < b) r |= 1;
    if (ua < ub) r |= 2;
    if (a >= b) r |= 4;
    if (ua >= ub) r |= 8;
    if (a == b) r |= 16;
    if (a != b) r |= 32;
    return r;
}

NOINLINE uint32_t big_constants(uint32_t x)
{
    x ^= 0x12345678u;
    x += 0x80000000u;
    x = (x << 7) | (x >> 25);
    x -= 0xDEADBEEFu;
    return x;
}

NOINLINE int depth(int n)
{
    volatile int local[4];
    local[0] = n;
    local[3] = n * 3;
    if (n == 0) {
        return local[3];
    }
    return depth(n - 1) + local[0] + local[3];
}

int main(void)
{
    int a = opaque(13);
    int b = opaque(-7);
    uint32_t acc = 0;

    acc = acc * 31u + (uint32_t)fib(12);
    acc = acc * 31u + (uint32_t)sum_bytes_signed(a * 9, 23);
    acc = acc * 31u + (uint32_t)sum_bytes_unsigned(a * 9, 23);
    acc = acc * 31u + (uint32_t)sum_halves(-30000 + a, 9001);
    acc = acc * 31u + (uint32_t)mul_div(a * 1000, b);
    acc = acc * 31u + (uint32_t)call_indirect(0, a, b);
    acc = acc * 31u + (uint32_t)call_indirect(1, a, b);
    acc = acc * 31u + (uint32_t)call_indirect(2, a, b);
    for (int i = -4; i < 12; i++) {
        acc = acc * 31u + (uint32_t)classify(a * i + b);
    }
    acc = acc * 31u + (uint32_t)compares(a, b);
    acc = acc * 31u + (uint32_t)compares(b, a);
    acc = acc * 31u + (uint32_t)compares(a, a);
    acc = acc * 31u + big_constants((uint32_t)(a * b));
    acc = acc * 31u + (uint32_t)depth(6);

    return (int)(acc & 0x7FFFFFFFu);
}