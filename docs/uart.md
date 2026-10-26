# Generalized UART Peripheral Specification

**Version:** 1.0

An implementation-agnostic specification for a Universal Asynchronous Receiver/Transmitter (UART) peripheral, detailed enough for an engineer or LLM to produce a functionally correct RTL implementation and verification suite.

---

## 1. Overview

A UART converts parallel data to serial for transmission, and serial to parallel for reception, using start/stop bits, optional parity, and a configurable baud rate. This document covers features, the register interface, timing, corner-case behavior, interrupts, flow control, clocking, CDC considerations, and verification.

**Goals**

- Feature-complete for typical embedded use: configurable baud, word length, parity, stop bits, FIFOs, interrupts, RTS/CTS
- Parameterizable and synthesizable
- Clear, deterministic semantics for register access and interrupts
- Well-defined test plan and verification points

---

## 2. Parameters

| Parameter             | Default | Description                                                  |
|-----------------------|---------|--------------------------------------------------------------|
| `CLOCK_FREQ_HZ`       | n/a     | Peripheral clock frequency (Hz)                              |
| `DEFAULT_BAUD`        | n/a     | Baud rate after reset                                        |
| `FIFO_DEPTH`          | 16      | RX/TX FIFO depth (power of two recommended)                  |
| `DATA_BITS_MAX`       | 8       | Maximum data bits supported                                  |
| `SUPPORT_PARITY`      | true    | Include parity logic                                         |
| `SUPPORT_FLOW_CONTROL`| true    | Include RTS/CTS                                              |
| `SUPPORT_DMA`         | false   | Include DMA request/ack interface                            |
| `OVERSAMPLE`          | 16      | Receiver oversampling ratio (e.g., 8 or 16)                  |
| `ADDR_WIDTH`          | n/a     | Bus address width                                            |
| `DATA_WIDTH`          | 32      | Bus data width                                               |

---

## 3. Features

- Configurable baud generator (integer or fractional divisor)
- Word length 5, 6, 7, or 8 bits
- Parity: none, odd, even, stick (mark/space)
- Stop bits: 1, 1.5 (5-bit words only), or 2
- Parameterizable TX and RX FIFOs
- Interrupts: RX ready, TX empty, RX overflow, line status (parity/framing/break), modem status (CTS change)
- Optional RTS/CTS hardware flow control
- Internal loopback mode
- Break generation and detection
- Line status register with defined clear semantics
- Compatible with APB, AXI4-Lite, or AHB-Lite register access
- Test hooks: forced parity/framing errors, optional disabling of auto-clear, monitor counters

---

## 4. External Interfaces

### 4.1 Clock and reset

| Signal  | Dir | Description                                                                                  |
|---------|-----|----------------------------------------------------------------------------------------------|
| `clk`   | in  | Main clock                                                                                   |
| `rst_n` | in  | Active-low reset. The implementation must state whether it is synchronous or asynchronous (asynchronous assertion with synchronous release is recommended for FPGA/ASIC). |

### 4.2 Serial lines

| Signal  | Dir | Description                                         |
|---------|-----|-----------------------------------------------------|
| `tx`    | out | Serial transmit (idle = 1)                          |
| `rx`    | in  | Serial receive                                      |
| `rts_n` | out | Request To Send, active low (optional)              |
| `cts_n` | in  | Clear To Send, active low (optional)                |

### 4.3 Bus interface

Choose one of APB, AXI4-Lite, or AHB-Lite. The interface must support byte-accessible register reads/writes with documented, consistent endianness.

### 4.4 DMA interface (optional)

`tx_dma_req`, `tx_dma_ack`, `rx_dma_req`, `rx_dma_ack`, or a descriptor-based interface.

### 4.5 Interrupt

`irq`: active-high. Level-sensitive is recommended (see section 14). The chosen semantics must be documented.

---

## 5. Register Map

Recommended canonical map. All registers are 32 bits wide; offsets are relative to the base address. Other offsets and widths are acceptable provided the semantics are preserved.

