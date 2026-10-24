# I2C Controller Specification

## Overview
APB-attached I2C **controller** (drives SCL, issues START/STOP). The block does not implement its own APB logic: it reuses `apb_completer` from the APB4 interconnect, so all I2C logic sits behind a `bus_protocol_if`.

```
apb_if ──► apb_completer ──bus_protocol_if──► i2c_regs ◄──► i2c_engine ──► i2c_if (SCL / SDA)
```

Components:
- `i2c_if`: I2C pin interface (open-drain SCL/SDA, interrupt).
- `i2c_regs`: Register file. `bus_protocol_if` peripheral; no knowledge of I2C timing.
- `i2c_engine`: SCL generation, START/STOP/byte sequencing, ACK handling. No bus knowledge.
- `i2c`: Top level. Instantiates `apb_completer`, `i2c_regs`, and `i2c_engine`.

**In scope:** controller mode, 7-bit addressing (address byte is sent as ordinary write data), Standard (100 kHz) and Fast (400 kHz) mode via a programmable prescaler, repeated START, target clock stretching, one interrupt output.

**Out of scope:** target mode, multi-controller arbitration, 10-bit addressing, FIFOs/DMA, pad cells and tri-state (`1'bz`) nets, input synchronizers (provided by the digital I/O mux).

## 1. Interfaces

### 1.1 Pin interface (`i2c_if`)
**Parameters:** None.

