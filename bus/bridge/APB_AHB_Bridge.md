## AHB-to-APB Bridge Specification (`ahb2apb`)

### Overview

`ahb2apb` converts AHB transactions into APB transactions. It sits between an AHB subordinate port and an APB target region, translating address, control, and data signals while handling protocol timing, error signaling, and clock-domain crossing (CDC).

Responsibilities:

- Accept valid AHB transactions only from a configured address window
- Translate AHB addresses to APB addresses relative to a base address
- Convert AHB reads and writes into APB setup/access cycles
- Honor byte-lane write strobes
- Stall AHB traffic until the APB transfer completes
- Return APB read data to the AHB side
- Propagate APB errors to the AHB side via `HRESP`
- Buffer requests and responses across the AHB/APB clock domains

The AHB-side and APB-side control logic are separate and independent, and FIFOs are used to move information safely between clock domains.

---

### Reuse of Existing Verified Modules

**The bridge must be built on the AHB and APB modules that already exist in the repository and are already verified.**

- Use the existing AHB and APB modules and interfaces (`ahb_if`, `apb_if`) as-is. Do not redefine, duplicate, or modify them.
- Do not reimplement AHB or APB protocol behavior that those modules already provide.
- The bridge itself should only add the logic specified in this document:
  - address window and alignment checking
  - address translation
  - request/response packetization
  - FIFO-based clock-domain crossing
  - the AHB-side and APB-side state machines that connect the two protocols
- If a verified FIFO or CDC module already exists in the repository, prefer it over writing a new one.

---

### Module Interface

```systemverilog
module ahb2apb #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 'h8000_0000,
    parameter int FIFO_DEPTH = 16,
    parameter int NWORDS = 4096
)(
    ahb_if.subordinate ahbif,
    apb_if.requester   apbif
);
endmodule
```

### Parameters

| Parameter | Description |
|---|---|
| `ADDR_WIDTH` | Width of the address bus (both AHB and APB). |
| `DATA_WIDTH` | Width of the data bus. Write strobe width is `STRB_WIDTH = DATA_WIDTH / 8`. |
| `BASE_ADDR` | Base address of the APB-mapped region. All legal AHB addresses fall in the window starting here. |
| `FIFO_DEPTH` | Depth of the request and response FIFOs used for CDC. |
| `NWORDS` | Number of addressable units in the mapped region; used with `BASE_ADDR` to compute the top of the window. |

---

### Address Window and Validity

The window starts at `BASE_ADDR` and ends at:

```systemverilog
TOP_ADDR = BASE_ADDR + NWORDS * (ADDR_WIDTH / 8);
```

An address is in range only if:

```systemverilog
ahbif.HADDR >= BASE_ADDR && ahbif.HADDR < TOP_ADDR
```

It must also be aligned to the transfer width:

```systemverilog
(ahbif.HADDR & ((ADDR_WIDTH / 8) - 1)) == '0
```

If the address is out of range or misaligned, the bridge must reject the transaction with an AHB error response and **must not start any APB transaction**.

The APB address is the offset from the base:

```systemverilog
latched_addr <= ahbif.HADDR - BASE_ADDR;
```

---

### AHB Side

**Signals used:** `HCLK`, `HRESETn`, `HSEL`, `HTRANS`, `HADDR`, `HWRITE`, `HWDATA`, `HSTRB`, `HREADYOUT`, `HRDATA`, `HRESP`

**A transfer is valid when all of the following are true:**

1. `HSEL` is asserted
2. `HTRANS[1]` is asserted (active, not IDLE)
3. The address is valid (in range and aligned)
4. The bridge is not already waiting on an outstanding APB response

**On a valid request, latch:**

- `HADDR` (translated to the APB-relative address)
- `HWRITE`
- `HWDATA`
- `HSTRB`
- address validity / error status

The latched request is used to build the APB request after the AHB address phase ends.

**AHB completion and stall timing**

| Case | `HREADYOUT` | `HRESP` | Notes |
|---|---|---|---|
| APB transfer in progress | 0 | 0 | AHB master held in a wait state |
| APB transfer complete, success | 1 | 0 | `HRDATA` valid for reads |
| Address error or APB error | per AHB error timing | 1 | Address errors are never forwarded to APB |

---

### APB Side

**Signals used:** `PCLK`, `PRESETn`, `PSEL`, `PENABLE`, `PADDR`, `PWDATA`, `PWRITE`, `PSTRB`, `PREADY`, `PRDATA`, `PSLVERR`