| Offset | Name           | Access | Description                         |
|--------|----------------|--------|-------------------------------------|
| `0x00` | DATA           | R/W    | RX buffer (read) / TX holding (write) |
| `0x04` | INT_ENABLE     | R/W    | Interrupt enables                   |
| `0x08` | INT_ID / FIFO_CTRL | RO / WO | Interrupt ID (read); FIFO control (write) |
| `0x0C` | LINE_CTRL      | R/W    | Frame format, break                 |
| `0x10` | MODE_CTRL      | R/W    | RTS, loopback, flow control         |
| `0x14` | LINE_STATUS    | RO     | RX/TX/error status                  |
| `0x18` | MODEM_STATUS   | RO     | CTS and related status              |
| `0x1C` | SCRATCH        | R/W    | Driver scratch register             |
| `0x20` | BAUD_DIV_LO    | R/W    | Baud divisor, low 16 bits           |
| `0x24` | BAUD_DIV_HI    | R/W    | Baud divisor, upper bits / extension|
| `0x28` | FRACTIONAL     | R/W    | Fractional divisor (optional)       |
| `0x2C` | FIFO_LEVELS    | RO     | RX/TX FIFO occupancy                |
| `0x30` | IRQ_CLEAR      | WO     | Write-1-to-clear for sticky IRQs    |

Unless noted, bits not listed are reserved: write 0, read as 0. Reset value of every register is 0 except where stated in section 15.

### 5.1 `0x00` DATA

| Access | Behavior                                                              |
|--------|-----------------------------------------------------------------------|
| Read   | Returns the oldest RX FIFO byte (RBR) and pops it                     |
| Write  | Pushes a byte into the TX FIFO (THR)                                  |

Bits `[7:0]` hold data; the rest are reserved.

### 5.2 `0x04` INT_ENABLE (IER)

| Bit | Name              | Description                                           |
|-----|-------------------|-------------------------------------------------------|
| 0   | `RX_READY_IE`     | Enable RX data-available interrupt                    |
| 1   | `TX_EMPTY_IE`     | Enable TX-empty interrupt                             |
| 2   | `RX_OVF_IE`       | Enable RX overflow interrupt                          |
| 3   | `LINE_STATUS_IE`  | Enable parity/framing/break interrupts                |
| 4   | `MODEM_STATUS_IE` | Enable modem status (CTS change) interrupt            |
| 7:5 |                   | Reserved                                              |

### 5.3 `0x08` INT_ID (read) / FIFO_CTRL (write)

**INT_ID (read, RO)**

| Bits | Name           | Description                                                                 |
|------|----------------|-----------------------------------------------------------------------------|
| 3:0  | `INT_ID`       | Highest-priority pending interrupt (encoding below)                         |
| 4    | `FIFO_ENABLED` | FIFOs are enabled                                                           |

| `INT_ID` | Meaning              |
|----------|----------------------|
| `0`      | None pending         |
| `1`      | RX ready             |
| `2`      | TX empty             |
| `3`      | RX overflow          |
| `4`      | Line status          |
| `5`      | Modem status         |

**FIFO_CTRL (write, WO)**

| Bit | Name            | Description                                      |
|-----|-----------------|--------------------------------------------------|
| 0   | `FIFO_ENABLE`   | 0 = disable FIFOs, 1 = enable                    |
| 1   | `RX_FIFO_RESET` | Write 1 to clear the RX FIFO (self-clearing)     |
| 2   | `TX_FIFO_RESET` | Write 1 to clear the TX FIFO (self-clearing)     |
| 3   | `DMA_MODE`      | Enable DMA operation for the FIFOs               |
| 7:4 |                 | Reserved                                         |

### 5.4 `0x0C` LINE_CTRL (LCR)

| Bit | Name          | Description                                                                          |
|-----|---------------|--------------------------------------------------------------------------------------|
| 1:0 | `WORD_LENGTH` | `00` = 5 bits, `01` = 6, `10` = 7, `11` = 8                                          |
| 2   | `STOP_BITS`   | `0` = 1 stop bit; `1` = 2 stop bits (1.5 for 5-bit words)                            |
| 4:3 | `PARITY`      | `00` = none, `01` = odd, `10` = even, `11` = stick (mark/space)                      |
| 6:5 |               | Reserved                                                                             |
| 7   | `BREAK`       | Write 1 to hold `tx` low (break). Read returns the current break state.              |

