# SRAM Controller Specification

## 1. Overview
Off-chip asynchronous SRAM controller. It connects to the system via the generic `bus_protocol_if` and bridges to two external SRAM chips sharing a 16-bit data bus.

## 2. Memory Map
- **Base Address:** `0x0002_0000`
- **End Address:** `0x0021_FFFF`
- **Size:** 2 MiB (2^19 × 4 B)

## 3. Interfaces

### 3.1. System Interface
- Uses `bus_protocol_if` (bridges to AHB upstream).
- Supports partial word accesses using the `strobe` signal.

### 3.2. External SRAM Interface
- **`addr`**: 19-bit parameterized address bus (shared).
- **`wdata` / `rdata`**: 16-bit shared data bus.
- **`pad_oe`**: IO pad enable for bidirectional data lines (`1` = read/input/High-Z, `0` = write/output/drive).
- **Control Signals (Active-Low):**
  Each of the two chips (Chip 0 and Chip 1) receives its own dedicated set of 5 control signals:
  - `ce_n`: Chip Enable
  - `oe_n`: Output Enable
  - `we_n`: Write Enable
  - `ub_n`: Upper Byte Enable
  - `lb_n`: Lower Byte Enable

## 4. Behavior & Timing
- **Access Sequencing:** A single 32-bit system access is split into two sequential 16-bit external cycles.
  - *Cycle 1:* Chip 0 is enabled to handle the lower 16 bits.
  - *Cycle 2:* Chip 1 is enabled to handle the upper 16 bits.
- **Asynchronous Timing:** To accommodate asynchronous SRAM timing, the controller uses a parameterized wait-state timer (instantiated from `digital_lib`) to hold the `bus_protocol_if` bus access open for the required SRAM access duration.