The bridge drives the APB requester signals according to the current APB state.

**Setup/access sequence (every valid request):**

| Phase | `PSEL` | `PENABLE` | Driven |
|---|---|---|---|
| SETUP | 1 | 0 | `PADDR`, `PWDATA` (writes), `PWRITE`, `PSTRB` |
| ACCESS | 1 | 1 | Same signals held while waiting for `PREADY` |

When `PREADY` is asserted the transfer completes, and the bridge captures `PRDATA` (reads) and `PSLVERR`. In idle, all outputs must be in a safe default state.

---

### Transfer Behavior

#### Reads

- Accepted only if the address is valid.
- APB read: `PWRITE = 0`, `PSEL = 1`, `PENABLE = 1` in the access phase.
- Wait for `PREADY`, then capture `PRDATA` and return it on `HRDATA`.
- `HRESP = 0` on success. If `PSLVERR` is asserted, signal an AHB error.

#### Writes

- Accepted only if the address is valid.
- APB write: `PWRITE = 1`, `PWDATA = HWDATA`, `PSTRB = HSTRB`, `PADDR = translated address`.
- Wait for `PREADY`; the write is then complete.
- If `PSLVERR` is high, drive `HRESP = 1` and report a failed AHB transfer.
- Only byte lanes with the corresponding `HSTRB` bit set may be written. Unselected lanes must remain unchanged at the target.

---

### Error Handling

**Address error** (out of range or misaligned):

- Do not forward to APB.
- Drive `HRESP = 1` and hold the protocol in an error state until the AHB error sequence completes.

**APB error** (`PSLVERR = 1` at completion):

- Present it as `HRESP = 1`; the AHB transfer is considered failed.
- `HRDATA` is not meaningful.

---

### Packet Formats and Clock-Domain Crossing

#### Forward packet (AHB → APB)

```systemverilog
{addr, wdata, write, strobe}
```

| Field | Width |
|---|---|
| `addr` | `ADDR_WIDTH` |
| `wdata` | `DATA_WIDTH` |
| `write` | 1 |
| `strobe` | `DATA_WIDTH / 8` |

AHB requests are serialized into this packet and pushed into the forward FIFO.

#### Return packet (APB → AHB)

```systemverilog
{hresp, rdata}
```

| Field | Meaning |
|---|---|
| `hresp` | AHB error flag |
| `rdata` | Read data for the return path |

These are pushed into the return FIFO when APB completion occurs.

#### FIFOs

| FIFO | Direction | Write clock | Read clock | Purpose |
|---|---|---|---|---|
| Forward | AHB → APB | AHB clock | APB clock | Holds pending requests until the APB side can service them |
| Return | APB → AHB | APB clock | AHB clock | Holds completion status and read data until the AHB side accepts it |

All FIFO reads and writes must be guarded by control logic. A request must never be dropped and a response must never be overwritten.

---

### State Machines

The AHB and APB sides use **separate, independent** state machines, since the clocks may differ.

#### AHB state machine

| State | Behavior |
|---|---|
| `AHB_IDLE` | Wait for a valid request. Invalid address → `ERROR`. Valid request → latch it and go to `WAIT`. |
| `WAIT` | Hold the AHB side stalled until the APB result returns through the return FIFO. |
| `ERROR` | Report the AHB error response, then return to idle. |

#### APB state machine

| State | Behavior |
|---|---|
| `APB_IDLE` | Wait for a request packet in the forward FIFO. |
| `SETUP` | Assert `PSEL`; drive address, data, and control signals. |
| `ACCESS` | Assert `PENABLE`; wait for `PREADY`. On `PREADY`, push the completion response into the return FIFO and return to idle. |

---

### Functional Requirements Summary

A correct implementation must:

1. Be built on the existing, verified AHB and APB modules/interfaces rather than reimplementing them.
2. Accept only valid AHB transactions in the configured address range.
3. Reject misaligned or out-of-range addresses with an AHB error response.
4. Convert AHB transactions into valid APB setup/access cycles.
5. Support both reads and writes.
6. Translate addresses into the APB-relative space.
7. Forward `HSTRB` as `PSTRB`.
8. Stall AHB until the APB transaction completes.
9. Return read data on `HRDATA` at APB completion.
10. Propagate `PSLVERR` onto `HRESP`.
11. Buffer requests and responses using FIFO-based CDC logic.
12. Keep AHB-side and APB-side control logic independent.
13. Return to idle after each transaction and allow the next transfer.

The result should be synthesizable, with correct AHB/APB handshake timing.
