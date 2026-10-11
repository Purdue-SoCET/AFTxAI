# AFT SoC: RISC-V CPU Design & Verification Plan

## 1. Directory Mapping (AFT Repository Structure)
- **RTL**:
  - `riscv/rtl/datapath/`: IF, ID/EX, MEM/WB stages, Branch Predictor, ALU, RegFile.
  - `riscv/rtl/caches/`: L1 iCache and dCache modules.
  - `riscv/rtl/memory/`: Bus Controller (arbitration and routing).
- **Verification**:
  - `riscv/verification/tb/`: Module-level testbenches.
  - `riscv/verification/asmFiles/`: Directed `.hex` assembly tests.
  - `riscv/verification/uvm/`: Full UVM environment.

## 2. Interface Definitions
- **Global**: `HCLK` (system clock), `nRST` (async active-low reset).
- **CPU-Cache (`cpu_cache_if`)**: `valid`, `ready` (stall=!ready), `addr[31:0]`, `wdata[31:0]`, `wstrb[3:0]`, `rdata[31:0]`, `error`.
- **Cache-Bus (`cache_bus_if`)**: 32-bit word-by-word protocol. `req`, `gnt`, `addr[31:0]`, `rnw`, `wdata[31:0]`, `rdata[31:0]`, `valid`, `last`, `error`.
- **Bus-AHB (`bus_ahbm_if`)**: `req`, `ack`, `addr[31:0]`, `rnw`, `size[2:0]`, `wdata[31:0]`, `rdata[31:0]`, `error` (AHB Manager implementation is out-of-scope).

## 3. RTL Architecture
### 3.1. 3-Stage Pipeline (No Zicsr / No Interrupts)
- **IF**: PC logic, Branch Predictor (param BHT, 64-entry, 2-bit saturating).
- **ID/EX**: RegFile (RV32I=32, RV32E=16), ImmGen, ALU, Forwarding, Branch Resolution (1-cycle IF flush penalty).
- **MEM/WB**: Memory/Writeback muxes. **Terminal Halt Logic**: Asserts on illegal instruction or AHB error; requires `nRST` to recover.

### 3.2. Memory Subsystem
- **L1 Cache**: Unified parameterized module. dCache = write-back/write-allocate; iCache = read-only. 2-way uses True LRU.
- **Bus Controller**: Fixed dCache > iCache priority. Unbuffered routing to external AHB interface.

## 4. Verification Strategy & Toolchain
- **Toolchain**:
  - Lint / Fast Simulation: `verilator/5.036`
  - UVM / Gate-Level: `cadence/xcelium/23.03`
  - Coverage: `lcov/2.1`
- **Sign-off**: 100% Line, Toggle, FSM, and Functional Coverage.
- **Configurations**: Separate regression sweeps for RV32I and RV32E.
- **Checking Mechanism**: Tests write flags to memory; final memory state is compared against a golden reference.

### 4.1. Module-Level
- **ALU/Decoder**: Opcode execution, illegal instruction trap.
- **Branch Predictor**: 2-bit FSM transitions, BHT aliasing.
- **L1 Cache**: Read/write hits/misses, block fills, write-back evictions, LRU logic.
- **Bus Controller**: Arbitration priority, error propagation.

### 4.2. Directed Assembly Tests
- **Categories**: ISA compliance, control flow (1-cycle mispredict penalty verification), cache eviction (conflict miss).

### 4.3. UVM Constrained Random
- **Architecture**:
  - **Sequence**: Random arithmetic/memory/control instruction generation.
  - **Driver**: Loads `.hex` files into simulated memory.
  - **Monitor/Scoreboard**: Validates final simulated memory state against Golden ISS (e.g., Spike).
- **Coverage**: EX->EX / MEM->EX hazards, load-use stalls, branch aliasing, simultaneous iCache/dCache misses.

### 4.4. Assertion-Based Verification (SVA)
- Bind SVAs to pipeline interfaces to guarantee:
  - Hazard forwarding correctness.
  - 1-cycle flush timing on mispredict.
  - Cache valid/ready handshake invariants.