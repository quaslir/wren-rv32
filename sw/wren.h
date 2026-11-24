#ifndef WREN_H
#define WREN_H
 
#include <stdint.h>
 
#define WREN_IO_BASE   0x80000000u
 
#define WREN_REG32(addr) (*(volatile uint32_t *)(addr))
#define WREN_REG16(addr) (*(volatile uint16_t *)(addr))
#define WREN_REG8(addr)  (*(volatile uint8_t *)(addr))
 
#define LED_ADDR (WREN_IO_BASE + 0x00u)
#define SW_ADDR  (WREN_IO_BASE + 0x04u)
#define HEX_ADDR (WREN_IO_BASE + 0x08u)
 
#define LED WREN_REG32(LED_ADDR)
#define SW  WREN_REG32(SW_ADDR)
#define HEX WREN_REG32(HEX_ADDR)
 
#define LED_MASK 0x3FFu
#define SW_MASK  0x3FFu
#define HEX_MASK 0xFFFFFFu
 
#endif
 