# RISC-V Core & L1 Cache Specification

## 1. Core Architecture Overview
### 1.1. ISA & Capabilities
- **Base ISA:** Parameterized for `RV32I` or `RV32E`.
- **Extensions:** Base I/E only.
  - *Unsupported:* `Zicsr`, `M` extension, interrupts, virtual memory/TLBs.
  - All addresses are treated as physical.
- **Memory Accesses:** All loads and stores are assumed to be naturally aligned (hardware ignores the bottom two bits of the address).
- **Error Handling:** The core halts execution upon encountering an illegal instruction.

### 1.2. Global Signals & Parameters
- **Clock:** Single clock domain (`HCLK`) for the entire core and cache subsystem.
- **Reset:** Asynchronous, active-low.
- **Boot Address:** Parameterized, default `0x0000_0000`.

---

## 2. Pipeline Datapath (3-Stage)
The core implements a strict 3-stage pipeline.
- **Stall Behavior:** A global pipeline stall is triggered on any cache miss (iCache or dCache).

### Stage 1: Instruction Fetch (IF)
- **Program Counter (PC)** logic.
- **Instruction Fetch** (interfaces with iCache).
- **Branch Predictor:** 
  - Algorithm: 2-bit saturating bimodal counter.
  - Structure: Parameterized Branch History Table (BHT), default 64 entries.
  - Indexing: Lower bits of the PC.

### Stage 2: Instruction Decode & Execute (ID/EX)
- **Register File:** Sized based on RV32I (32) or RV32E (16).
- **Immediate Generator.**
- **ALU.**
- **Hazard & Forwarding Units:** Resolves data hazards and bypasses data to the ALU.
- **Branch Resolution:** Evaluates branch targets and conditions.
  - *Verification Note:* Mispredictions incur a strict **1-cycle penalty** (flushes the IF stage).

### Stage 3: Memory & Writeback (MEM/WB)
- **Data Memory Access** (interfaces with dCache).
- **Writeback Mux:** Selects ALU result, memory read data, or PC+4 to write to the Register File.

---

## 3. L1 Cache Subsystem
### 3.1. Module Architecture
- **Design:** A single L1 cache SystemVerilog module, instantiated twice (once for iCache, once for dCache).
- **Parameters:**
  - `CACHE_SIZE`: Total capacity in bytes (must be a power of 2).
  - `BLOCK_SIZE`: Words per line (must be a power of 2, maximum of 8 words).
  - `ASSOCIATIVITY`: 1 (Direct Mapped) or 2 (2-way Set Associative).
  - `CACHE_TYPE`: Boolean/Enum to prune write logic for the iCache.

### 3.2. Interfaces
- **CPU-to-Cache:** Standard `valid` / `ready` / `addr` / `rdata` / `wdata` / `wstrb` (byte enables) handshake.
- **Cache-to-Bus-Controller:** Simple internal handshaking protocol (not AHB). Data width is 32 bits. Cache lines (up to 8 words) are transferred word-by-word.

### 3.3. Cache Policies
- **dCache (Data):** Write-back, write-allocate. Uses basic Valid and Dirty bits (No MESI protocol/coherency).
- **iCache (Instruction):** Read-only. Uses Valid bits only.
- **Replacement Policy:** True LRU (Least Recently Used) for the 2-way set associative configuration.

---

## 4. Bus Controller
A dedicated Bus Controller arbitrates cache misses and unifies the Harvard caches into a single stream.

### 4.1. Architecture & Arbitration
- **Role:** Merges iCache and dCache requests, handing them off to an external AHB Manager.
- **Arbitration:** Fixed priority. The dCache strictly wins arbitration if both caches miss simultaneously.
- **Buffering:** Strictly unbuffered. The cache and pipeline remain stalled until the memory transaction is fully completed by the AHB Manager.

### 4.2. Interfaces & Error Handling
- **Cache-Facing:** Uses the simple 32-bit word-by-word internal protocol.
- **Fabric-Facing:** Connects to an external AHB Manager (which handles the translation to actual AHB `INCR` bursts).
- **Error Handling:** If the AHB Manager reports a bus error during a cache fill or eviction, the Bus Controller permanently halts the core.