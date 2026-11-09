# Top-Level Verification

This directory contains the verification environment for the AFT RISC-V SoC top-level integration.

## Directory Structure

* \`tb/\`: Top-level RTL testbench (SystemVerilog / UVM).
* \`sw/\`: Software test programs (C/Assembly) compiled for the RISC-V core, aimed at verifying each memory-mapped peripheral.

## Software Tests
Software tests are designed to be loaded into the SoC memory (e.g., SRAM or ROM) by the testbench, allowing the RISC-V processor to execute them and interact with the peripherals over the bus fabric.
