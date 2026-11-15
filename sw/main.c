#define OPAQUE(x)  __asm__ volatile ("" : "+r"(x))
#define SHOW(x)    __asm__ volatile ("add x10, %0, x0" :: "r"(x))
#define HALT()     __asm__ volatile ("1: beq x0, x0, 1b"); __builtin_unreachable()

__attribute__((section(".text.start"), noreturn))
void _start(void)
{
    unsigned n = 20;
    OPAQUE(n);

    unsigned a = 0, b = 1, i = 1;
    unsigned done = 0;
    do {
        unsigned t = a + b;
        a = b;
        b = t;
        i = i + 1;
        done = (i == n);
        OPAQUE(done);
    } while (done == 0);

    SHOW(b);
    HALT();
}
