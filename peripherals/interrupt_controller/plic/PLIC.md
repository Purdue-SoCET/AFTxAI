# PLIC Specification

## 1. Parameters
- **Interrupts**: 31 (Source 0 hardwired to 0)
- **Priority Levels**: 7 (0=disabled, 7=highest)
- **Contexts**: 1 (Hart 0 Machine mode)
- **Bus Interface**: `bus_protocol_if`
- **Trigger Type**: Level-triggered and Edge-triggered supported
- **Clock Domain**: Single shared domain (`clk`, `nrst`)

## 2. Register Map
Base Address: TBD

| Offset | Name | Size | R/W | Description |
|---|---|---|---|---|
| `0x000000-0x00007C` | `PRIORITY[0..31]` | 32b | RW | Priority. `PRIORITY[0]` is RO 0. |
| `0x001000` | `PENDING[0]` | 32b | RO | Bit `i` = interrupt `i` pending. |
| `0x002000` | `ENABLE[0]` | 32b | RW | Bit `i` = interrupt `i` enabled for Context 0. |
| `0x200000` | `THRESHOLD` | 32b | RW | Priority threshold for Context 0. |
| `0x200004` | `CLAIM_COMPLETE` | 32b | RW | R: Claim highest ID. W: Complete ID. |

## 3. Requirements

| ID | Requirement |
|---|---|
| `PLIC-REQ-001` | Source 0 priority reads 0; writes ignored. |
| `PLIC-REQ-002` | Interrupt pending if gateway senses active level/edge and not claimed. |
| `PLIC-REQ-003` | Context 0 interrupted if highest pending & enabled priority > `THRESHOLD`. |
| `PLIC-REQ-004` | Read `CLAIM_COMPLETE` clears corresponding pending bit. |
| `PLIC-REQ-005` | Write ID to `CLAIM_COMPLETE` notifies gateway of completion. |
| `PLIC-REQ-006` | On priority tie, lowest ID wins. |
| `PLIC-REQ-007` | Accesses to unmapped addresses return a bus error. |
| `PLIC-REQ-008` | Registers reset to 0 on `nrst`. |