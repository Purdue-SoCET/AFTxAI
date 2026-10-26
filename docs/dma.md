# Single-Channel DMA Controller: Specification

## 1. Overview

A single-channel, memory-mapped DMA controller that moves data from a source address to a destination address over a shared bus (AHB-Lite in the reference design). An internal FIFO decouples the read side from the write side.

**Features**

- Memory-to-memory and peripheral-triggered transfers
- 8-, 16-, and 32-bit transfer units
- Optional source/destination address incrementing
- Optional circular mode
- Basic error reporting and optional completion/error interrupt
- Fully parameterizable widths and FIFO depth

**Design goals**

- Safe, deterministic transfer semantics
- Minimal read-to-write latency through the FIFO pipeline
- Clear register interface for software control and status
- Bus-agnostic core: all bus-specific logic lives in the arbiter/bus adapter, so porting to another bus means replacing that module only
- Small footprint suited to FPGA/SoC prototypes

---

## 2. Parameters

| Parameter    | Default                 | Description                                              |
|--------------|-------------------------|----------------------------------------------------------|
| `ADDR_W`     | 32                      | Address width                                            |
| `DATA_W`     | 32                      | Data width                                               |
| `PSIZE_W`    | 2                       | Width of transfer-size field (selects 8/16/32-bit)       |
| `HSZ_W`      | 3                       | Bus `HSIZE` width (AHB/AXI-like)                         |
| `COUNT_W`    | 8                       | Transfer-length counter width                            |
| `FIFO_DEPTH` | 8                       | FIFO entries (power of two recommended)                  |
| `FIFO_PKT_W` | `PSIZE_W + ADDR_W + DATA_W` | FIFO entry width (default 2 + 32 + 32 = **66**)      |

---

## 3. External Interfaces

### 3.1 System

| Signal         | Dir | Description                                                              |
|----------------|-----|--------------------------------------------------------------------------|
| `clk`          | in  | System clock                                                             |
| `rst_n`        | in  | Active-low reset (synchronous or asynchronous; choose one and document)  |
| `async_reset`  | in  | *Optional.* External forced reset of the FSMs                            |

### 3.2 Register (CPU slave) interface

A memory-mapped slave port (AHB-Lite, APB, or a simple bus) supporting word reads/writes at a configurable base address.

### 3.3 Memory master interface

The read and write engines share one master port through the arbiter. Two options:

- **AHB-Lite example:** `HTRANS`, `HWRITE`, `HADDR[ADDR_W-1:0]`, `HWDATA[DATA_W-1:0]`, `HSIZE`, `HREADY`, `HRESP`, `HRDATA`
- **Abstract request/response interface** (`memArb_if`) into the arbiter module. *Preferred for bus portability.*

### 3.4 Trigger and interrupt (optional)

| Signal | Dir | Description                                                           |
|--------|-----|-----------------------------------------------------------------------|
| `drq`  | in  | DMA request from a peripheral                                         |
| `daq`  | out | DMA acknowledge                                                       |
| `irq`  | out | Asserted on completion or error when `CR.IRQ_EN` is set              |

---

## 4. Register Map

All offsets are relative to a configurable `BASE`. Registers are word-aligned (adapt if the bus is not 32 bits wide). Offset `0x00` is unused/reserved.

| Offset | Name | Width              | Access | Description               |
|--------|------|--------------------|--------|---------------------------|
| `0x04` | SAR  | `ADDR_W`           | R/W    | Source address            |
| `0x08` | DAR  | `ADDR_W`           | R/W    | Destination address       |
| `0x0C` | TSR  | `COUNT_W` (or 32)  | R/W    | Transfer size (units)     |
| `0x10` | CR   | 32                 | R/W    | Control register          |
| `0x14` | SR   | 32                 | R      | Status register           |

### 4.1 CR: Control Register

