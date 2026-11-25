#include <stdint.h>

#define N_SW 10u

#ifdef HOST
static uint32_t fake_led, fake_sw;
#define LED fake_led
#define SW fake_sw
#else
#define WREN_REG32(a) (*(volatile uint32_t *)(a))
#define LED WREN_REG32(0x80000000u)
#define SW  WREN_REG32(0x80000004u)
#define IRQ WREN_REG32(0x8000000Cu)
#define IRQ_CLEAR 1u
#define IRQ_SET   2u
#endif

static volatile uint32_t sw_count;
static volatile uint32_t ext_count;
static volatile uint32_t bad;
static volatile uint32_t expect_sw;
static volatile uint32_t noise;

__attribute__((noinline)) static uint32_t mix(uint32_t x)
{
    uint32_t a = x ^ 0x9E3779B9u, b = x * 7u + 3u, c = x >> 3, d = x << 5;
    uint32_t e = a + b, f = c ^ d, g = e - f, h = g | a;
    for (uint32_t i = 0; i < 4; i++) {
        a += h ^ i; b ^= a << 1; c += b >> 2; d ^= c + i;
        e += d; f ^= e >> 3; g += f; h ^= g << 2;
    }
    return a ^ b ^ c ^ d ^ e ^ f ^ g ^ h;
}

#ifndef HOST
__attribute__((interrupt("machine"))) void irq_handler(void)
{
    uint32_t cause;
    __asm__ volatile("csrr %0, mcause" : "=r"(cause));
    if (cause != 0x8000000Bu)
        bad++;
    if (expect_sw) {
        sw_count++;
        expect_sw = 0;
    } else {
        ext_count++;
    }
    noise = mix(noise + cause);
    IRQ = IRQ_CLEAR;
}

static void irq_init(void)
{
    __asm__ volatile("csrw mtvec, %0" : : "r"(irq_handler));
    __asm__ volatile("csrs mie, %0" : : "r"(0x800u));
    __asm__ volatile("csrsi mstatus, 8");
}

static uint32_t sw_phase(void)
{
    uint32_t ok = 1;
    for (uint32_t i = 0; i < N_SW; i++) {
        expect_sw = 1;
        IRQ = IRQ_SET;
        if (expect_sw != 0 || sw_count != i + 1)
            ok = 0;
    }
    return ok;
}
#endif

__attribute__((noinline)) static uint32_t fib(uint32_t n)
{
    return n < 2 ? n : fib(n - 1) + fib(n - 2);
}

__attribute__((noinline)) static uint32_t crunch(uint32_t seed)
{
    uint32_t v[16];
    for (uint32_t i = 0; i < 16; i++) {
        seed = seed * 1103515245u + 12345u;
        v[i] = seed;
    }
    for (uint32_t i = 0; i < 16; i++)
        for (uint32_t j = i + 1; j < 16; j++)
            if (v[j] < v[i]) {
                uint32_t t = v[i];
                v[i] = v[j];
                v[j] = t;
            }
    uint32_t s = 0;
    for (uint32_t i = 0; i < 16; i++)
        s = s * 31u + v[i] / (i + 3u) + v[i] % 97u;
    return s;
}

static uint32_t workload(void)
{
    uint32_t acc = 0x12345678u;
    for (uint32_t r = 0; r < 6; r++) {
        int8_t b = (int8_t)(acc >> 3);
        int16_t h = (int16_t)(acc >> 7);
        acc = acc * 33u + fib(10 + (r & 3));
        acc ^= crunch(acc + r);
        acc += (uint32_t)(int32_t)b * 5u - (uint32_t)(int32_t)h;
        acc = mix(acc);
    }
    return acc;
}

int main(void)
{
    uint32_t ok = 1;
#ifndef HOST
    irq_init();
    ok = sw_phase();
#endif
    LED = 2u;
    uint32_t result = workload();
    LED = 3u;
#ifndef HOST
    for (volatile uint32_t i = 0; i < 400u; i++)
        ;
    if (ext_count != SW || bad != 0 || sw_count != N_SW)
        ok = 0;
#endif
    return (int)(result + (ok ? 0u : 0xBAD00000u));
}