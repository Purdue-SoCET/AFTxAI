# 04 - Static Timing Analysis (OpenROAD STA)

Static Timing Analysis (STA) validates that all synchronous flip-flops in the design satisfy setup and hold requirements across all corners without requiring dynamic simulation vectors.

---

## 1. Timing Constraints (`synth/aft_top.sdc`)

AFTxAI targets a nominal operating clock frequency of **100 MHz** (clock period: **10.0 ns**), matching the baseline testbench environment (`top_tb.sv`).

```tcl
# SDC constraints for AFTxAI aft_synth_top
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

# Standard input/output delays (20% cycle budget for external pad/board delays)
set_input_delay -clock clk 2.0 [all_inputs -no_clocks]
set_output_delay -clock clk 2.0 [all_outputs]
```

---

## 2. Linking the Design in OpenROAD

To run timing analysis, OpenROAD must resolve both **logical timing arcs** (from Liberty `.lib`) and **physical pin locations** (from LEF):
1. **Liberty (.lib):** `sky130_fd_sc_hd__tt_025C_1v80.lib` (typical corner: 1.8V, 25°C).
2. **Technology LEF (.tlef):** `sky130_fd_sc_hd.tlef` (defines layer stack, metal pitches, routing tracks).
3. **Cell LEF (.lef):** `sky130_fd_sc_hd_merged.lef` (defines boundary boxes and pin shapes for all standard cells).

### The Tri-State Buffer (`\$_TBUF_`) Linker Problem
During synthesis, bidirectional I/O pins (e.g., `i2c0_sda`, `i2c0_scl`, GPIOs) infer tri-state drivers. Yosys leaves abstract internal cells named `\$_TBUF_ (A, E, Y)`. Because OpenROAD only recognizes PDK cell masters, linking failed with error `ORD-2013: unresolved cell master \$_TBUF_`.

**The Solution (`synth/tbuf_sky130.v`):**
We implemented `\$_TBUF_` structurally using standard SKY130HD library gates:
```verilog
module \$_TBUF_ (
    input  wire A,
    input  wire E,
    output wire Y
);
    wire enable_n;

    // Invert active-high enable E to produce active-low enable TE_B
    sky130_fd_sc_hd__inv_1 u_inv (
        .A(E),
        .Y(enable_n)
    );

    // Active-low tri-state buffer
    sky130_fd_sc_hd__ebufn_1 u_tri (
        .A(A),
        .TE_B(enable_n),
        .Z(Y)
    );
endmodule
```
By concatenating `tbuf_sky130.v` to the mapped netlist before calling OpenROAD, all cells linked with 0 unresolved masters.

---

## 3. Running OpenROAD STA

Run the automated script:
```bash
bash synth/scripts/run_sta.sh
```

---

## 4. Measured Baseline Timing Results & Bottlenecks

### Baseline STA Summary (Commit `0a1aa68`):
- **Clock:** `clk` (10.00 ns period, 100 MHz target).
- **Setup Worst Negative Slack (WNS):** **-1532.34 ns** (Massive timing violation).
- **Setup Total Negative Slack (TNS):** -1.14 × 10⁸ ns.
- **Hold WNS:** +0.20 ns (Met).
- **Unconstrained Endpoints:** 0 (All synchronous registers constrained).

### Why Was Setup Slack -1532 ns?
An inspection of the top 10 critical paths in OpenROAD revealed the root cause:
- **Critical Path Startpoint:** Memory address register in `ahb_subordinate` / `ff_ram`.
- **Fanout Load:** **16,393 downstream logic inputs!**
- Because 16 KiB was synthesized as a single monolithic flat array of 131,072 flip-flops with multiplexers, the read-address decoding logic had to drive tens of thousands of gate inputs over an unbuffered, unrouted logic tree.
- A gate driving 16,393 loads has enormous capacitive slew ($\sim 200\text{ ns}$ delay per stage), compounding through 8-10 logic levels to exceed 1.5 microseconds.

### Context: Preliminary Pre-Placement STA
These numbers reflect **pre-placement, zero-wire-load** static timing analysis. In real physical implementation, high-fanout nets are balanced using clock tree synthesis (CTS) and high-drive buffer insertion. However, a 131,072-flop memory cannot be successfully buffered or routed at 100 MHz without multi-level banking or dedicated SRAM macros.
