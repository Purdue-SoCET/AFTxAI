# PLIC Verification Testplan

## 1. Objectives
Verify the Platform-Level Interrupt Controller (PLIC) based on the specification (`PLIC.md`).

## 2. Requirements Mapping

| Requirement ID | Description | Strategy | Covergroup |
|---|---|---|---|
| `PLIC-REQ-001` | Source 0 priority reads 0; writes ignored. | `plic_sanity_test`: Write non-zero to `PRIORITY[0]`, read back and verify 0. | `cg_priority_reg` |
| `PLIC-REQ-002` | Interrupt pending if gateway senses active level/edge and not claimed. | `irq_trigger_seq`: Assert `irq_source[i]`, read `PENDING` to ensure bit is set. | `cg_pending_reg` |
| `PLIC-REQ-003` | Context 0 interrupted if highest pending & enabled priority > `THRESHOLD`. | `plic_sanity_test`: Enable IRQ, set priority > threshold, assert source, verify `irq_target` goes high. | `cg_irq_target` |
| `PLIC-REQ-004` | Read `CLAIM_COMPLETE` clears corresponding pending bit. | `plic_sanity_test`: Read claim register, verify returned ID, read `PENDING` to ensure bit cleared. | `cg_claim` |
| `PLIC-REQ-005` | Write ID to `CLAIM_COMPLETE` notifies gateway of completion. | `plic_sanity_test`: Write back ID, assert `irq_source`, verify gateway can re-trigger. | `cg_complete` |
| `PLIC-REQ-006` | On priority tie, lowest ID wins. | `plic_priority_tie_test`: Set same priority for multiple enabled sources, assert both, verify `CLAIM_COMPLETE` returns lowest ID. | `cg_priority_tie` |
| `PLIC-REQ-007` | Accesses to unmapped addresses return a bus error. | `plic_unmapped_test`: Read/Write to invalid addresses, check `bus.error == 1`. | `cg_bus_error` |
| `PLIC-REQ-008` | Registers reset to 0 on `nrst`. | `plic_sanity_test`: Check default values of `PRIORITY`, `ENABLE`, `THRESHOLD` upon reset. | `cg_reset` |

## 3. UVM Environment Architecture
- `bus_agent`: Active agent to drive and monitor the register interface (`bus_protocol_if`).
- `irq_agent`: Active agent to drive IRQ sources and monitor target interrupt (`plic_if`).
- `plic_scoreboard`: Shadow registers predicting target interrupt behavior and register state.
- `plic_env`: Encapsulates agents and scoreboard.
- Tests: `plic_sanity_test`, etc.