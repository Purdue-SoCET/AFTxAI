# Software Tests

This directory contains the C and Assembly tests executed by the RISC-V core during top-level simulation. 

## Peripheral Test Suites

Tests are organized by the peripheral they target:
* \`digital_io_mux/\`: Pin multiplexer configurations
* \`dma/\`: Direct memory access transfers
* \`ff_ram/\`: Flip-flop based RAM read/write tests
* \`gpio/\`: General-purpose I/O toggling and input reading
* \`i2c/\`: I2C controller transactions
* \`interrupt_controller/\`: CLINT and PLIC interrupt handling
* \`pwm/\`: Pulse-width modulation generation
* \`spi/\`: SPI controller transactions
* \`sram_controller/\`: Off-chip SRAM access
* \`timer/\`: General-purpose timer interrupts and counters
* \`uart/\`: UART serial transmission and reception

## Compilation
Tests should be compiled using the \`riscv-gcc/13.2.0\` toolchain into hex files that the testbench can load into the simulated memory.