### 5.5 `0x10` MODE_CTRL (MCR)

| Bit | Name        | Description                                                                         |
|-----|-------------|-------------------------------------------------------------------------------------|
| 0   | `RTS`       | Manual RTS control (when `AUTO_RTS` is 0)                                           |
| 1   | `AUTO_RTS`  | Hardware drives RTS from RX FIFO thresholds                                         |
| 2   | `LOOPBACK`  | Enable internal loopback (`tx` routed to `rx` internally)                           |
| 3   | `SW_FLOW`   | Enable software flow control (XON/XOFF)                                             |
| 7:4 |             | Reserved                                                                            |

### 5.6 `0x14` LINE_STATUS (LSR)

| Bit | Name       | Description                                                                          |
|-----|------------|--------------------------------------------------------------------------------------|
| 0   | `DR`       | Data ready: RX FIFO not empty                                                        |
| 1   | `OE`       | Overrun error: a byte was received while the RX FIFO was full                        |
| 2   | `PE`       | Parity error on the byte at the head of the RX FIFO                                  |
| 3   | `FE`       | Framing error                                                                        |
| 4   | `BI`       | Break interrupt                                                                      |
| 5   | `THRE`     | TX FIFO not full (room to write). *See open item 3.*                                 |
| 6   | `TEMT`     | Transmitter empty: shift register and TX FIFO both empty                             |
| 7   | `FIFO_ERR` | At least one error byte (PE/FE/BI) is in the RX FIFO                                 |

Clear semantics must be documented per bit. Recommended: `OE`, `PE`, `FE`, `BI` are cleared on read of LSR (or by `IRQ_CLEAR`); `DR`, `THRE`, `TEMT` are live status and are never sticky.

### 5.7 `0x18` MODEM_STATUS (MSR)

| Bit | Name   | Description                                   |
|-----|--------|-----------------------------------------------|
| 0   | `DCTS` | CTS changed since last read (cleared on read) |
| 1   | `DDSR` | DSR changed (if implemented)                  |
| 2   | `TERI` | Trailing edge of RI (if implemented)          |
| 3   | `DDCD` | DCD changed (if implemented)                  |
| 4   | `CTS`  | Current CTS state                             |

### 5.8 Remaining registers

| Offset | Register     | Description                                                                              |
|--------|--------------|------------------------------------------------------------------------------------------|
| `0x1C` | SCRATCH      | General-purpose R/W for driver use                                                        |
| `0x20` | BAUD_DIV_LO  | Lower 16 bits of the baud divisor                                                         |
| `0x24` | BAUD_DIV_HI  | Upper divisor bits for extended or fractional divisors                                    |
| `0x28` | FRACTIONAL   | Fractional divisor numerator/denominator (optional)                                       |
| `0x2C` | FIFO_LEVELS  | `[7:0]` `RX_LEVEL` (bytes in RX FIFO); `[15:8]` `TX_LEVEL` (entries in TX FIFO)           |
| `0x30` | IRQ_CLEAR    | Write 1 to clear a specific sticky interrupt                                              |

---

## 6. Register Semantics and I/O Rules

### 6.1 DATA read

- Returns one byte from the RX FIFO and pops it. Parity bits are stripped by hardware.
- If the RX FIFO is empty, the implementation must define the result. **Recommended:** return 0, leave `LSR.DR = 0`, and never stall the bus. Software should check `DR` before reading.
- Debug/test modes may provide a non-destructive peek.

### 6.2 DATA write

- A write pushes the byte into the TX FIFO and starts the transmitter if idle.
- If the TX FIFO is full, behavior depends on the bus:
  - **APB:** the write completes without stalling. Recommended: the byte is dropped and a dedicated TX-overflow status flag is set. Software must check `THRE` before writing.
  - **AXI4-Lite / AHB-Lite:** preferred approach is to stall the write with ready/valid backpressure until the FIFO has space.

### 6.3 Interrupts

- `irq` is asserted whenever any enabled interrupt source is pending.
- With several pending, `INT_ID` reports the highest priority (section 14).
- Level-sensitive `irq` is recommended: it stays asserted while any enabled source is pending. A pulse is acceptable only if the interrupt controller is guaranteed to see it.

