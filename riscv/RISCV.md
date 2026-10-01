# RISC-V CPU Specification

## Overview
A single RISC-V core with a 3-stage pipeline that supports the base integer instruction set (RV32I) with a parameterized option for the reduced register set (RV32E). Designed for full tapeout, utilizing standard interfaces and modular blocks.

## System Architecture & Interfaces
- **Bus Protocol**: Use a standard interface (e.g., AXI4-Lite or Wishbone) for memory and memory-mapped peripherals to ensure IP reusability.
- **Boot Address**: Parameterized, defaulting to `0x0000_0000`.
- **Memory Map**: Clearly defined regions for Instruction Memory (ROM/SRAM), Data Memory (SRAM), and Memory-Mapped I/O (MMIO).

## Pipeline Architecture (3-Stage)
The pipeline is divided into three stages to balance logic depth and throughput.

### 1. Instruction Fetch (IF)
- **Program Counter (PC) Logic**: Next PC calculation (PC+4, Branch Target, or Trap Vector).
- **Instruction Fetch**: Interfaces with iCache.
- **Branch Predictor**: Simple static prediction (e.g., backward branches predicted taken, forward predicted not taken) to reduce control hazards.

### 2. Decode & Execute (ID/EX)
- **Control Unit**: Decodes instruction into control signals for the ALU, memory, and writeback.
- **Register File**: 32x32-bit (RV32I) or 16x32-bit (RV32E), parameter-driven. Dual-read, single-write ports.
- **Immediate Generator**: Extracts and sign-extends immediate values based on instruction format (I, S, B, U, J).
- **ALU**: Performs arithmetic, logical, and shift operations.
- **Branch Resolution**: Evaluates branch conditions and calculates target addresses. Triggers a pipeline flush on misprediction.
- **Forwarding Unit**: Bypasses data from the MEM/WB stage to the ALU to resolve data hazards without stalling.
- **Hazard Unit**: Stalls the IF and ID/EX stages on load-use hazards or cache misses.

### 3. Memory & Writeback (MEM/WB)
- **Data Memory Control**: Interfaces with dCache for Load/Store instructions. Handles sign-extension for byte/halfword loads.
- **Writeback Mux**: Selects between ALU result, Memory Read Data, or PC+4 (for JAL/JALR) to write back to the Register File.

## Exceptions and Interrupts (CSRs)
- **Privilege Levels**: Machine mode (M-mode) support required for basic embedded applications and traps.
- **Core CSRs**: Implement minimum required CSRs (`mstatus`, `mepc`, `mcause`, `mtvec`) to handle timer interrupts, external interrupts, and synchronous exceptions (e.g., illegal instruction, ecall).

## Memory Subsystem

### CPU Blocks
- **Datapath**: Integrates the 3-stage pipeline and control logic.
- **Memory Controller**: Arbitrates between iCache and dCache requests, interfacing with the external system bus or main SRAM.

### Cache Specification
- **Split L1 Cache**: Harvard architecture with separate Instruction (iCache) and Data (dCache) caches.
- **Parameters**: Configurable Cache Size, Block/Line Size, and Associativity.
- **Policies**: 
  - **dCache**: Write-back with write-allocate (reduces memory bus traffic).
  - **Replacement**: LRU or Pseudo-LRU for set-associative configurations.

### RAM / Simulation Model
- **SRAM Model**: A behavioral/synthesizable SRAM block used for both simulation and physical implementation.
- Includes initialization support (`$readmemh`) to load hex programs for simulation testbenches.

## Implementation & Verification Notes
- **Interfaces**: SystemVerilog `interface` constructs must be used for Cache-to-CPU and Cache-to-Memory Controller connections (stored in `/include`).
- **Coding Standard**: Pure SystemVerilog, using `always_ff` for sequential logic and `always_comb` for combinational logic.
- **Verification**: UVM testbenches for the full CPU and major blocks. SV assertion-based testbenches for every smaller submodule (e.g., ALU, Predictor).