**Signals** (direction from the I2C block's side):
- `scl_o` (out, 1): Always `0` (open drain).
- `scl_oe` (out, 1): `1` pulls SCL low, `0` releases it (pull-up gives `1`).
- `scl_i` (in, 1): SCL line value, already synchronized to `PCLK`.
- `sda_o` (out, 1): Always `0` (open drain).
- `sda_oe` (out, 1): `1` pulls SDA low, `0` releases it.
- `sda_i` (in, 1): SDA line value, already synchronized to `PCLK`.
- `irq` (out, 1): Interrupt, active high, level.

### 1.2 Bus interface (`bus_protocol_if`)
The existing shared interface in `bus/generic/bus_protocol_if.sv` is used as-is (not redefined here). `i2c_regs` connects to the `peripheral_vital` modport; `apb_completer` drives the `protocol` modport.

**Parameters:**
- `ADDR_WIDTH`: 32 (default)
- `DATA_WIDTH`: 32 (default)

**Signals used** (`peripheral_vital`, direction from `i2c_regs`' side):
- `wen` (in): Write request.
- `ren` (in): Read request.
- `addr` (in, `ADDR_WIDTH` bits): **Offset** address. `apb_completer` drives `PADDR - BASE_ADDR`.
- `wdata` (in, `DATA_WIDTH` bits)
- `strobe` (in, `DATA_WIDTH / 8` bits): Byte enables (from `PSTRB`).
- `rdata` (out, `DATA_WIDTH` bits): Passed straight through to `PRDATA`.
- `error` (out)
- `request_stall` (out): High inserts APB wait states (holds `PREADY` low).

**Not used:** the hint signals (`is_burst`, `burst_type`, `burst_length`, `secure_transfer`, modport `peripheral_hint`). `apb_completer` ties them to `0`.

**Note:** `bus_protocol_if` carries no clock or reset. `i2c_regs` takes `PCLK` and `PRESETn` from the top level (`apb.PCLK`, `apb.PRESETn`).

## 2. Modules & Requirements

### 2.1 Top (`i2c`)
Connects the APB4 completer to the I2C register file and engine.
- **Parameters:**
  - `BASE_ADDR`: `0x80005000` (default, "I2C0" in `docs/memory_map.md`)
  - `NWORDS`: 6 (fixed by the register map in 2.2)
- **Ports:** `apb_if` (completer modport), `i2c_if`.
- **Requirements:**
  - `I2C-TOP-001`: Instantiates `apb_completer #(.BASE_ADDR(BASE_ADDR), .NWORDS(6))` and one `bus_protocol_if` between its `protocol` modport and `i2c_regs`' `peripheral_vital` modport. No other module in the block touches APB signals.
  - `I2C-TOP-002`: Range and alignment errors are handled entirely by `apb_completer` (`APB-COM-004`); such accesses never assert `wen`/`ren`. `i2c_regs` decodes only the word index of the offset address, `addr[4:2]`.
  - `I2C-TOP-003`: One clock domain (`PCLK`) and one asynchronous active-low reset (`PRESETn`), both taken from `apb_if`. SCL is an ordinary output generated from `PCLK`.
  - `I2C-TOP-004`: **Dependency.** The current `apb_completer` drives `PSLVERR` only from `request_error` and its ERROR state (`APB-COM-003`); it does not forward `bus_protocol_if.error`. For the register-level errors in `I2C-REG-004` to reach `PSLVERR`, `apb_completer` must also assert `PSLVERR` when `bus.error` is high during the ACCESS phase. Until that change lands, those accesses complete with `PSLVERR = 0` but still have no side effects.

### 2.2 Registers (`i2c_regs`)
Translates `bus_protocol_if` accesses into register reads/writes and engine commands.
- **Parameters:** None.
- **Register Map:**

| Offset | Name | Access | Reset | Fields |
|--------|------|--------|-------|--------|
| `0x00` | `CTRL`     | RW       | `0x0` | `[0] EN`, `[1] IRQ_EN` |
| `0x04` | `PRESCALE` | RW       | `0x3` | `[15:0]` quarter-SCL-period length minus 1 (see 2.3) |
| `0x08` | `TXDATA`   | RW       | `0x0` | `[7:0]` byte to send on the next WRITE command |
| `0x0C` | `RXDATA`   | RO       | `0x0` | `[7:0]` byte received by the last READ command |
| `0x10` | `CMD`      | WO       | —     | `[0] START`, `[1] STOP`, `[2] WRITE`, `[3] READ`, `[4] NACK` |
| `0x14` | `STATUS`   | RO / W1C | `0x0` | `[0] TIP`, `[1] BUS_BUSY`, `[2] RX_NACK`, `[3] DONE` (W1C) |

- **Requirements:**
  - `I2C-REG-001`: Zero wait states: `request_stall` is held at `0`. `apb_completer` asserts `wen`/`ren` only during the APB ACCESS phase, so `rdata` and `error` must be valid combinationally in the same cycle as `ren`/`wen`, and a write takes effect on the `PCLK` edge that ends that cycle.
  - `I2C-REG-002`: Writes are masked by `strobe` (little-endian byte lanes). Unused bits read as `0` and ignore writes. `strobe = 0` is a legal no-op.
  - `I2C-REG-003`: A write to `CMD` with `strobe[0] = 1` launches exactly one engine command for one cycle; `CMD` holds no state.
  - `I2C-REG-004`: Error Handling: `error` asserts (no state change, `rdata = 0`) on:
    - read of `CMD`, or write to `RXDATA`;
    - write to `CMD` while `TIP = 1` or while `CTRL.EN = 0`;
    - write to `CMD` with both `WRITE` and `READ` set, or with none of `START`/`STOP`/`WRITE`/`READ` set;
    - write to `CTRL`, `PRESCALE`, or `TXDATA` while `TIP = 1`;
    - write to `PRESCALE` with a value below 3 (`I2C-ENG-007`).
  - `I2C-REG-005`: `STATUS.DONE` is sticky and cleared by writing `1` to bit 3. Other `STATUS` bits ignore writes. If a DONE event and a clear occur in the same cycle, the event wins.
  - `I2C-REG-006`: `irq = STATUS.DONE & CTRL.IRQ_EN`, driven from flops or simple AND logic.

### 2.3 Engine (`i2c_engine`)
Executes one command at a time on the I2C bus.
- **Parameters:** None.
- **Timing:** Each SCL period is four quarter phases of `PRESCALE + 1` `PCLK` cycles each (period = `4 × (PRESCALE + 1)` cycles, plus any clock stretching). For a target SCL frequency: `PRESCALE = PCLK / (4 × f_SCL) − 1`.
- **Command Sequencing:** A command runs its parts in this order, skipping any bit that is not set: `START` → `WRITE` or `READ` → `STOP`.
- **Requirements:**
  - `I2C-ENG-001`: START: with SCL high, SDA is pulled low; SCL is pulled low one quarter period later. If the bus is already owned (`BUS_BUSY = 1`), a repeated START is generated by first releasing SDA and SCL.
  - `I2C-ENG-002`: STOP: with SCL low, SDA is pulled low; SCL is released; SDA is released one quarter period after SCL reads high.
  - `I2C-ENG-003`: WRITE: shifts `TXDATA` out MSB first over 8 SCL pulses, then releases SDA for a 9th pulse and samples the target's ACK into `STATUS.RX_NACK` (`1` = NACK).
  - `I2C-ENG-004`: READ: releases SDA for 8 SCL pulses, samples SDA in the middle of each SCL high phase (MSB first) into `RXDATA`, then drives `CMD.NACK` on the 9th pulse (`0` = ACK, `1` = NACK).
  - `I2C-ENG-005`: SDA changes only while SCL is low (except START and STOP).
  - `I2C-ENG-006`: Clock stretching: after releasing SCL, the engine waits until `scl_i` reads `1` before counting the high phase.
  - `I2C-ENG-007`: The minimum `PRESCALE` is 3. The I/O mux round trip is 3 `PCLK` cycles (1 output flop + 2-flop input synchronizer); a 4-cycle quarter period leaves 1 cycle of margin for pad and board delay.
  - `I2C-ENG-008`: Status: `TIP` is `1` from command launch until the command completes. `BUS_BUSY` sets on START and clears on STOP. `DONE` sets when `TIP` falls.
  - `I2C-ENG-009`: When `CTRL.EN = 0`, `scl_oe = sda_oe = 0` and the engine is idle.
  - `I2C-ENG-010`: `scl_oe` and `sda_oe` come straight from flops. The engine adds no synchronizer on `scl_i` or `sda_i`.

## 3. Verification

### 3.1 Test Plan
The testbench drives the block through an APB requester (`apb_requester` or a BFM) and includes a behavioral I2C target model with a configurable address, programmable ACK/NACK response, configurable clock stretching, and a 3- or 4-cycle round-trip delay on `scl_i`/`sda_i` to model the I/O mux.

| Test ID | Description | Requirement IDs |
|---------|-------------|-----------------|
| `T01` | Reset values of all registers and outputs; `scl_oe`/`sda_oe` low while `EN = 0` | `I2C-REG-002`, `I2C-ENG-009` |
| `T02` | Read/write of `CTRL`, `PRESCALE`, `TXDATA` through APB with all `PSTRB` combinations | `I2C-TOP-001`, `I2C-REG-001`, `I2C-REG-002` |
| `T03` | Out-of-range and misaligned APB access to the I2C block | `I2C-TOP-002`, `APB-COM-003`, `APB-COM-004` |
| `T04` | Every register-level error case: `bus.error` asserted, no side effects, `rdata = 0` (checked at `bus_protocol_if`; also checked as `PSLVERR` once `I2C-TOP-004` is resolved) | `I2C-REG-004`, `I2C-TOP-004` |
| `T05` | START + address WRITE with target ACK | `I2C-ENG-001`, `I2C-ENG-003`, `I2C-ENG-005` |
| `T06` | WRITE to a non-existent address; `RX_NACK = 1` | `I2C-ENG-003` |
| `T07` | READ with ACK then READ with NACK + STOP | `I2C-ENG-002`, `I2C-ENG-004` |
| `T08` | Repeated START (write register address, then read) | `I2C-ENG-001`, `I2C-ENG-008` |
| `T09` | SCL timing for `PRESCALE` = 3, a mid value, and a large value | `I2C-ENG-007` |
| `T10` | Target clock stretching of 0, 1, and many cycles | `I2C-ENG-006` |
| `T11` | I/O mux round-trip delay of 3 and 4 cycles at `PRESCALE = 3` | `I2C-ENG-007`, `I2C-ENG-010` |
| `T12` | `TIP`, `BUS_BUSY`, `DONE` timing; `DONE` W1C; event-vs-clear in the same cycle; `irq` masking | `I2C-ENG-008`, `I2C-REG-005`, `I2C-REG-006` |
| `T13` | Reset asserted mid-transfer | `I2C-TOP-003`, `I2C-ENG-009` |
| `T14` | Bus protocol checker: START/STOP only with SCL high, SDA stable while SCL high | `I2C-ENG-001`, `I2C-ENG-002`, `I2C-ENG-005` |

### 3.2 Coverage Bins
- **Commands:**
  - START only, STOP only.
  - START + WRITE, START + READ.
  - WRITE + STOP, READ + STOP.
  - START + WRITE + STOP, START + READ + STOP.
- **Acknowledge:**
  - Target ACK and NACK on WRITE.
  - Controller ACK and NACK on READ.
- **Prescaler:**
  - Minimum (3).
  - Mid-range.
  - Maximum (`0xFFFF`).
- **Clock Stretching:**
  - None.
  - Single cycle.
  - Multi-cycle.
- **Errors:**
  - Each case in `I2C-REG-004` (`bus.error`).
  - Range and align errors from `apb_completer`.
- **Transitions:**
  - Back-to-back WRITEs.
  - Back-to-back READs.
  - Repeated START (write-then-read).
  - Reset during a transfer.

### 3.3 Makefile Targets
- `lint`: Lints RTL, testbench, and interface files.
- `sim CFG=<name>`: Runs self-checking simulation.
- `regress`: Runs all configurations.
- `cov`: Generates coverage report.
- `clean`: Removes build directory.