### 6.4 FIFO behavior

- **RX FIFO:** received bytes are pushed. If full when another byte arrives, set `OE` and drop the newest byte (recommended; overwrite-oldest is an allowed alternative, but must be documented).
- **TX FIFO:** bytes are popped and transmitted. When the FIFO and shift register are empty, `TEMT = 1`.
- FIFO resets clear contents and associated flags without touching configuration registers.
- Configurable thresholds `RX_LEVEL_TH` and `TX_LEVEL_TH` trigger interrupts and/or RTS toggling.

### 6.5 Side effects

- Sticky bits in LSR and MSR are cleared on read or via `IRQ_CLEAR`; each bit's behavior must be specified.
- FIFO reset bits are write-1, self-clearing.

---

## 7. Baud Rate Generation

```
baud = CLOCK_FREQ_HZ / (DIVIDER * OVERSAMPLE)
```

- Typical `OVERSAMPLE = 16`; 8x is an optional configuration.
- The receiver samples at the middle of a bit: tick `OVERSAMPLE / 2`.
- The divisor is either a 16-bit integer or a fractional (numerator/denominator) divider.
- Document the maximum allowable baud error (recommended < 3%).

**Worked example**

| Item              | Value                                                  |
|-------------------|--------------------------------------------------------|
| Desired baud      | 115200                                                 |
| `CLOCK_FREQ_HZ`   | 50,000,000                                             |
| `OVERSAMPLE`      | 16                                                     |
| `DIVIDER`         | 50,000,000 / (115200 x 16) = 27.1267                   |

Use integer divisor 27 and apply the fractional part to compensate. With integer-only, the actual baud is about 115,741 (error roughly +0.47%).

---

## 8. Receive Sampling and Framing

**Frame format** (idle line = 1):

```
| Start (0) | Data bits, LSB first | [Parity] | Stop bit(s) (1) |
```

**Sampling**

1. On a 1 to 0 transition of `rx`, wait `OVERSAMPLE / 2` ticks and re-sample to confirm the start bit (single sample or majority vote). If it is not 0, treat it as a glitch and return to idle.
2. After confirming start, sample each data, parity, and stop bit at successive multiples of `OVERSAMPLE` ticks.

**Error detection**

| Error   | Condition                                                                                                  |
|---------|------------------------------------------------------------------------------------------------------------|
| Framing | Stop bit sampled as 0                                                                                       |
| Parity  | Received parity does not match the configured parity                                                        |
| Overrun | A byte completes while the RX FIFO is full                                                                  |
| Break   | `rx` held low for at least a full character time (start + data + parity + stop); sets `BI`                  |

---

## 9. Transmit Timing and Behavior

- When data is written to THR and the transmitter is idle, the shift register loads from the FIFO and begins shifting at the baud rate.
- Frame order: start bit, data bits (LSB first), optional parity, stop bit(s).
- `tx` idles at 1.
- **Break:** while `LCR.BREAK = 1`, `tx` is held low until the bit is cleared.
- `TEMT` = shift register empty AND TX FIFO empty.

---

## 10. Flow Control

**CTS (if `SUPPORT_FLOW_CONTROL`)**

- When `cts_n` is deasserted-high (remote not ready), finish the current byte, then suspend the transmitter. No FIFO data is dropped. An optional TX-paused flag/interrupt may be provided.
- A change in CTS sets `MSR.DCTS`.

**RTS**

- **Auto-RTS:** RTS is driven from RX FIFO thresholds to stop the remote transmitter.
- **Manual:** software controls `MCR.RTS` directly.

---

## 11. Loopback and Test Modes

- **Loopback** (`MCR.LOOPBACK`): internal `tx` is routed to internal `rx`. Physical `tx` is held idle (recommended), and CTS/RTS pins are bypassed.
- **Error injection** (for verification): control bits to force a parity error, a framing error, or a break.

---

## 12. Error and Corner-Case Behavior

