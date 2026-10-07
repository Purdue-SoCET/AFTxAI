# Dual-Core RISC-V CPU

## ISA Scope

- **Base ISAs:** RV32I and RV32E. Both are supported from **one RTL code base**, selected by a top-level parameter.
  - RV32E has 16 GPRs. Any encoding that references x16–x31 raises an **illegal instruction** exception.
  - Both configurations are regressed.
- **Extension A (atomics):**
  - Instructions: `LR.W`, `SC.W`, `AMOSWAP.W`, `AMOADD.W`, `AMOXOR.W`, `AMOAND.W`, `AMOOR.W`, `AMOMIN.W`, `AMOMAX.W`, `AMOMINU.W`, `AMOMAXU.W`.
  - Enabled by parameter.
  - `aq`/`rl` bits are honored trivially by the in-order, blocking design. Document this argument in the spec.
- **Zicsr, Zifencei, and minimal Machine mode:**
  - CSR instructions: `CSRRW`, `CSRRS`, `CSRRC`, and the immediate forms.
  - CSRs: `mhartid`, `mstatus`, `mtvec`, `mepc`, `mcause`, `mtval`, `misa` (reflects enabled extensions), `mcycle`/`cycle`, `minstret`/`instret` (with high halves).
  - Traps: `ECALL`, `EBREAK`, `MRET`, illegal instruction, instruction-address-misaligned, load/store/AMO address-misaligned, and load/store/AMO access fault (AHB `HRESP` error, unmapped address, or AMO/LR/SC to uncacheable space).
  - **No interrupts in v1.** Structure the trap unit so interrupts (`mie`/`mip`, a timer interrupt) can be added later without restructuring the pipeline.
- **FENCE** is a no-op, because there is nothing to drain in an in-order, blocking design. **FENCE.I** flushes the pipeline and refetches. Instruction-side correctness comes from the iCache participating in coherence (§5.3).
- **Endianness:** little-endian.
- **Toolchain flags:**
  - RV32I build: `-march=rv32ia_zicsr_zifencei -mabi=ilp32`
  - RV32E build: `-march=rv32ea_zicsr_zifencei -mabi=ilp32e`

### Extensibility Requirement (Critical)

The code must make adding RISC-V extensions later (M, C, Zba/Zbb, F, etc.) a **local change**, not a pipeline rewrite:

- **Parameters.** Every extension has an enable parameter, e.g. `EXT_A`, with defaults in `riscv_pkg`. Stubs for `EXT_M` and `EXT_C` exist and default to 0.
- **Decode.**
  - Decode is split into a **base decoder** plus **per-extension decode slices**, each instantiated under `generate if (EXT_x)`.
  - Each slice outputs a common decoded-instruction struct (`decoded_instr_t`) and a `valid`/`illegal` flag.
  - Unrecognized encodings fall through to illegal-instruction.
- **Execution.** Execution operations are a unified enum (`exec_op_t`) in `riscv_pkg`. New functional units, such as a future multiplier/divider, plug in beside the ALU through a defined result-mux and stall/valid handshake.
- **Fetch.** The fetch/PC logic must not hard-code 4-byte instruction alignment in ways that block a future C extension. Document the path to adding a 16-bit fetch alignment.
- **CSRs.** The CSR file is table-driven, so adding a CSR means adding an entry, not new control logic.

---

## Core Microarchitecture

Two identical cores. Each has a `HART_ID` parameter that drives `mhartid`. Both reset to the **same reset vector `0x0000_0000`**, and software diverges on `mhartid`.

### Datapath

The datapath module integrates the 3-stage pipeline and its control logic.

**Pipeline:** `IF` → `ID/EX` → `MEM/WB`

| Stage | Submodules |
|---|---|
| **IF** | PC, instruction fetch (iCache interface), branch predictor |
| **ID/EX** | control unit, register file, immediate generator, ALU, branch resolution, forwarding unit, hazard unit, CSR/trap logic |
| **MEM/WB** | data memory control (dCache interface, load alignment/sign-extension, store byte enables, AMO/LR/SC sequencing), writeback mux |

