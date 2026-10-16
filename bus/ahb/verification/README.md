# AHB Subsystem Verification Guide

This directory contains the UVM-based verification environment for the AMBA AHB-Lite interconnect and related bus components.

## Prerequisites

The verification flow uses Cadence Xcelium for simulation and Cadence vManager/IMC for coverage. The regression scripts will automatically load the required environment modules, but if you are running tools interactively, ensure they are loaded:

```bash
module load cadence/xcelium/23.03
module load cadence/vmanager/23.03
```

All commands below should be executed from the `bus/ahb/verification` directory:
```bash
cd AFTxAI/bus/ahb/verification
```

## Directory Structure
The UVM testbench is organized into standard functional directories:
* `agent/` - UVM driver, monitor, sequencer, and transactions
* `env/` - UVM environment, scoreboard, coverage, config objects, and models
* `sequences/` - Virtual sequences defining the stimulus profiles
* `tests/` - High-level test components
* `tb/` - SystemVerilog top-level module and interfaces
* `scripts/` - Compilation and execution scripts
* `sim/` - Working directory (auto-created) for compilation outputs, logs, and coverage data

## Running the Full Regression

The easiest way to verify the subsystem and generate a coverage report is to run the automated regression script. This script executes all testcases, collects functional coverage, and merges the databases inside the `sim/` directory.

```bash
./scripts/run_regression.sh
```

### Pass/Fail Indicators (Regression)
The script will output a clean summary to the console:
* **Pass:** Indicated by `[PASS] ahb_<name>_test`. This means the test completed with `0` `UVM_ERROR`s and `0` `UVM_FATAL`s.
* **Fail:** Indicated by `[FAIL] ahb_<name>_test`. You will be directed to check the specific log file in the `sim/regression_logs/` directory.

At the end of the regression, the script merges the coverage and outputs a summary. A successful run should indicate **100%** functional coverage:
```text
[COV_REPORT] ahb_cg Coverage = 100.00%
```
Detailed HTML coverage metrics are generated in `bus/ahb/verification/sim/cov_report/index.html`.

## Running a Single Test

If you need to debug a specific scenario or run a test without the full regression overhead, use the compilation script directly.

```bash
./scripts/compile_xcelium.sh +UVM_TESTNAME=<test_name>
```

**Available Tests:**
* `ahb_base_test`: Basic sequential and non-sequential traffic without heavy contention.
* `ahb_matrix_test`: Heavy, concurrent traffic across all 4 managers and 4 subordinates driving high arbitration contention.
* `ahb_error_test`: High probability of injected wait-states and ERROR responses, testing the 2-cycle error pipeline.

### Pass/Fail Indicators (Single Test)
When running a single test, check the standard UVM Report Summary printed at the bottom of the simulation output (`xrun.log`). 

**Passing Run:**
```text
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO :   XX
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0
```

**Failing Run:**
Any `UVM_ERROR` > 0 or `UVM_FATAL` > 0 indicates a failure. 
* To debug scoreboard mismatches, search the log for `[SCB]`, `[SCB_MISMATCH]`, or `[SCB_UNEXPECTED]`.
* To debug protocol violations, search for `[DRV]` or `[MON]`.
