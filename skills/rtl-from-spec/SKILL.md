
name: rtl-from-spec description: Implement synthesizable RTL for one block from its spec file, then lint it clean. Use for workflow stage 2a when the user gives a block spec path (e.g. peripherals/spi/SPI.md) and asks for RTL. Does not write testbenches.
Instructions
The spec is $ARGUMENTS.
Read the inputs.
Read NEX.md and the spec in full.
Read the existing RTL style references (riscv/include/*_if.sv, riscv/rtl/) and any shared files the spec names (e.g. bus/apb/include/, digital_lib/).
Check the spec before writing anything. List anything ambiguous, contradictory or missing, citing the requirement IDs involved. If any of it blocks implementation, stop and ask the user. Don't guess, and don't edit the spec.
Write the interface files first, in each module's include/ folder, using the signal names from the spec. Tell the user when they are done: the verification session can use them.
Write the RTL in rtl/, following the spec's module structure and every NEX.md coding rule:
no logic in always_ff;
one interface per module;
nothing simulation-only.
If you need to create a shared file (e.g. a bus interface or a digital_lib/ module), keep it minimal and flag it in the report.
Lint until clean.
Run make lint, or verilator --lint-only -Wall if no Makefile target exists yet.
Lint every configuration the spec lists, and fix every warning.
Only waive a warning with an inline comment that justifies it, and list every waiver in the report.
Confirm that the illegal parameter combinations named in the spec fail at elaboration.
Stay in scope.
Don't create or edit anything under verification/, and don't write testbenches.
Only touch shared files the spec requires.
Report:
a requirement traceability table: each requirement ID → file and module that implements it, or NOT IMPLEMENTED with the reason;
lint results for each configuration, plus any waivers;
assumptions and open questions;
the NEX.md git summary and a suggested feat(<block>): ... commit message.

