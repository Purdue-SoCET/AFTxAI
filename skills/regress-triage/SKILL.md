
name: regress-triage description: Run the full regression and coverage for one block, triage every failure as RTL bug / TB bug / spec gap with evidence, and close coverage holes. Use for workflow stage 4, after both RTL and testbench exist. Reports failures; does not fix RTL.
Instructions
The spec is $ARGUMENTS.
Read the inputs. Read NEX.md, the spec, and verification/. You may now read rtl/ for debugging, but your checks still come from the spec.
Run everything.
Run make regress and make cov across every configuration in the spec.
Run long simulations as background jobs and check their logs as they go.
Trust each tool's exit code, not its stderr.
If a tool or license is missing, record NOT RUN with the error output.
Triage each failure.
Rerun the single test and seed.
Read the log and the waveform at the first mismatch.
Classify the failure as one of the following, with evidence (test ID, requirement ID, configuration, seed, cycle/time, signals):
Class
Meaning
RTL bug
The RTL disagrees with the spec
TB bug
The testbench disagrees with the spec
Spec gap
The spec is ambiguous or silent, so either side could be "right"

Don't fix on your own.
Never edit rtl/; RTL bugs go back to the RTL session.
Propose testbench fixes, and apply them only after the user approves.
Never change an expected value, remove a check or lower a target without a spec citation and the user's approval.
Coverage.
Compare the results to the spec's targets, or NEX.md's defaults if the spec has none.
For each gap, name the feature that was never exercised (not just the bin) and propose the stimulus that would reach it.
For code that can't be reached, propose an exclusion with a reason.
After the user approves, add the tests, rerun, and show a before/after table.
Optional, when asked: mutation check.
On a scratch copy, inject a few bugs one at a time (wrong reset value, inverted mode bit, off-by-one in a counter, missing byte-strobe mask).
Confirm the regression catches each one, and report any it misses.
Restore the RTL afterwards.
Report:
a results table: each test ID × configuration → PASS / FAIL / NOT RUN;
a triage table: failure → class → evidence → proposed owner and fix;
a coverage table: metric × configuration → result vs target, plus exclusions;
commands, tool versions and seeds used;
the NEX.md git summary and a suggested commit message, if anything changed.