| Bit(s) | Name           | Description                                                                                          |
|--------|----------------|------------------------------------------------------------------------------------------------------|
| 0      | `EN`           | Channel enable. `1` starts the transfer. Software-cleared or auto-cleared on completion (document the choice). |
| 1      | `STOP`         | Reserved / stop request                                                                              |
| 4      | `DIR`          | Direction. `0` = memory-to-memory (default). Peripheral semantics to be defined per integration.      |
| 7:6    | `PSIZE`        | Transfer unit size: `00` = 8-bit, `01` = 16-bit, `10` = 32-bit, `11` = reserved                      |
| 8      | `TRIG_EN`      | Enable external trigger (`drq`) usage                                                                |
| 10     | `CIRC`         | Circular mode: auto-wrap after the count rolls over                                                  |
| 11     | `INC_DEST`     | Increment destination address after each transfer                                                    |
| 12     | `INC_SRC`      | Increment source address after each transfer                                                         |
| 13     | `DIRECT_PERIPH`| Direct peripheral mode (special behavior when set)                                                   |
| 14     | `IRQ_EN`       | Enable completion/error interrupt                                                                    |
| other  |                | Reserved (write 0, read as 0)                                                                        |

`PSIZE` maps to the bus size as `HSIZE = {1'b0, PSIZE[1:0]}`.

### 4.2 TSR: Transfer Size Register

The low `COUNT_W` bits hold the transfer length in units (of size `PSIZE`). Upper bits are reserved.

### 4.3 SR: Status Register

| Bit(s) | Name       | Description                                      |
|--------|------------|--------------------------------------------------|
| 0      | `FINISHED` | Set on completion. Sticky until read/cleared.    |
| 1      | `ERROR`    | Set on error. Sticky until read/cleared.         |
| 31:2   |            | Reserved                                         |

**Clear semantics (default):** reading SR clears `FINISHED` and `ERROR` (read-to-clear). An implementation that instead uses a dedicated clear bit in CR must document this explicitly and apply it consistently.

---

## 5. FIFO and Packet Format

Each FIFO entry carries everything the write side needs:

```
[ PSIZE (2) | DEST_ADDR (ADDR_W) | DATA (DATA_W) ]
```

- Depth is `FIFO_DEPTH`. Full and empty flags must be exposed internally.
- **Read side** pushes only when the FIFO is not full and the bus read has completed.
- **Write side** pops only when the FIFO is not empty and the bus is ready to accept a write.

---

## 6. Architecture

The top-level `dma_controller` instantiates these modules:

| Module          | Role                                                         |
|-----------------|--------------------------------------------------------------|
| `registers`     | Register file and CPU slave interface                        |
| `read_control`  | Read FSM: fetches source data, pushes to FIFO                |
| `write_control` | Write FSM: pops FIFO, writes to destination                  |
| `memArbiter`    | Arbitrates read/write access to the shared bus               |
| `fifo`          | Decoupling buffer                                            |
| `counter`       | Tracks completed transfers against TSR                       |

Bus-specific logic stays inside `memArbiter` (or a bus adapter).

### 6.1 Read Controller FSM

| State       | Actions                                                                                                                                                              | Next                                  |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| `IDLE`      | Wait for `EN` and start conditions (and `drq` if `TRIG_EN`)                                                                                                          | `READ`                                |
| `READ`      | Compute source address (`SAR + (count << psize)` when `INC_SRC`, else `SAR`). Issue read: `HSEL`, `HADDR`, `HSIZE`, `HWRITE=0`. Wait for `HREADY`. On `OKAY`, capture `HRDATA`. | `FIFO_WAIT`; `ERROR` if `HRESP != OKAY` |
| `FIFO_WAIT` | Wait until the FIFO is not full                                                                                                                                      | `FIFO_WRITE`                          |
| `FIFO_WRITE`| Compute destination address (`DAR + (count << psize)` when `INC_DEST`, else `DAR`). Push `{psize, dest, data}`. Increment count. Bounds-check address.               | `READ`; `FINISHED` (or `CIRC_RESET` if `CIRC`) when count reaches TSR |
| `ERROR`     | Set error flag; optionally flush FIFO; wait for status read/clear                                                                                                    | `IDLE`                                |
| `FINISHED`  | Set finished flag; assert `irq` if enabled; wait for status read/clear                                                                                               | `IDLE`                                |

### 6.2 Write Controller FSM

