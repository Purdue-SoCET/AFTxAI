# APB4 Interconnect Specification

## Overview
APB4 interconnect system mapping a generic bus protocol to peripherals.
Components:
- `apb_if`: APB4 interface definitions.
- `apb_requester`: Single APB requester converting `bus_protocol_if` signals to APB4.
- `apb_completer`: APB completer converting APB4 signals to `bus_protocol_if`.
- `apb_interconnect`: 1-to-N address decoder and multiplexer.

## 1. Interface (`apb_if`)
**Parameters:**
- `ADDR_WIDTH`: 32 (default)
- `DATA_WIDTH`: 32 (default)

**Signals:**
- `PCLK`, `PRESETn`
- `PADDR` (`ADDR_WIDTH` bits)
- `PPROT` (3 bits)
- `PSEL`
- `PENABLE`
- `PWRITE`
- `PWDATA` (`DATA_WIDTH` bits)
- `PSTRB` (`DATA_WIDTH / 8` bits)
- `PREADY`
- `PRDATA` (`DATA_WIDTH` bits)
- `PSLVERR`

## 2. Modules & Requirements

### 2.1 Requester (`apb_requester`)
Translates upstream `bus_protocol_if` requests to APB4 downstream.
- **Parameters:** None.
- **Requester Count:** Supports 1 requester.
- **Requirements:**
  - `APB-REQ-001`: Converts `bus_protocol_if` read/write requests to APB4 SETUP and ACCESS phases.
  - `APB-REQ-002`: Respects APB4 `PREADY` signal, stalling the upstream `bus_protocol_if` via `request_stall` until `PREADY` is asserted.
  - `APB-REQ-003`: Maps `PSLVERR` to the upstream `bus_protocol_if.error` signal.

### 2.2 Completer (`apb_completer`)
Translates APB4 requests to downstream `bus_protocol_if` peripheral accesses.
- **Parameters:**
  - `ADDR_WIDTH`: 32 (default)
  - `DATA_WIDTH`: 32 (default)
  - `BASE_ADDR`: `0x80000000` (default)
  - `NWORDS`: 4 (default)
- **Requirements:**
  - `APB-COM-001`: Converts APB4 ACCESS phase (`PSEL` & `PENABLE`) to `bus_protocol_if` access.
  - `APB-COM-002`: Handles downstream `request_stall` by holding `PREADY` low.
  - `APB-COM-003`: Error Handling: `PSLVERR` asserts when in the ERROR state or if `request_error` is high. 
  - `APB-COM-004`: `request_error` asserts when `PSEL && (range_error || align_error)`.

### 2.3 Interconnect (`apb_interconnect`)
Decodes addresses from the single requester and routes to `NCOMPLETERS` completers.
- **Parameters:**
  - `NCOMPLETERS`: 2 (default)
  - `COMPLETER_ADDR_BITS`: 16 (default)
  - `BUS_REGION_BEGIN`: `0x80000000` (default)
  - `APB_MAP[NCOMPLETERS]`: `'0` (default)
- **Addressing Scheme:**
  - `COMPLETER_ADDR_BITS` is the address "suffix" that is used within completers.
  - The completer is selected based on the `32 - COMPLETER_ADDR_BITS` prefix.
  - `APB_MAP` provides the 32b addresses consisting of `{prefix, suffix}` for each completer index (i.e., mapping between completer index and its base address).
- **Requirements:**
  - `APB-INT-001`: Asserts the correct `PSEL` based on the address prefix matching `APB_MAP`.
  - `APB-INT-002`: Multiplexes `PRDATA`, `PREADY`, and `PSLVERR` back to the requester from the active completer.
  - `APB-INT-003`: Gracefully handles unmapped addresses by returning an error (`PSLVERR`) or safely defaulting to prevent deadlocks.

## 3. Verification

### 3.1 Test Plan
| Test ID | Description | Requirement IDs |
|---------|-------------|-----------------|
| `T01` | Basic read and write to Completer 0 | `APB-REQ-001`, `APB-COM-001`, `APB-INT-001`, `APB-INT-002` |
| `T02` | Basic read and write to Completer 1 | `APB-REQ-001`, `APB-COM-001`, `APB-INT-001`, `APB-INT-002` |
| `T03` | Back-to-back transactions across different completers | `APB-REQ-001`, `APB-INT-001` |
| `T04` | Transaction with wait states (`request_stall` / `PREADY`) | `APB-REQ-002`, `APB-COM-002` |
| `T05` | Misaligned access to trigger error | `APB-COM-003`, `APB-COM-004` |
| `T06` | Out-of-bounds access to trigger error | `APB-COM-003`, `APB-COM-004` |
| `T07` | Unmapped address handling | `APB-INT-003`, `APB-REQ-003` |

### 3.2 Coverage Bins
- **Address Target:** 
  - Hits to Completer 0.
  - Hits to Completer 1.
  - Out of bounds / Unmapped.
- **Wait States:** 
  - Zero wait states.
  - Single wait state.
  - Multi-cycle wait states.
- **Errors:** 
  - `PSLVERR` generation from align error.
  - `PSLVERR` generation from range error.
- **Transitions:** 
  - Back-to-back writes.
  - Back-to-back reads.
  - Read-after-write.

### 3.3 Makefile Targets
- `lint`: Lints testbench and interface files.
- `sim CFG=<name>`: Runs self-checking simulation.
- `regress`: Runs all configurations.
- `cov`: Generates coverage report.
- `clean`: Removes build directory.
