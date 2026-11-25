# 06 - Troubleshooting & Verified Fixes

This section records real EDA errors encountered during synthesis and static timing analysis of AFTxAI, along with their verified root causes and solutions.

---

## 1. Verilog Parser Failure on Mapped Netlist (`STA-0171`)
- **Symptom:** OpenROAD fails immediately during `read_verilog` with:
  ```text
  [ERROR STA-0171] syntax error, unexpected $write, expecting endmodule
  ```
- **Root Cause:** Synthesis preserved behavioral `$write` statements inside un-flattened debug modules and SVA assertions. Downstream timing tools require pure structural gate-level netlists.
- **Verified Fix:** Ensure Yosys runs `synth -flatten` and invokes `write_verilog -noattr`. Additionally, strip empty module declarations and simulator task calls from netlists intended for STA.

---

## 2. Missing Technology Setup in OpenROAD (`ORD-2010`)
- **Symptom:** OpenROAD aborts with:
  ```text
  [ERROR ORD-2010] No technology has been read.
  ```
- **Root Cause:** `read_verilog` and `link_design` were invoked before reading a Technology LEF (`.tlef`).
- **Verified Fix:** Always read the Technology LEF first in OpenROAD Tcl scripts:
  ```tcl
  read_liberty /path/to/sky130_fd_sc_hd__tt_025C_1v80.lib
  read_lef /path/to/sky130_fd_sc_hd.tlef
  read_lef /path/to/sky130_fd_sc_hd_merged.lef
  read_verilog /path/to/netlist.v
  link_design aft_synth_top
  ```

---

## 3. Unresolved Cell Master `\$_TBUF_` (`ORD-2013`)
- **Symptom:** OpenROAD linking fails with:
  ```text
  [ERROR ORD-2013] Could not find cell \$_TBUF_
  ```
- **Root Cause:** Standard SKY130 Liberty does not define Yosys's internal `\$_TBUF_` cell. Standard cell libraries provide active-low enable buffers (`sky130_fd_sc_hd__ebufn_1`), whereas Yosys infers active-high enables.
- **Verified Fix:** Append `synth/tbuf_sky130.v` to the mapped netlist prior to linking. It decomposes `\$_TBUF_` into an inverter plus an `ebufn_1` cell:
  ```bash
  cat netlist_sta.v synth/tbuf_sky130.v > netlist_sta_linked.v
  ```

---

## 4. Clock-Edge Simulation Race in Verilator SRAM Model
- **Symptom:** SRAM macro reads fail in simulation by returning `0x00000000` or stale data, even though write transactions logged successful data writes.
- **Root Cause:** The behavioral OpenRAM model updates `dout0` at `negedge clk0` using nonblocking delays (`dout0 <= #(DELAY) mem[addr0]`) and clears `dout0 <= 64'bx` at `posedge clk0`. Attempting to register `dout0` using `always_ff @(negedge clk)` caused a race condition where the wrapper sampled the port before the nonblocking assignment finished.
- **Verified Fix:** Eliminate `negedge` capture flops in synthesizable RTL. Use a 3-state FSM that waits for `negedge` to settle, then cleanly latches `dout0` on the subsequent `posedge clk` while holding bus wait states (`request_stall = 1`).

---

## 5. Docker File Permissions in WSL2/Linux
- **Symptom:** Files created inside Docker containers are owned by `root:root`, preventing editing or deletion on the host.
- **Verified Fix:** Always pass `--user "$(id -u):$(id -g)"` or ensure the container user matches the host UID/GID when invoking Docker commands.
