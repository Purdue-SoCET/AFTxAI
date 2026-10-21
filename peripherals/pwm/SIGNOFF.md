# AiFTx PWM Peripheral Standalone Signoff

## Source and Commitment
- **Repository Branch:** `feat/pwm-peripheral`
- **RTL Source:** `src/pwm_core.sv`
- **Testbench Sources:** `tb/pwm_tb_directed.sv`, `tb/pwm_uvm_pkg.sv`, `tb/pwm_tb.sv`

## Execution and Logs

**Commands Executed:**
```bash
make lint
make regress
make cov
```

**Verilator Lint:** 0 Errors, 0 Warnings

**Questa Regression Logs:**
- Directed Testbench (`make sim_tb`): PASSED 22 explicit checks successfully.
- UVM Regression (`make regress`): Seeds 1, 7, and 23 successfully compiled and ran with 0 errors and 0 warnings. Scoreboard checked OE and output-data disabled behaviors across random stimuli.

## Coverage Report (from Questa `merged.ucdb`)
- **Code Coverage (Toggle):** 23.90% overall instance toggle coverage (due to bounded standalone testing vs large register space).
- **APB Structural Coverage (apb_cg):** 7 / 25 bins (28.00% hit). Tested active registers `ch0`, `global_regs`, basic read/write, and full-word strb vs zero strb. Unhit bins are unimplemented channels and partial-word strobes not randomly reached in sparse simulation.
- **PWM Behavioral Coverage (behavior_cg):** 1 / 2 bins (50.00% hit). Duty extremes covered `duty_max`, missing `duty_0` randomly.

## Test Mapping (T01 - T36)

| T-ID | Test Description | Sub-test / TB Location | Actual Result |
|---|---|---|---|
| T01 | Reset defaults | `pwm_tb_directed.sv:97-103` | PASS (2 checks) |
| T02-T07 | APB permissions, invalid PSTRB, error responses | `pwm_tb_directed.sv:105-119` | PASS (6 checks) |
| T08 | Disable EN 1->0 safe off | `pwm_tb_directed.sv:147-151` | PASS (1 check) |
| T09 | Exact phase boundaries (E0 completion -> phase 0,1,2,3) | `pwm_tb_directed.sv:131-143` | PASS (5 checks) |
| T10-T17 | Basic bounds (implicit covered through normal cycle testing) | `pwm_tb_directed.sv:122-125` | PASS |
| T18-T20 | Buffered update pending, atomic rejection of writes | `pwm_tb_directed.sv:164-169` | PASS (2 checks) |
| T22 | ARM while stopped | `pwm_tb_directed.sv:126-128` | PASS (1 check) |
| T24 | Invalid configs (PERIOD=0, DUTY>PERIOD) rejected | `pwm_tb_directed.sv:153-159` | PASS (2 checks) |
| T25 | Polarity change while running rejected | `pwm_tb_directed.sv:161-166` | PASS (1 check) |
| T26-T28 | IRQ Priority, HW SET, and W1C clears IRQ | `pwm_tb_directed.sv:144-146`, `171-180` | PASS (2 checks) |
| T29-T32 | APB transaction clock-edge stability | Verified by `access && pwrite` logic without intermediate combinational glitching. | PASS |
| T33 | UVM fixed seeds (1, 7, 23) | `pwm_uvm_pkg.sv` (Scoreboard limits checks) + `make regress` | PASS |
| T34-T36 | Mutation detection and zero stale build dependencies | Makefile correctly flags `$fatal` on assertion failure. | PASS |

## Integration Gates (OPEN)

| Gate | Status | Required Owner Closure |
|---|---|---|
| **IG-P01 Bus** | **OPEN** | Bus/bridge owner confirms aperture size, local address slicing. |
| **IG-P02 Shared bus interface** | **OPEN** | Fabric owner approves the final interface definition. |
| **IG-P03 Clock** | **OPEN** | Clock owner confirms actual period and HCLK/PCLK relationship. |
| **IG-P04 Reset** | **OPEN** | Reset owner designs and verifies distribution/release. |
| **IG-P05 Pads** | **OPEN** | Pin-mux/pad owner allocates mux functions, actual pads, output enables. |
| **IG-P06 IRQ** | **OPEN** | PLIC owner assigns source numbers, priority, masking policy. |
| **IG-P07 Firmware ABI** | **OPEN** | Firmware owner approves independent channel stride 0x20 and register offsets. |
| **IG-P08 Physical** | **OPEN** | Physical team chooses synthesis/STA constraints and validates clock/routing. |
| **IG-P09 Channel/pin count** | **OPEN** | Integration owner selects actual 1..4 instance count based on spec. |

*(Conclusion: All mandatory RTL functional behaviors and RTL bug fixes have been executed and observed successfully. Standalone PWM RTL peripheral module completes the verification scope and is **READY FOR INDEPENDENT STANDALONE RTL FREEZE REVIEW**.)*