Pipeline requirements:

- **Branch predictor:** 2-bit saturating counters, plus a BTB so IF can predict a target.
  - Default: 16-entry direct-mapped BTB, parameterized.
  - The prediction is made in IF. The branch is resolved in ID/EX.
  - A misprediction flushes IF, a 1-cycle penalty.
  - `JAL` uses the BTB. `JALR` resolves in ID/EX.
- **Forwarding:** from MEM/WB into ID/EX operands.
  - **Load-use handling Architect decision:** Stall 1 cycle with register-file write-before-read bypass. Forwarding from the dCache through the writeback mux would create a long combinational path that jeopardizes the 100 MHz timing budget.
- **Hazard unit** handles:
  - load-use stalls
  - full-pipeline freeze on iCache/dCache miss or bus wait
  - multi-cycle AMO/LR/SC sequencing
  - flushes on mispredict, trap, `MRET`, and `FENCE.I`
- **Cache hits are single-cycle** for both caches, so the 3-stage pipeline holds without extra stages.
- **Register file:** 32 × 32 (RV32I) or 16 × 32 (RV32E), selected by parameter. x0 is hard-wired to zero.

### Simulation Commit Port

Each core exposes a **commit/retire trace port** in the style of RVFI. It carries:

- PC
- instruction
- rd and rd write data
- memory address, data, and byte mask
- trap flag

The port is guarded by `` `ifdef RISCV_TRACE `` and never synthesized. The verification reference model consumes it for lockstep comparison.

---

## Caches and Memory Controller

### L1 Cache: One Module, Instantiated Four Times

The L1 is a split Harvard design: each core has its own iCache and dCache. A **single cache module** serves all four instances, configured by parameters:

| Parameter | Legal values | Default |
|---|---|---|
| `CACHE_SIZE` (bytes) | power of 2 | 1024 |
| `BLOCK_WORDS` (32-bit words per block) | 1, 2, 4, 8 | 4 (16 B) |
| `ASSOC` | 1 or 2 | 2 |
| `CACHE_TYPE` | `ICACHE` / `DCACHE` (enum in `riscv_pkg`) | — |

Cache requirements:

- **Parameter checks.** Illegal parameter combinations fail at elaboration, using `$error` inside a generate block guarded by `` `ifndef SYNTHESIS ``.
- **Replacement.** 2-way uses true LRU (1 bit per set). Direct-mapped has no replacement state.
- **dCache policy:** write-back, write-allocate, full MESI.
- **iCache policy:** read-only, and holds only **I or S**. It never takes E or M.
- **Flush port.** Each cache has a synthesizable flush port (`flush_req`/`flush_done`). A flush writes back all dirty lines and invalidates.
  - The port is driven from an MMIO cache-control register (§6).
  - The testbench uses it so main memory is coherent before the final memory dump.

### Memory Controller and Coherence Bus

The memory controller arbitrates the four L1 requesters (2× iCache, 2× dCache) and is the **single AHB-Lite master** of the SoC.

- **Arbitration:** round-robin, provably starvation-free.
- **Atomic bus:** exactly **one outstanding, non-split coherence transaction at a time**.
  - A transaction runs from grant through snoop, data, and completion before the next grant.
  - This is the definition of the "atomic coherence bus".
- **Snooping protocol:** MESI.
  - Bus transactions: `BusRd`, `BusRdX`, `BusUpgr`, `Writeback`/`Flush`.
  - Snoops are **broadcast to every cache except the requester**, including the requester's own sibling iCache. This keeps the instruction side coherent with stores from either core.
  - **Architect decision (Snoop hit to M):** Owner writeback followed by a memory read. This avoids the complexity of direct cache-to-cache data forwarding while keeping the memory coherent.
- **Uncacheable accesses** (the MMIO region) bypass the caches and go directly to AHB single transfers. They are serialized through the same arbiter.
- **Block fills and writebacks** use AHB bursts: `INCR4` for 4 words, `INCR8` for 8 words, and `INCR` with a defined length or singles for 1–2 words.
- **AHB `HRESP` errors** propagate back as access faults.
- **State Transition Table (MESI):**

