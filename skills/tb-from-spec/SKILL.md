
name: tb-from-spec description: Build a self-checking testbench, reference checks and coverage for one block from its spec file, without reading the RTL. Use for workflow stage 2b when the user gives a block spec path and asks for verification. Runs in parallel with RTL work.
Instructions
The spec is $ARGUMENTS.
Read the inputs.
Read NEX.md and the spec in full, especially its verification section.
Do not open anything under rtl/. You may read the interface files in include/ if they exist; otherwise use the signal tables in the spec.
Check the spec before writing anything. List anything ambiguous or untestable, citing the requirement IDs involved. If any of it blocks a test, stop and ask the user. Don't guess, and don't edit the spec.
Write a test plan. Map every test ID in the spec to the requirement IDs it checks. Every requirement ID must be covered by at least one test; list any that aren't.
Build the testbench in verification/:
Compute expected values from the spec. Never mirror RTL logic or read internal DUT signals.
Write bus driver tasks, and any external device models the spec asks for (e.g. an SPI target with configurable MISO delay).
Add protocol assertions.
Add functional coverage bins for every item listed in the spec's coverage section.
Make it self-checking: print PASS/FAIL and exit non-zero on failure.
Build setup. Add the Makefile targets the spec lists (lint, sim CFG=<name>, regress, cov, clean), with build output in build/. Cover every configuration in the spec.
Check it compiles.
If the RTL exists, compile the testbench against it and run one smoke test.
If it doesn't exist yet, lint the testbench files together with the interface files, and stop there.
Leave the full regression to regress-triage.
Stay in scope. Never edit rtl/ or include/. If an interface file seems wrong against the spec, report it.
Report:
the test plan table (test ID → requirement IDs), plus any requirements left uncovered;
a list of coverage bins;
what compiled and what ran;
open questions;
the NEX.md git summary and a suggested test(<block>): ... commit message.

