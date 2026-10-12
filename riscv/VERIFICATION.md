# RISC-V CPU Verification Guide

This document outlines the verification methodology, execution instructions, and future roadmap for the AFT RISC-V SoC (RV32I/E) core.

## 1. Methodology

The current verification strategy relies on **directed bare-metal C tests** executed on the RTL via the Cadence Xcelium simulator. 

### Architecture
- **No Standard Library:** The tests are compiled with `-ffreestanding` and `-nostdlib`. 
- **Bootstrapping:** A custom `crt0.s` initializes the stack pointer (`sp`) and jumps to `main()`. A custom linker script (`link.ld`) maps the `.text`, `.data`, and `.bss` sections to fit within our 8KB memory constraint.
- **Memory Model:** The testbench (`ahb_memory.sv`) implements a zero-wait-state combinational AHB RAM. 
- **Self-Checking C Code:** The C programs calculate expected results and compare them dynamically. To avoid GCC optimizing away the logic, critical variables are marked `volatile`.

### The "Magic Write" Termination
Since the CPU has no operating system to return to, we use a memory-mapped peripheral approach to signal test completion:
1. The C program finishes its checks.
2. If all checks pass, it returns `0x600D` (GOOD). If it fails, it returns a specific error code (e.g., `0xBAD0` or an isolated checkpoint ID).
3. `crt0.s` takes the return value in register `a0` and stores it into the absolute memory address `0x1000`.
4. `ahb_memory.sv` snoops the AHB bus. If it sees a write request to address `0x1000`, it intercepts the payload.
5. The testbench prints `SUCCESS` or `FAILURE` and calls `$finish;` to halt the simulation.

---

## 2. Running the Tests

To compile a test and run the RTL simulation, use the environment modules available on the system.

### Step 1: Load Toolchains
```bash
module load riscv-gcc/13.2.0
module load cadence/xcelium/23.03
```

### Step 2: Compile the C Program
Compile your target C file (e.g., `bitwise_alu.c` or `matrix_mult.c`) into an ELF binary:
```bash
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -O1 \
  -T riscv/verification/cFiles/link.ld \
  riscv/verification/cFiles/crt0.s \
  riscv/verification/cFiles/bitwise_alu.c \
  -o bitwise_alu.elf
```

### Step 3: Generate the Hex Payload
Extract the binary data into a 32-bit aligned hex file that Verilog's `$readmemh` can ingest:
```bash
riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=4 bitwise_alu.elf mem.hex
```

### Step 4: Run the Simulation
Execute the testbench in Xcelium. The testbench automatically loads `mem.hex` into the AHB RAM.
```bash
xrun -64bit -timescale 1ns/1ps \
  riscv/include/*.sv \
  riscv/rtl/datapath/*.sv \
  riscv/rtl/caches/*.sv \
  riscv/rtl/memory/*.sv \
  riscv/rtl/*.sv \
  riscv/verification/tb/ahb_memory.sv \
  riscv/verification/uvm/tb_top.sv
```

*Note: You can check `mem_out.hex` after the simulation to inspect the final state of the memory.*

---

## 3. Future Verification Roadmap

While the directed C tests prove the pipeline, ALU, and basic cache operations function correctly, the design requires rigorous verification sign-off before synthesis and tape-out. 

### Outstanding Verification Tasks:
1. **UVM Constrained Random Verification:**
   - Establish a UVM environment in `riscv/verification/uvm/`.
   - Implement AHB monitors and drivers.
   - Build a reference model/scoreboard (or integrate an ISS like Spike) to verify deep architectural edge cases.
   - Generate sequences for random pipeline stalls, bus backpressure, and instruction streams.

2. **SystemVerilog Assertions (SVA) & Formal:**
   - Bind SVA checkers to the AHB interfaces to ensure protocol compliance (e.g., `HTRANS`, `HREADY` relationships).
   - Write invariants for the L1 cache state machines (valid/dirty bit coherence) and pipeline forwarding hazard logic.

3. **Linting and Static Analysis:**
   - Run Verilator or Spyglass linting over the entire `riscv/rtl` directory to catch unintended latches, combinational loops, width mismatches, and coding style violations.

4. **Interrupt and Exception Handling:**
   - Develop verification tests for external interrupts (PLIC) and timer/software interrupts (CLINT).
   - Verify pipeline flushing, CSR (Control and Status Register) writes, and context switching accuracy during trap handling.

5. **Coverage Signoff:**
   - Define functional coverage groups for the instruction set (ISA).
   - Collect Code, Toggle, and FSM coverage using Xcelium (`xrun -coverage all`).
   - Close all coverage holes to reach the 100% tape-out target.