| Current State | Local Event | Next State | Bus Action |
| --- | --- | --- | --- |
| I | Read | S or E (depending on shared line) | BusRd |
| I | Write/AMO | M | BusRdX |
| S | Read | S | None |
| S | Write/AMO | M | BusUpgr |
| E | Read | E | None |
| E | Write/AMO | M | None |
| M | Read/Write/AMO | M | None |

*Snoop Responses:*
| Current State | Bus Event | Next State | Cache Action |
| --- | --- | --- | --- |
| S, E, M | Eviction | I | Writeback (if M) |
| S | BusRd | S | None |
| S | BusRdX/BusUpgr | I | Invalidate |
| E | BusRd | S | Assert Shared |
| E | BusRdX | I | Invalidate |
| M | BusRd | S | Flush to Mem |
| M | BusRdX | I | Flush to Mem |

*iCache uses only the I and S states (read-only).*

### Atomics (A Extension) Implementation

- **AMOs** execute at the dCache once the line is in **M**, obtained via `BusRdX` or `BusUpgr` as needed. The read-modify-write is indivisible: the cache **defers snoop responses** to that line until the AMO completes. This is safe because the bus allows one outstanding transaction.
- **LR.W** sets a per-core reservation on the cache-line address. The reservation is cleared by:
  - a snoop invalidation (`BusRdX`/`BusUpgr`) of that line
  - eviction of that line
  - any `SC.W`
  - a trap
- **SC.W** succeeds only with a valid reservation. It then requires the line in M/E and performs the write. Otherwise it writes rd = 1 and does not store.
- **Uncacheable addresses:** AMO, LR, and SC to uncacheable addresses raise an access fault.
- **Forward progress:** Constrained LR/SC loops (per the ISA spec) make forward progress under round-robin arbitration because wait times are bounded and reservations can only be broken by an actual write or eviction. One core will always win arbitration and complete its SC.

---

## 6. Memory Map and MMIO

The system address space is divided into cacheable memory and uncacheable memory-mapped I/O (MMIO).

| Address Range | Size | Region | Cacheable | Description |
| --- | --- | --- | --- | --- |
| `0x0000_0000` – `0x0FFF_FFFF` | 256 MB | **Main SRAM** | Yes | Execution and data memory. Reset vector is `0x0000_0000`. |
| `0x1000_0000` – `0x1FFF_FFFF` | 256 MB | **MMIO** | No | Uncacheable device region. |

**Cache Control Register (MMIO)**:
- Address: `0x1000_0000`
- Access: Write-only
- Bits `[0]`: Write 1 to flush Core 0 iCache & dCache.
- Bits `[1]`: Write 1 to flush Core 1 iCache & dCache.

---

## SRAM Model (Simulation and Test Only)

- The main SRAM is a **behavioral, synthesizable-style** AHB-Lite slave. It is used for **simulation and testing only** and is **excluded from physical design** (§9).
- **Program loading:** supports `$readmemh` with the hex file path supplied by a parameter or plusarg.
- **Zero-padding:** initialization hex files **must be fully zero-padded to the full SRAM depth**, so that no `X` propagates into the caches on misses or allocations. The program build script performs the padding automatically and verifies the output length.
- **Defense in depth:** the SRAM model zero-initializes before `$readmemh`, and an assertion fires on any `X` or `Z` read from SRAM.
- **Final-state dump:** the SRAM model provides a backdoor task to dump the entire memory contents to a file. This is used for the final-state comparison.

---

## Coding Standards (Mandatory)

These rules apply to all RTL and all verification code unless stated otherwise:

1. **SystemVerilog only** for synthesizable RTL. Testbenches may use full SV/UVM.
2. **No logic in `always_ff`.**
   - `always_ff` blocks contain only reset and `q <= next_q` register assignments.
   - All next-state and output logic lives in `always_comb`.
   - Naming: a register `foo` has its next-state signal `next_foo`.
