# UVM Roadmap: AHB-Lite Bus Matrix (N×M)

**Goal:** Reusable, parameterized UVM environment for N-manager × M-subordinate AHB-Lite interconnect.
**Strategy:** Isolate protocol → decode → arbitration → full matrix.
**Architecture:** Fully synchronous (single clock domain for all managers and subordinates).
**Toolchain:** Cadence Xcelium 23.03 (simulation, SVA, coverage).

## 0. Specification & Plan
- **DUT Contract:**
  - Configurable N (managers), M (subordinates).
  - Address map: Regions → subordinate index, default behavior.
  - Arbitration policy & burst handling.
  - `HMASTLOCK` behavior & subordinate-side ID.
- **Verification Plan:** Map features to checks (scoreboard/SVA) and coverage points.
- **Scoreboard Strictness:** Define exact order vs. delivery/liveness.
- **Exit:** Vplan reviewed; full feature mapping complete.

## 1. Infrastructure (File Mappings)
- **`bus/ahb/include/ahb_if.sv`:** Interface with `HADDR`, `HTRANS`, `HWRITE`, `HSIZE`, `HBURST`, `HPROT`, `HMASTLOCK`, `HWDATA`, `HRDATA`, `HREADY`, `HREADYOUT`, `HRESP`, `HSEL`.
- **`bus/ahb/verification/ahb_txn.sv`:** Sequence item with `addr`, `write`, `size`, `burst`, `trans`, `lock`, `wdata`, `rdata`, `resp`, `port_id`.
- **`bus/ahb/verification/ahb_addr_map.sv`:** Config object (`decode(addr)`, `is_mapped(addr)`).
- **`bus/ahb/verification/ahb_agent_cfg.sv`:** Role (MANAGER/SUBORDINATE), port index, error/wait-state knobs.
- **`bus/ahb/verification/ahb_env_cfg.sv`:** N, M, agent configs, `ahb_addr_map`.
- **Exit:** Clean compilation; `uvm_config_db` integration complete.

## 2. Reusable AHB-Lite Agent (`bus/ahb/verification/agent/`)
- **Manager Driver:** Pipelined (addr n+1 during data n); handles `HREADY` holds, 1KB boundaries, `BUSY`.
- **Subordinate Responder:** Memory model; wait states (`HREADYOUT`); two-cycle `ERROR`; zero-wait `OKAY` for `IDLE`/`BUSY`.
- **Monitor:** Captures address phase (`HREADY && HTRANS ∈ {NONSEQ, SEQ}`); completes on next `HREADY`.
- **Sequencer:** Base sequences (single R/W, bursts, random).
- **Exit:** 1×1 loopback simulation matches driver intent.

## 3. Protocol Assertions (SVA) (`bus/ahb/include/ahb_sva.sv`)
- Stable address/control during low `HREADY`.
- `ERROR` response is two cycles (`HREADYOUT` low → high, `HRESP=ERROR`).
- `IDLE`/`BUSY` → zero-wait `OKAY`.
- `SEQ` address increments correctly; no 1KB boundary crossings.
- Legal `HTRANS` transitions (no `SEQ` after `IDLE`).
- Liveness (no starvation), burst atomicity, `HMASTLOCK` adherence.
- **Exit:** Assertions pass on known-good 1×1, fail on bad stimulus.

## 4. Bring-Up (1×1) (`bus/ahb/verification/tb/`)
- **Scope:** 1 manager, 1 subordinate.
- **Scoreboard:** Exact match between manager TXN and subordinate TXN; data consistency.
- **Tests:** Directed R/W, sizes, bursts, wait states, errors.
- **Exit:** Clean protocol behavior; agent/SVA trusted.

## 5. Decoder (1×M)
- **Scope:** 1 manager, M subordinates (`bus/ahb/ahb_interconnect/`).
- **Scoreboard:** Route TXNs via `addr_map.decode()`.
- **Tests:** Target all regions, boundaries, unmapped (default `ERROR`), burst crossings.
- **Exit:** 100% correct routing; unmapped addresses properly error.

## 6. Arbiter (N×1)
- **Scope:** N managers, 1 subordinate (`bus/ahb/ahb_interconnect/`).
- **Scoreboard:** Match subordinate TXNs against manager queues.
- **Tests:** Contention, staggered requests, locked transfers, backpressure.
- **Exit:** Per-manager order preserved, no starvation, policy verified.

## 7. Full Matrix (N×M)
- **Scope:** Arrays of interfaces; virtual sequencer.
- **Scoreboard:** Routing logic keyed by `[sub][mgr]`; verify subordinate TXNs and read data returns.
- **Exit:** Clean random N×M traffic across seeds.

## 8. Test Suite (`bus/ahb/verification/tests/`)
- **Scenarios:**
  - Disjoint (mgr N → sub N)
  - Hot-spot (all mgr → sub M)
  - Burst races & contention
  - Backpressure (mid-burst hold)
  - Locked vs normal traffic
  - Unmapped/boundaries
  - Reset mid-traffic
  - Random regression

## 9. Functional Coverage (`bus/ahb/verification/coverage/`)
- **Crosses:** `mgr` × `sub` × `HTRANS` × `HBURST` × `HSIZE` × `HWRITE`.
- **Arbitration:** Contention sets, grant transitions (A→B, A→A).
- **Wait States & Responses:** Wait counts, `OKAY`/`ERROR`.
- **Code Coverage:** Line, toggle, FSM.
- **Exit:** 100% functional/code coverage goals met via Cadence Xcelium; waivers documented.

## 10. Regression & Sign-off
- **Tasks:** Regression scripts (tests × seeds), coverage merge, parameter sweep (N, M, maps).
- **Exit:** Final report, verified vplan, bug log resolved.

## Pitfalls
- Monitor address/data phase overlap misalignment.
- Misuse of `HREADY` vs `HREADYOUT` at subordinates.
- Scoreboard assuming global ordering instead of per-manager ordering.
- Duplicated address maps (must use shared config object).
- Skipping incremental phases (1×1 → 1×M → N×M) and debugging multiple domains simultaneously.