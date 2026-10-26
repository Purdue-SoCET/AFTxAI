## CLINT Functional Specification

### Overview

The Core Local Interruptor (`clint`) provides two local interrupt sources for each RISC-V hart:

- Machine software interrupts (`MSIP`)
- Machine timer interrupts (`MTIMER`)

It supports `NUM_HARTS` harts and exposes a memory-mapped register interface for configuration and status. This document is detailed enough for another LLM or hardware designer to regenerate a functionally equivalent module.

---

### Reuse of Existing Verified Modules

**The CLINT must be built on the interfaces and modules that already exist in the repository and are already verified.**

- Use the existing `bus_protocol_if` (`peripheral_vital` modport) and `clint_if` (`clint` modport) as-is. Do not redefine, duplicate, or modify them.
- Do not reimplement bus-protocol behavior that the existing bus modules/interfaces already provide.
- The CLINT itself only adds the logic specified here: the timer, compare registers, MSIP bits, interrupt/clear-pulse generation, and register decode.

---

### Module Interface

```systemverilog
module clint #(
    parameter NUM_HARTS = 1
) (
    input CLK,
    input nRST,
    bus_protocol_if.peripheral_vital busif,
    clint_if.clint clif
);
endmodule
```

#### Inputs

| Signal | Description |
|---|---|
| `CLK` | System clock |
| `nRST` | Active-low reset |
| `busif.wen` | Write enable |
| `busif.ren` | Read enable |
| `busif.addr[31:0]` | Register address |
| `busif.wdata[31:0]` | Write data |
| `busif.strobe[3:0]` | Byte strobe / write mask |

#### Outputs

| Signal | Description |
|---|---|
| `clif.mtime[63:0]` | Global time counter visible to all harts |
| `clif.timer_int[NUM_HARTS-1:0]` | Per-hart timer interrupt request |
| `clif.clear_timer_int[NUM_HARTS-1:0]` | Per-hart timer interrupt clear pulse |
| `clif.soft_int[NUM_HARTS-1:0]` | Per-hart software interrupt request |
| `clif.clear_soft_int[NUM_HARTS-1:0]` | Per-hart software interrupt clear pulse |
| `busif.error` | Invalid access flag |
| `busif.rdata[31:0]` | Read data |
| `busif.request_stall` | Fixed low (the CLINT never stalls the bus) |

#### Interrupt interface (`clint_if`)

Carries interrupt signals and `mtime` to the top-level interrupt pipeline.

```systemverilog
interface clint_if #(
    parameter NUM_HARTS=1
) ();
    logic [NUM_HARTS-1:0] timer_int, clear_timer_int, soft_int, clear_soft_int;
    logic [63:0] mtime;

    modport clint (
        output timer_int, clear_timer_int, soft_int, clear_soft_int, mtime
    );

    modport top (
        input timer_int, clear_timer_int, soft_int, clear_soft_int, mtime
    );
endinterface
```

---

### Memory Map

Address constants:

```systemverilog
localparam logic [31:0] MSWI_BASE_ADDR    = 32'h0,
                        MTIMER_BASE_ADDR  = MSWI_BASE_ADDR + 32'h4000,
                        MTIMER_TIME_ADDR  = MTIMER_BASE_ADDR + 32'h7FF8,
                        MTIMER_TIMEH_ADDR = MTIMER_TIME_ADDR + 32'h4;
```

Per-hart addresses:

```systemverilog
MSWI_MSIP_ADDR[i]   = 0x0000 + 4*i
MTIMER_CMP_ADDR[i]  = 0x4000 + 8*i
MTIMER_CMPH_ADDR[i] = 0x4004 + 8*i
```

| Register | Address | Width | Meaning |
|---|---|---|---|
| `MSIP[i]` | `0x0000 + 4*i` | 1 bit | Software interrupt for hart `i` |
| `MTIMECMP[i]` | `0x4000 + 8*i` | 32 bits | Low 32 bits of timer compare for hart `i` |
| `MTIMECMPH[i]` | `0x4004 + 8*i` | 32 bits | High 32 bits of timer compare for hart `i` |
| `MTIME` | `MTIMER_TIME_ADDR` (`0xBFF8`) | 32 bits | Low 32 bits of global timer |
| `MTIMEH` | `MTIMER_TIMEH_ADDR` (`0xBFFC`) | 32 bits | High 32 bits of global timer |

---

### Functional Behavior

#### Global time counter

```systemverilog
logic [63:0] mtimefull, mtimefull_next;
logic [31:0] mtime, mtimeh;
```

- `mtimefull` increments by 1 every clock cycle (`mtimefull_next = mtimefull + 1`).
- `mtimefull` is exposed as `clif.mtime`.
- `mtime` is the lower 32 bits and `mtimeh` is the upper 32 bits.
- A bus write overrides the increment:

```systemverilog
if (busif.wen && busif.addr == MTIMER_TIME_ADDR) begin
    mtimefull_next = {mtimefull[63:32], busif.wdata};
end else if (busif.wen && busif.addr == MTIMER_TIMEH_ADDR) begin
    mtimefull_next = {busif.wdata, mtimefull[31:0]};
end
```

Writing `MTIME` updates the low 32 bits, writing `MTIMEH` updates the high 32 bits, and otherwise the timer is free-running.

#### Timer compare registers