| State       | Actions                                                                                                              | Next                                    |
|-------------|----------------------------------------------------------------------------------------------------------------------|-----------------------------------------|
| `IDLE`      | If FIFO not empty, begin. If FIFO empty and `EN==0`, the transfer may be marked finished.                            | `FIFO_READ`                             |
| `FIFO_READ` | Latch top-of-FIFO (`psize`, `addr`, `data`) and assert FIFO pop                                                      | `WRITE`                                 |
| `WRITE`     | Drive `HWRITE=1`, `HADDR`, `HWDATA`, `HSIZE` (from `psize`), `HSEL`. Wait for `HREADY`.                               | `IDLE` or next `FIFO_READ` on `OKAY`; `ERROR` otherwise |
| `ERROR`     | Set error flag; optionally flush FIFO; wait for status read/clear                                                    | `IDLE`                                  |

### 6.3 Counter

- Increments on each completed logical transfer.
- When the count reaches TSR, raises a rollover/finished flag.
- Cleared via CR or read-side behavior.

### 6.4 Arbiter

- Exposes a generic `memArb_if` carrying read and write request vectors.
- Accepts concurrent `r_hsel` and `w_hsel` and arbitrates deterministically (round-robin, fixed priority, or last-served-flip).
- For AHB-like buses: drive `HTRANS = NONSEQ` when granting a new transfer, and hold master signals stable until `HREADY` completes the transaction.
- Returns `HRDATA` to the read controller and forwards `r_hready` / `w_hready` to the respective controllers.

---

## 7. Bus Handshake and Backpressure (AHB-style)

1. Controllers assert `HSEL`/`HADDR`/`HWRITE`/`HSIZE` when they want a transaction.
2. The arbiter drives bus signals only for the granted requester.
3. Controllers must wait on `*_hready` from the arbiter and must not assume single-cycle completion.
4. Any `HRESP != OKAY` sets the error flag and aborts the transfer.

---

## 8. Error and Status Handling

**Error sources**

- Bus response error (`HRESP != OKAY`)
- Address out of range (optional check)
- FIFO overflow/underflow (logic bug; must be prevented by design)

**On error**

1. Set sticky `SR.ERROR`.
2. Optionally flush the FIFO or freeze operation (design choice; document it).
3. Assert `irq` if `CR.IRQ_EN` is set.
4. Require software to clear the error (read-to-clear, or CR clear bit).

**On normal completion**

- Set `SR.FINISHED` and assert `irq` if enabled. Software acknowledgment clears it.

---

## 9. Software Interface

### 9.1 Driver API

| Function                                   | Behavior                                                                |
|--------------------------------------------|-------------------------------------------------------------------------|
| `initDMA(params)`                          | Validate sizes/directions; program SAR, DAR, TSR, CR; clear status      |
| `startTransfer()`                          | Set `CR.EN` (other control bits unchanged)                              |
| `stopTransfer()`                           | Clear `CR.EN`                                                           |
| `setSource(addr)` / `setDest(addr)` / `setLength(n)` | Write SAR / DAR / TSR                                         |
| `readStatus()`                             | Return SR bits (clearing sticky bits if read-to-clear)                  |
| Interrupt handler                          | Check SR, clear SR/CR bits, notify upper layers                         |

### 9.2 Example sequence

```
initDMA(src, dst, len, psize, inc_src, inc_dst, circular, irq_en)
  write SAR, DAR, TSR
  write CR (config bits)
  set CR.EN = 1
wait for IRQ, or poll SR.FINISHED
```

---

## 10. Verification Plan

### 10.1 Unit testbenches

- Memory-to-memory transfer of N units at 8-, 16-, and 32-bit sizes
- FIFO full/empty boundary behavior
- Arbiter contention with simultaneous read and write requests
- Bus error injection (`HRESP != OKAY`)
- Circular mode wrap behavior
- Peripheral trigger: `drq`/`daq` handshake

### 10.2 Assertions

- FIFO never overflows or underflows when controllers obey the handshake
- Counter increments match FIFO pushes/pops
- Generated `HSIZE` matches `PSIZE` encoding
- `SR` is updated on finish and cleared on read

### 10.3 Coverage

- Every FSM state visited
- Edge cases: single-unit transfer, maximum-length transfer, unaligned addresses (if supported)

