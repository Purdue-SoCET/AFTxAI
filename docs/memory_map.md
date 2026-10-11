# Memory Map

- All addresses are 32-bit physical byte addresses. Ranges are inclusive.
- Each region is an address window starting at **Base Address**. **Address Range** gives the number of words the slave actually implements. The rest of each window is reserved, and software must not access it.
- Reset PC: `0x0000_8400`

## AHB

| Region             | Base Address  | Address Range (Words)    |
|--------------------|---------------|--------------------------|
| Unmapped           | `0x0000_0000` | —                        |
| Boot ROM           | `0x0000_0400` | 1,024 (`ROM_N_WORDS`)    |
| On-chip RAM        | `0x0000_8400` | 4,096 (`FF_RAM_N_WORDS`) |
| Off-chip SRAM      | `0x0002_0000` | 524,288 (`SRAM_N_WORDS`) |
| APB Bridge         | `0x8000_0000` | See APB                  |
| DMA                | `0x9000_1000` | 5                        |
| UART               | `0x9000_2000` | 4                        |
| CLINT              | `0x9001_0000` | 8,192                    |
| PLIC               | `0xA000_0000` | 16,777,216               |
| Printer (sim only) | `0xB000_0000` | 1                        |
| Unmapped           | `0xC000_0000` | —                        |

## APB

| Peripheral | Base Address  | Address Range (Words)  |
|------------|---------------|------------------------|
| GPIO0      | `0x8000_0000` | 8                      |
| GPIO1      | `0x8000_0100` | 8                      |
| GPIO2      | `0x8000_0200` | 8                      |
| GPIO3      | `0x8000_0300` | 8                      |
| PWM0       | `0x8000_1000` | 6                      |
| Timer0     | `0x8000_2000` | 20 (2 × `TIMER_CC_CHANNELS` + 4) |
| SPI0       | `0x8000_4000` | 8                      |
| I2C0       | `0x8000_5000` | TBD                    |
| I/O Mux    | `0x8000_6000` | 1–2                    |
| GPIOBOOT   | `0x8000_7000` | 8                      |
| Unmapped   | `0x9000_0000` | —                      |

Parameterized word counts show their default values.