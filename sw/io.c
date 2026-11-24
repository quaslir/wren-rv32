#include "wren.h"
 
#define UNMAPPED WREN_REG32(WREN_IO_BASE + 0x0Cu)
 
static uint32_t fib(uint32_t n)
{
    uint32_t a = 0;
    uint32_t b = 1;
    while (n--) {
        uint32_t t = a + b;
        a = b;
        b = t;
    }
    return a;
}
 
int main(void)
{
    LED = 0x200u;
    for (;;) {
        uint32_t s = SW & SW_MASK;
        uint32_t n = s & 0x1Fu;
 
        WREN_REG16(HEX_ADDR) = (uint16_t)fib(n);
        WREN_REG8(HEX_ADDR + 2u) = (uint8_t)n;
 
        LED = (LED & 0x200u) | (s & 0x1FFu);
 
        if (UNMAPPED != 0u) {
            LED = LED_MASK;
            HEX = 0xBADBADu;
        }
    }
}
 