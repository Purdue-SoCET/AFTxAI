# SRAM Controller Specification

## 1. Overview
Off-chip asynchronous SRAM controller. It connects to the system via the generic `bus_protocol_if` and bridges to two external SRAM chips sharing a 16-bit data bus.

## 2. Parameters
- **`ADDR_WIDTH`**: 19 (Default). Width of the external address bus.
- **`WAIT_CYCLES`**: 2 (Default). Number of active cycles applied per 16-bit SRAM access to accommodate asynchronous timing.

## 3. Memory Map
- **Base Address:** `0x0002_0000`
- **End Address:** `0x0021_FFFF`
- **Size:** 2 MiB (2^19 × 4 B)

## 4. Interfaces

### 4.1. System Interface
- **Clocks & Resets:** `HCLK` (system clock) and `nRST` (active-low asynchronous reset).
- **Bus Interface:** Uses `bus_protocol_if` comprising the following handshake signals:
  - `valid`, `ready`, `write`, `wdata`, `rdata`, `addr`, `strobe`, `error`.
  - Bridges to AHB upstream.
  - The `error` signal is never asserted by the SRAM controller.

### 4.2. External SRAM Interface
- **`addr`**: `ADDR_WIDTH`-bit address bus (shared).
- **`wdata` / `rdata`**: 16-bit shared data bus.
- **`pad_oe`**: IO pad enable for bidirectional data lines (`1` = read/input/High-Z, `0` = write/output/drive).
- **Control Signals (Active-Low):**
  Each of the two chips (Chip 0 and Chip 1) receives its own dedicated set of 5 control signals:
  - `ce_n`: Chip Enable
  - `oe_n`: Output Enable
  - `we_n`: Write Enable
  - `ub_n`: Upper Byte Enable
  - `lb_n`: Lower Byte Enable

## 5. Behavior & Timing

### 5.1 Address Mapping
- The `addr` signal from `bus_protocol_if` represents the byte offset address from the base address.
- Since the two external SRAM chips share the same address bus and sequentially map halves of a 32-bit word, the external `addr` port maps to the word address: `bus_protocol_if.addr[ADDR_WIDTH+1 : 2]`.

### 5.2 Access Sequencing
- A single 32-bit system access is split into two sequential 16-bit external accesses:
  - **Access 1:** Chip 0 is enabled to handle the lower 16 bits.
  - **Access 2:** Chip 1 is enabled to handle the upper 16 bits.
- **Partial Accesses:** 
  - Supports partial word accesses using the 4-bit `strobe` signal.
  - `strobe[1:0]` map to Chip 0's `ub_n` and `lb_n`.
  - `strobe[3:2]` map to Chip 1's `ub_n` and `lb_n`.
  - If a partial access targets only the upper 16 bits (e.g., `strobe[1:0]` is 0), **Access 1 to Chip 0 is skipped**. Only the necessary accesses are executed.

### 5.3 Data Path Holding Register
- During read operations, a holding register must capture and store the lower 16 bits from Chip 0 during Access 1. 
- This ensures the full 32-bit `rdata` can be presented to the system interface at the completion of Access 2.

### 5.4 Wait States and Granular Signaling
- Asynchronous SRAMs require proper setup and hold times. Each external 16-bit access is divided into a 3-phase granular state machine:
  1. **Setup Phase (1 cycle):** Drive `addr`, data (if writing), and assert `ce_n`. Keep `we_n`/`oe_n` deasserted.
  2. **Active Phase (`WAIT_CYCLES` cycles):** Assert `we_n` (for writes) or `oe_n` (for reads) and wait using `digital_lib/counter.sv`.
  3. **Hold Phase (1 cycle):** Deassert `we_n`/`oe_n` while holding `addr`, data, and `ce_n` stable.

## 6. Requirements

| Req ID | Description | Test ID |
| --- | --- | --- |
| **SRAM-REQ-001** | The module shall interface to upstream via `bus_protocol_if` (`valid`, `ready`, `write`, `wdata`, `rdata`, `addr`, `strobe`, `error`). | T01 |
| **SRAM-REQ-002** | The module shall map `bus_protocol_if.addr[ADDR_WIDTH+1 : 2]` to the external `addr` pins. | T02 |
| **SRAM-REQ-003** | A full 32-bit access shall be sequenced as Access 1 (Chip 0, lower 16 bits) then Access 2 (Chip 1, upper 16 bits). | T03 |
| **SRAM-REQ-004** | A read operation shall use a holding register to sample Access 1 data and return the full 32-bits upon Access 2 completion. | T04 |
| **SRAM-REQ-005** | The module shall map `strobe[1:0]` to Chip 0 byte enables and `strobe[3:2]` to Chip 1 byte enables. | T05 |
| **SRAM-REQ-006** | The module shall skip Access 1 or Access 2 if their respective `strobe` bits are deasserted. | T06 |
| **SRAM-REQ-007** | The module shall execute a 3-phase timing per access: 1-cycle setup, `WAIT_CYCLES` active pulse, and 1-cycle hold, using `digital_lib/counter.sv`. | T07 |
| **SRAM-REQ-008** | The module shall never assert the `error` signal on `bus_protocol_if`. | T08 |