### 10.4 Performance

- Throughput versus FIFO depth and bus stall patterns

---

## 11. Deliverables

- Parameterized RTL with clear ports and comments: `dma_controller.sv`, `read_control.sv`, `write_control.sv`, `registers.sv`, `memArbiter.sv`, `fifo.sv`, `counter.sv`, `ahb_if.vh`, `memArb_if.vh`
- C header `dma.h` (register map plus inline helpers) and a C driver implementing the API in section 9
- SystemVerilog testbench with a memory model, exercising transfers, bus stalls, and error injection, and validating memory contents
- Verification plan and assertions (section 10)
- README (parameters, how to run the testbench) and a short spec summarizing the register map and control flow

### Reference defaults

`ADDR_W=32`, `DATA_W=32`, `COUNT_W=8`, `FIFO_DEPTH=8`, FIFO entry = 66 bits; `HSIZE = {1'b0, PSIZE[1:0]}` with PSIZE `00/01/10` = 8/16/32-bit; SR uses read-to-clear for `FINISHED`/`ERROR` unless explicitly documented otherwise.

---

## 12. Possible Enhancements

- Multiple channels with in-memory descriptors (linked-list DMA)
- Scatter-gather via descriptor chains
- Burst and alignment-aware transfers
- Per-channel interrupts and per-transfer callbacks
- ECC/status counters, performance counters, watermark thresholds
- AXI / AXI-Lite variant (adapt the arbiter)
- Cache-coherency hooks (flush/invalidate interface)

---

## 13. Generation Prompt (for an LLM)

> Generate a parameterized single-channel DMA controller in SystemVerilog with a matching C driver and testbench.
>
> - **Parameters:** `ADDR_W=32`, `DATA_W=32`, `COUNT_W=8`, `FIFO_DEPTH=8`
> - **Registers:** SAR (`BASE+0x04`), DAR (`BASE+0x08`), TSR (`BASE+0x0C`), CR (`BASE+0x10`), SR (`BASE+0x14`)
> - **CR bits:** `EN[0]`, `DIR[4]`, `PSIZE[7:6]`, `TRIG_EN[8]`, `CIRC[10]`, `INC_DEST[11]`, `INC_SRC[12]`, `DIRECT_PERIPH[13]`, `IRQ_EN[14]`
> - **FIFO packet:** `{PSIZE[1:0], DEST_ADDR[31:0], DATA[31:0]}`
> - **Bus:** a `memArbiter` module with an AHB-Lite master interface that selects between the read and write sides, handles `HREADY`/`HRESP`, and drives `r_hready`/`w_hready`
> - **RTL files:** `dma_controller.sv`, `read_control.sv`, `write_control.sv`, `registers.sv`, `memArbiter.sv`, `fifo.sv`, `counter.sv`, `ahb_if.vh`, `memArb_if.vh`
> - **C:** `dma.h` register map and a driver (init, start, stop, set address, set length)
> - **Testbench:** SystemVerilog, exercising transfers, bus stalls, and error injection
> - Add assertions and comments.
>
> **Output:** all RTL files, C files, and a README explaining parameters and how to run the testbench.

---

## Appendix: Open Items to Resolve

Points where the source text left behavior undefined or inconsistent. Each should be pinned down before RTL is written.

1. **`CR.EN` lifecycle:** software-cleared or auto-cleared on completion?
2. **`PSIZE = 11`:** reserved; define whether writing it raises an error or is ignored.
3. **`DIR` / `DIRECT_PERIPH`:** peripheral-mode semantics are not defined.
4. **`COUNT_W` vs. TSR width:** with `COUNT_W=8`, the maximum length is 255 (or 256 if 0 encodes 256); state which.
5. **Unaligned addresses:** supported or not?
6. **Error recovery:** flush the FIFO or freeze it? Does `STOP` (CR bit 1) abort in-flight transactions?
7. **Address increment:** the FSM formula `addr + (count << psize)` implies increment; define behavior when `INC_SRC`/`INC_DEST` is 0 (fixed address, e.g. for a peripheral FIFO).
8. **Reset style:** synchronous vs. asynchronous `rst_n`, and the role of `async_reset`.
