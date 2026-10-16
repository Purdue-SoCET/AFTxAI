# UVM Verification Roadmap: APB Interconnect

A structured guide for building a UVM testbench for the APB interconnect. The environment utilizes an APB master agent on each upstream port and a reactive APB slave agent on each downstream port. A scoreboard verifies transaction routing, data integrity, and response routing.

## 1. DUT Specification & Requirements
Extract checkable requirements from the DUT specification to define scoreboard checks, assertions, and coverage points:
* **Topology:** The APB interconnect is driven by the AHB-to-APB bridge. This impacts how master traffic is generated (AHB side) and observed (APB side).
* **Address Map:** Base address and size for every slave.
* **Decode Logic:** Correct `PSELx` assertion (mutually exclusive).
* **Transaction Forwarding:** `PADDR`, `PWRITE`, `PWDATA` (and APB4 `PSTRB`, `PPROT`) remain unchanged.
* **Response Muxing:** `PRDATA`, `PREADY`, and `PSLVERR` route exclusively from the selected slave.
* **Unmapped Addresses:** Default slave handles out-of-bounds addresses (e.g., returns `PSLVERR=1`, no `PSELx`).
* **Latency:** Combinational or pipelined behavior (affects scoreboard timing).

## 2. Interfaces and Configuration
* **`apb_if`:** Signals: `pclk`, `presetn`, `paddr`, `psel`, `penable`, `pwrite`, `pwdata`, `pstrb`, `pprot`, `prdata`, `pready`, `pslverr`. Include clocking blocks for synchronous sampling/driving.
* **`apb_agent_cfg`:** Fields: `is_active`, `mode` (MASTER or SLAVE), virtual interface handle.
* **`apb_env_cfg`:** Fields: Number of masters/slaves, address map, and a `decode(addr)` function yielding slave index (-1 if unmapped).

## 3. Transaction Class (`apb_item`)
* **Fields:** `addr`, `write`, `wdata`, `rdata`, `strb`, `prot`, `slverr`.
* **Slave Controls:** `wait_states`.
* **Constraints:**
  * Bias addresses to range boundaries (first, middle, last word).
  * Include unmapped addresses.
  * Constrain `wait_states` (e.g., 0 to N, biased to 0).

## 4. APB Agents

### Master Driver
* **IDLE:** `PSEL=0`, `PENABLE=0`.
* **SETUP:** `PSEL=1`, `PENABLE=0`, drive address, control, and data.
* **ACCESS:** `PENABLE=1`, wait for `PREADY=1`.
* **Complete:** Capture `PRDATA` and `PSLVERR`. Supports back-to-back transfers.

### Reactive Slave Driver
* Awaits SETUP phase for its `PSEL`.
* Pulls response characteristics (`wait_states`, `slverr`) from a slave sequence.
* Holds `PREADY=0` for `wait_states`, then asserts `PREADY=1` alongside `PRDATA` and `PSLVERR`.
* Implements associative array memory for stateful read/write responses.

### Monitor
* Samples completed transfers when `PSEL && PENABLE && PREADY` are high.
* Broadcasts items via `uvm_analysis_port`.

## 5. Sequences
* **`apb_slave_resp_seq`:** Background reactive sequence generating wait states and errors.
* **Master-Side Stimulus:** Because the interconnect sits behind an AHB-to-APB bridge, sequence generation usually targets the AHB agent. The APB master agent may operate in *passive* mode during system-level tests, or active mode for interconnect-only testing.
* **`apb_single_seq`:** Directed single read/write.
* **`apb_rand_seq`:** Fully randomized multi-transfer sequence.
* **`apb_boundary_seq`:** Targets range boundaries (base, base+size-1) and adjacent unmapped boundaries.
* **`apb_unmapped_seq`:** Specifically targets unmapped regions.
* **Virtual Sequence:** Coordinates parallel traffic across all masters.

## 6. Scoreboard
* **Analysis Imports:** Unique imports or an array of `uvm_subscriber` per slave/master.
* **Master Monitor Path:** Decodes address. If unmapped, expects `slverr=1`. If mapped, pushes to the target slave's expected queue.
* **Slave Monitor Path:** Pops expected item, compares `addr`, `write`, `wdata`, `strb`, `prot`.
* **Response Checking:** Ensures master receives the exact `rdata` and `slverr` returned by the slave.
* **End of Test:** `check_phase` verifies all expected queues are empty.

## 7. Protocol Assertions (SVA)
Bind to master and slave ports:
* `$onehot0(psel_vec)` (Interconnect level).
* `psel && !penable |=> penable` (SETUP to ACCESS transition).
* `penable |-> psel`.
* `penable && !pready |=> $stable({paddr, pwrite, pwdata, psel, pstrb, pprot})` (Signal stability during wait states).
* Control signals not X/Z out of reset.

## 8. Test Plan
| Test | Target |
|---|---|
| `sanity_test` | Single R/W per slave, 0 wait states. |
| `boundary_test` | Address decode edges. |
| `unmapped_test` | Default slave error response. |
| `wait_state_test` | Random slave stalls; protocol stability. |
| `slverr_test` | Error propagation to master. |
| `b2b_test` | Back-to-back transfers across different slaves. |
| `reset_test` | Mid-transfer reset and recovery. |
| `full_random_test` | Highly randomized traffic, bulk seed execution. |

## 9. Functional Coverage
* **Cross Coverage:** `slave_idx` x `write` x `wait_states_bin` x `slverr`.
* **Address Bins:** Lower edge, upper edge, middle, unmapped.
* **Transitions:** Same slave vs. switched slave back-to-back.

## 10. Regression and Closure
* **Execution:** Script to run test suite across numerous random seeds.
* **Coverage:** Merge databases, review holes, write targeted sequences.
* **Bug Insertion:** Temporarily modify DUT to prove testbench catches errors.
* **Sign-off:** 100% functional/code coverage, zero UVM errors/warnings.

## Directory Structure
```text
tb/
├── apb_if.sv
├── apb_pkg.sv            # item, cfg, drivers, monitor, sequencer, agent
├── apb_sva.sv            # protocol assertions (bind)
├── env/
│   ├── apb_env_cfg.sv
│   ├── apb_scoreboard.sv
│   ├── apb_coverage.sv
│   └── apb_env.sv
├── seq/
│   ├── apb_slave_resp_seq.sv
│   ├── apb_master_seqs.sv
│   └── apb_vseq.sv
├── tests/
│   ├── base_test.sv
│   └── *_test.sv
└── tb_top.sv
```