Each hart has a 64-bit compare value, programmed through two 32-bit registers:

```systemverilog
logic [NUM_HARTS-1:0] [63:0] mtimecmpfull, mtimecmpfull_next;
logic [NUM_HARTS-1:0] [31:0] mtimecmp, mtimecmph;
```

```text
if write to MTIMECMP[i]:
    mtimecmpfull_next[i] = {mtimecmpfull[i][63:32], wdata}
else if write to MTIMECMPH[i]:
    mtimecmpfull_next[i] = {wdata, mtimecmpfull[i][31:0]}
```

#### Timer interrupt generation

For each hart `i`:

```systemverilog
assign timer_int[i] = (mtimefull >= mtimecmpfull[i]);
assign clif.timer_int[i] = timer_int[i];
assign clif.clear_timer_int[i] = !timer_int[i] && prev_timer_int[i];
```

- `timer_int[i]` is level-sensitive: asserted while `mtimefull >= mtimecmpfull[i]`, deasserted otherwise.
- `clear_timer_int[i]` is a one-cycle pulse on the **falling edge** of `timer_int[i]`.

#### Software interrupts (MSIP)

Each hart has one software interrupt bit:

```systemverilog
logic [NUM_HARTS-1:0] msip, msip_next, msip_last;

assign msip_next[i] = (busif.addr == MSWI_MSIP_ADDR[i] && busif.wen) ? busif.wdata[0] : msip[i];
assign clif.soft_int[i] = msip[i];
assign clif.clear_soft_int[i] = ~msip[i] && msip_last[i];
```

- Writing 1 to `MSIP[i]` sets the hart's software interrupt; writing 0 clears it.
- `soft_int[i]` is level-sensitive.
- `clear_soft_int[i]` is a one-cycle pulse on the falling edge of `msip[i]`.

---

### Read Behavior

```systemverilog
always_comb begin
    {busif.error, busif.rdata} = {1'b1, 32'hBAD1BAD1};
    if (busif.addr == MTIMER_TIME_ADDR) {busif.error, busif.rdata} = {1'b0, mtime};
    else if (busif.addr == MTIMER_TIMEH_ADDR) {busif.error, busif.rdata} = {1'b0, mtimeh};
    for (int i = 0; i < NUM_HARTS; i = i + 1) begin
        if (busif.addr == MSWI_MSIP_ADDR[i]) {busif.error, busif.rdata} = {1'b0, 31'h0, msip[i]};
        else if (busif.addr == MTIMER_CMP_ADDR[i]) {busif.error, busif.rdata} = {1'b0, mtimecmp[i]};
        else if (busif.addr == MTIMER_CMPH_ADDR[i]) {busif.error, busif.rdata} = {1'b0, mtimecmph[i]};
    end
end
```

For any unrecognized address: `busif.error = 1` and `busif.rdata = 32'hBAD1BAD1`.

`busif.request_stall` is hardwired to 0.

---

### Reset and State Update

State updates are synchronous to `CLK` with asynchronous active-low reset on `nRST`:

```systemverilog
always_ff @(posedge CLK, negedge nRST) begin
    if (!nRST) begin
        mtimefull <= '0;
        mtimecmpfull <= '0;
        msip <= '0;
        msip_last <= '0;
        prev_timer_int <= '0;
    end else begin
        mtimefull <= mtimefull_next;
        mtimecmpfull <= mtimecmpfull_next;
        msip <= msip_next;
        msip_last <= msip;
        prev_timer_int <= timer_int;
    end
end
```

---

### Key Behavioral Rules

1. `mtime` increments every cycle unless a bus write overwrites it.
2. `timer_int[i]` is true whenever `mtime >= mtimecmp[i]`.
3. `soft_int[i]` is true whenever `MSIP[i]` is set.
4. `clear_timer_int[i]` and `clear_soft_int[i]` are one-cycle pulses on deassertion, not level signals.
5. Bus accesses outside the CLINT address map return an error.
6. `busif.request_stall` is hardwired to 0; the CLINT never stalls the bus.

---

### Regeneration Checklist

1. Reuse the existing, verified `bus_protocol_if` and `clint_if`.
2. Create a parameterized module `clint #(NUM_HARTS)`.
3. Maintain a 64-bit global timer `mtimefull` that increments every cycle.
4. Maintain one 64-bit compare register per hart.
5. Generate `timer_int[i] = (mtimefull >= mtimecmpfull[i])`.
6. Maintain one `msip[i]` bit per hart and expose `soft_int[i] = msip[i]`.
7. Use reset on `nRST` as shown above.
8. Decode reads/writes for `MTIME`, `MTIMEH`, `MSIP[i]`, `MTIMECMP[i]`, and `MTIMECMPH[i]`.
9. Return `error = 1` and `rdata = 32'hBAD1BAD1` for invalid addresses.
10. Generate clear pulses on the falling edge of each interrupt status:
    - `clear_timer_int[i] = !timer_int[i] && prev_timer_int[i]`
    - `clear_soft_int[i] = ~msip[i] && msip_last[i]`

---

### Summary

The CLINT is a per-hart, memory-mapped core-local interrupt controller. It maintains a shared 64-bit timer, compares it against per-hart compare values to generate timer interrupts, and provides a per-hart software-interrupt register (`MSIP`) for inter-processor signaling, exposing all state and status through a simple bus interface.