| Case | Behavior |
|------|----------|
| RX overflow | Set `OE`, drop the new byte, optionally increment an overrun counter |
| Write while TX FIFO full | Per section 6.2. Software must check `THRE` first; hardware asserts `THRE` only when space exists |
| Reset | Clears FIFOs and status flags, disables interrupts; configuration registers return to documented reset defaults (document which registers are reset) |
| CDC | Double-flop async inputs (`rx`, `cts_n`); use a FIFO to cross into the bus clock domain if clocks differ; handshake `irq` if the interrupt domain differs |

---

## 13. Bus Interface Guidance

| Bus | Guidance |
|-----|----------|
| APB | Reads return immediately; writes complete in a single transfer. If the TX FIFO is full, set a status flag and do not hang the bus. |
| AXI4-Lite / AHB-Lite | May apply write backpressure through ready/valid until FIFO space is available. |

Any bus-specific wrapper must preserve register behavior and side effects.

---

## 14. Interrupt Priority and Clearing

**Priority (highest to lowest)**

1. Line status (PE / FE / BI)
2. RX overflow
3. RX ready (usually level, when RX FIFO >= threshold)
4. TX empty (THR / TEMT)
5. Modem status

`INT_ID` reports the highest-priority pending interrupt.

**Clearing**

- **Edge/sticky sources:** cleared by reading the associated status register, or by writing `IRQ_CLEAR`.
- **Level sources:** remain asserted until the condition clears (e.g., RX FIFO drained below threshold).

---

## 15. Register Defaults

| Register       | Reset value                                                                     |
|----------------|---------------------------------------------------------------------------------|
| INT_ENABLE     | `0x00`                                                                          |
| LINE_CTRL      | `0x03` (8 data bits, 1 stop bit, no parity)                                     |
| FIFO enable    | 1 (optional)                                                                    |
| BAUD_DIV       | Computed from `DEFAULT_BAUD` and `CLOCK_FREQ_HZ`                                |

---

## 16. Verification Plan

The source spec calls for a test plan but did not enumerate one. The items below follow directly from the behaviors defined above.

**Directed tests**

- TX/RX at every word length, parity mode, and stop-bit setting
- Baud accuracy across several divisors, including the fractional case
- FIFO full/empty boundaries for both RX and TX
- RX overflow (`OE`, dropped byte)
- Framing, parity, and break detection and clearing
- Break generation via `LCR.BREAK`
- CTS suspend/resume without data loss; auto-RTS threshold behavior
- Loopback self-test
- Interrupt priority ordering and clearing for each source
- Reset behavior of every register

**Assertions**

- No FIFO overflow/underflow beyond the defined, flagged behavior
- `tx` is 1 whenever idle
- `TEMT` is high only when both the shift register and TX FIFO are empty
- `irq` equals the OR of enabled, pending sources

---

## Appendix: Open Items to Resolve

Places where the source text was ambiguous or internally inconsistent. Settle these before writing RTL.

1. **Write-when-full behavior:** the source offers several options (drop and flag, return an error, or stall) and, at one point, suggests reusing `LSR.OE`. `OE` already means RX overrun, so this spec recommends a separate TX-overflow flag instead. Choose one.
2. **Empty RX read:** return 0 vs. open bus. Recommended is 0 with no stall.
3. **`THRE` definition:** the source says "TX FIFO not full; or empty depending on policy". Choose one. "Not full" is assumed in section 5.6; classic 16550 behavior is "empty".
4. **Divisor registers:** the split between `BAUD_DIV_LO`, `BAUD_DIV_HI`, and `FRACTIONAL` (field widths, fractional format) is not defined.
5. **`INT_ENABLE` and `INT_ID`:** the source defines no modem-status enable bit and no modem-status interrupt ID. This spec adds `MODEM_STATUS_IE` (bit 4) and ID `5`.
6. **RX FIFO overrun policy:** drop newest (recommended) vs. overwrite oldest.
7. **Thresholds:** `RX_LEVEL_TH` and `TX_LEVEL_TH` are mentioned but have no register or default.
8. **Software flow control:** `MCR.SW_FLOW` (XON/XOFF) is listed with no behavior defined.
9. **Stick parity:** `PARITY = 11` does not say whether it is mark or space; define the polarity.
10. **Reset style:** synchronous vs. asynchronous reset, and which registers keep their value through reset.
11. **Bit-order option:** the source mentions "configurable endianness" for serial bit order with no control bit; add one or drop the option.