3. **snake_case only.** This applies to modules, signals, parameters, files, and directories wherever the tools allow. Active-low signals end in `_n`, e.g. `rst_n`.
4. **Reset:** active-low, asynchronous assert, synchronous deassert. A reset synchronizer sits at the cluster top.
5. **One module per file.** The file name equals the module name.
6. **Interfaces:**
   - Each module's port bundles are defined as **SystemVerilog interfaces with modports** in `riscv/include/`.
   - `clk` and `rst_n` remain plain ports.
7. **Package:** **`riscv_pkg.sv`** in `riscv/include/` holds the shared enums, structs, and typedefs: opcodes, `exec_op_t`, `decoded_instr_t`, MESI states, bus commands, cache type, CSR addresses, extension-enable defaults, the memory-map table, etc.
8. **Extensions are enabled only through parameters.** No `` `define ``-based feature switches in RTL. `` `ifdef `` is allowed only for `SYNTHESIS` and `RISCV_TRACE` guards.
9. **Lint gate:** Verilator `--lint-only -Wall` must be clean. Any waiver needs a justification comment and a listing in `docs/lint_waivers.md`.
10. **No latches, no combinational loops, no `initial` blocks in synthesizable RTL**, except the behavioral SRAM, which is simulation-only.
11. **Header comment on every module:** purpose, parameters, interfaces used, and the requirement IDs it implements.

---

## Tool Flow and Physical Design Targets

Pin these exact module versions and record them in `RISCV.md`. Every flow script calls `module load` explicitly.

| Purpose | Module |
|---|---|
| Lint / fast sim | `verilator/5.052` |
| Simulation, UVM, coverage | `siemens/questa/2023.4` |
| RISC-V toolchain | `riscv-gcc/13.2.0` |
| Waveforms | `gtkwave/3.3.124` or `surfer/0.4.0` |
| Synthesis | `cadence/genus/21.17` |
| Logical equivalence | `cadence/confrml/24.10` |
| Place and route | `cadence/innovus/21.17` |
| Extraction | `cadence/quantus/23.11` |
| Static timing sign-off | `cadence/ssv/25.11` (Tempus) |
| DRC/LVS | `cadence/pegasus/23.20` (or `cadence/pvs/23.11`, whichever has the gpdk45 rule decks) |
| PDK | `cadence/gpdk45/6.0` |

If a tool or license fails, the CAD agent tries the next listed version of the same tool before escalating.

### PD Scope and Targets

- **PD top: `riscv_cluster`.** It contains the 2 cores, 4 L1 caches, the memory controller, and the AHB-Lite master port, which is exported as block pins.
- **Excluded from PD:** the SRAM, the AHB fabric, and the test peripherals. They are simulation-level `soc_top` content.
- **Implementation level:** block-level. No I/O pads.
- **Clock:** **100 MHz** (10 ns period).
  - Sign off setup at the slow corner and hold at the fast corner.
  - Setup clock uncertainty is 0.5 ns.
  - Synthesis is over-constrained by about 10% for margin.
- **I/O constraints:** input and output delays of 30% of the period on AHB pins, plus reasonable max transition and max fanout constraints.
- **Cache arrays** synthesize to flops, because there is no SRAM compiler. Report the area impact and flag it if it drives utilization or timing problems.
- **Required PD outputs:**
  - area, power, and timing reports at each step
  - the top critical paths, with an explanation of each
  - DRC/LVS clean
  - LEC passes RTL ↔ synthesized netlist and synthesized ↔ post-route netlist
  - gate-level simulation of the directed test suite on the synthesized netlist, plus a subset with post-route SDF

---

## Verification Requirements

The Verification agent produces `docs/verification_plan.md` during the architecture phase. The plan traces to the requirement IDs in `RISCV.md`.

### Module Level

- **Every RTL module** gets a self-checking testbench with SVA assertions that prints a single `PASS`/`FAIL` line.
- **Protocol and invariant assertions** live in bind files, so system-level simulation reuses them. Examples:
  - one-hot MESI ownership
  - at most one M/E holder per line
  - AHB-Lite protocol rules
  - no X on valid outputs
  - LRU correctness

### Directed Assembly Tests

Tests are written in assembly, built with `riscv-gcc`, converted to fully zero-padded hex, and run on `soc_top`. Coverage must include:

- **Instructions:** every instruction in each enabled ISA configuration.
- **Pipeline:** forwarding paths, load-use, back-to-back branches, BTB aliasing, and predictor saturation behavior.
- **Traps and CSRs:** all trap causes, CSR read/write semantics, and `MRET`.
- **RV32E:** illegal-instruction behavior for x16–x31.
- **Caches:** hit, miss, eviction, dirty writeback, LRU, every `BLOCK_WORDS`/`ASSOC` variant, and the flush port.
- **Coherence:** ping-pong writes, false sharing, read sharing, and self-modifying code with `FENCE.I`.
- **Atomics:** shared counters with each AMO, spinlocks using `AMOSWAP` and LR/SC, and LR/SC contention and reservation-loss cases.
- **System:** MMIO uncacheable accesses, access faults to unmapped space, and AMOs to MMIO faulting.

### Golden Reference

- **Reference model.** The Verification agent writes an **in-house ISA reference model**, in SystemVerilog or C via DPI.
  - It executes each hart's program.
  - It compares against the commit trace port in lockstep.
  - It produces the **expected final memory image**.
- **Cross-check.** A subset of directed tests also has **hand-derived expected memory**, to validate the model itself.
- **Test end.** Each hart writes `tohost`. When both harts are done, the TB triggers the cache flush (§5.1), dumps the SRAM to `final_memory.hex`, and compares it word by word against `expected_memory.hex`. On mismatch, it reports the first N differing addresses.

### UVM Constrained-Random

- **Environment:** a UVM 1.2 environment in Questa with a constrained-random **instruction-stream generator**.
- **Configuration awareness:** the generator respects the enabled ISA configuration (RV32I/E, `EXT_A`).
- **Weighting:** constraints and knobs bias the streams toward hazards, branches, memory traffic, and cache conflicts.
- **Determinism:** dual-core random programs must have **deterministic final memory**. Either each hart writes only private regions, or shared locations are modified only through commutative AMOs, e.g. `AMOADD`/`AMOOR`.
- **Flow:** program generation → assemble → pad → run → compare the reference-model trace and final memory.
- **Seeds:** every seed is logged. A failing seed is minimized and promoted into the directed regression.

### Coverage and Sign-Off Criteria

- **Functional coverage:**
  - every instruction × operand-hazard cross
  - all MESI transitions in the table
  - every bus command × snoop outcome
  - every trap cause
  - BTB hit/miss × prediction outcome
  - every cache parameter configuration
- **Targets:**
  - 100% of planned functional bins (any exclusions justified)
  - ≥ 95% line coverage, ≥ 90% branch coverage, ≥ 85% toggle coverage on RTL
- **Regression:**
  - 100% pass on directed tests in both RV32I and RV32E configurations
  - an agreed random regression, with at least 1,000 seeds per configuration and 0 failures

---

## Repository Structure

```

riscv/
  ├── RISCV.md                 # single source of truth (spec + decision log)
  ├── include/                 # riscv_pkg.sv, *_if.sv interfaces, memory-map table
  ├── rtl/
  │   ├── core/                # datapath, stages, and per-stage submodules
  │   ├── cache/               # parameterized L1 cache
  │   ├── memory/              # memory controller / coherence bus, SRAM model
  │   └── soc/                 # riscv_cluster, soc_top, ahb fabric, peripherals (grows over time)
  ├── verification/
  │   ├── tb/                  # module-level self-checking TBs
  │   ├── assertions/          # SVA bind files
  │   ├── ref_model/           # ISA reference model
  │   ├── uvm/                 # UVM environment and random generator
  │   ├── tests/asm/           # directed assembly tests
  │   └── golden/              # expected memory images
  ├── syn/                     # Genus scripts, SDC, reports
  ├── pd/                      # Innovus, Quantus, Tempus, Pegasus scripts and reports
  ├── scripts/                 # build/pad hex, regression runners, Makefile helpers
  └── docs/
      ├── microarchitecture.md
      ├── verification_plan.md
      ├── lint_waivers.md
      └── feedback.md
```