# Project Overview

AiFT is a RISC-V microcontroller system-on-chip implemented in SystemVerilog.
It integrates a 32-bit RISC-V core with a two-tier AMBA bus fabric (AHB for the
core, DMA, and memories; APB for register-mapped peripherals, joined by an
AHB-to-APB bridge), on-chip and off-chip memory, and a set of peripherals. The
goal is a fully synthesizable, verified design taken through tapeout.

Treat this file as the primary engineering guidance for working in this
repository. The architectural specification in `docs/AiFT_spec.md` is the
authoritative source for system behavior, address maps, and block
requirements. Where this file and the specification disagree on architecture,
the specification wins; where they disagree on process or conventions, this
file wins.

# Project Glossary

- **AHB / APB**: AMBA AHB (high-bandwidth bus) and AMBA APB (peripheral bus).
  APB transfers are single-beat only; bursts never reach APB.
- **Bridge**: the AHB-to-APB bridge, which appears as one AHB slave exposing the
  whole APB peripheral set.
- **FF RAM**: the on-chip boot RAM region (see the AHB address map).
- **Printer**: a simulation-only console-output slave at `0xB000_0000`. It must
  never be synthesized; guard it so it is excluded from synthesis builds.
- **GPIOBOOT**: the boot-related GPIO region in the APB address map.
- **CLINT / PLIC**: the standard RISC-V core-local interruptor and
  platform-level interrupt controller.
- **I/O Mux**: the pin-muxing block that selects which peripheral function
  drives each physical pin.

# Clocks, Resets, and Naming

- Core/AHB clock: `hclk`, target 100 MHz. APB clock: `pclk`, target 12.5 MHz.
- AMBA-style reset names: `hresetn`, `presetn` (active-low).
- Bus signals follow AMBA naming (`haddr`, `htrans`, `hready`, `psel`,
  `penable`, `pready`, etc.).
- The `hclk`/`pclk` relationship and the reset style (synchronous vs.
  asynchronous assertion/deassertion) are open questions; see
  "Open Specification Questions". Do not assume either.

# Project Structure

## Top-Level Resources

- `docs/` — Architecture specification, block specifications, and design notes.
- `docs/assumptions.md` — Record of every assumption made where the
  specification is ambiguous.
- `digital_lib/` — Reusable RTL building blocks (FIFOs, CDC synchronizers,
  arbiters, and other common digital blocks).
- `sw/` — Firmware, boot code, linker scripts, and the self-checking software
  regression suite.
- Each major hardware block has its own top-level directory.

All paths in this file are relative to the repository root.

## Major Module Structure

Each major module uses the following structure:

- `include/` — Interfaces, packages, parameters, and shared definitions.
- `src/` — Synthesizable SystemVerilog source files.
- `tb/` — Testbenches and verification code.
- `wav/` — Waveform viewer configuration files only (e.g. `.gtkw`, `.tcl`).
  Generated waveform dumps are build output and are not committed.
- `Makefile` — Standard development targets (see "Simulation and Build").

When adding a new major module, follow this structure unless there is a
documented reason not to.

# Engineering Conventions

## SystemVerilog

- All RTL must be written in SystemVerilog.
- Prefer synthesizable SystemVerilog constructs.
- Do not introduce Verilog-only coding styles unless required for tool
  compatibility.
- Use `interface` definitions (with modports) for connections between major
  modules where practical. Bus interfaces (AHB, APB) live in the bus fabric's
  `include/` directory and are shared by all producers and consumers.
- Use one primary module/class/interface per source file when practical.
- Use `.sv` for SystemVerilog source files and `.svh` only for include/header
  content.
- Use `snake_case` for signal, module-local variable, and instance names.
- Use descriptive signal names. Avoid abbreviations unless they are
  industry-standard.
- Use parameters instead of hard-coded architectural constants.
- Avoid unnecessary global state.
- Clearly separate combinational and sequential logic.
- Explicitly define reset behavior for every state-holding element.
- Do not infer hardware behavior from comments when the RTL behavior is
  different; the RTL is authoritative.
- Bus protocol behavior must be cycle-accurate to the AMBA specification.

## RTL Design Rules

Before modifying RTL:

1. Understand the existing module hierarchy.
2. Identify the module's interfaces and architectural role.
3. Read `docs/AiFT_spec.md` and any block-level specification in `docs/`.
4. Check existing implementations in this repository for established design
   patterns.
5. Determine whether the change affects other modules or interfaces.

When modifying an existing interface:

- Identify all producers and consumers of the interface.
- Update all affected modules.
- Update affected testbenches.
- Update documentation if the interface is architectural.
- Do not silently break existing connections.

Prefer small, localized changes over unnecessary architectural rewrites.

# Source and Verification Workflow

For every new hardware feature:

1. Define or confirm the required behavior from the specification.
2. Implement the RTL.
3. Create or update the corresponding testbench.
4. Run simulation.
5. Inspect failures and waveforms when necessary.
6. Fix RTL or testbench issues.
7. Run lint/static checks.
8. Run synthesis checks when a synthesis tool is configured.
9. Only consider the change complete after verification passes.

Write the source RTL before writing the testbench when implementing a new
module. Checkers, scoreboards, reference models, and assertions must be derived
from the specification, not from reading the RTL under test, so that the
testbench can catch RTL that disagrees with the specification.

# Verification Strategy

Verification follows three levels, matching the specification:

1. **Block level** — Every peripheral has a UVM testbench with both directed
   and constrained-random tests. Small leaf modules (e.g. `digital_lib`
   components) may use plain SystemVerilog testbenches.
2. **Bus level** — AHB and APB protocol checkers (SystemVerilog assertions)
   and bus functional models for standalone verification of the AHB
   interconnect, the AHB-to-APB bridge, and the APB interconnect.
3. **System level** — Full-SoC simulation running compiled firmware from
   `sw/`. System tests are self-checking and report pass/fail through the
   Printer console.

Use:

- SystemVerilog assertions for protocol, functional, and invariant checks.
- Directed tests for known corner cases.
- Constrained-random testing with functional coverage where it provides
  useful coverage.

Verification should test both:

- Normal/expected behavior.
- Invalid, boundary, and corner-case behavior.

A module is not considered complete merely because it compiles.

At minimum, verification should demonstrate:

- Correct reset behavior.
- Correct operation under normal inputs.
- Correct behavior at boundary conditions.
- Correct handling of invalid or unexpected inputs where applicable.
- No unintended X/Z propagation in relevant simulation scenarios.
- Correct interface/protocol behavior.

## Waveforms

- Testbenches dump waveforms in VCD or FST format so they can be analyzed by
  NEX's waveform tooling, in addition to any simulator-native format.
- Waveform dumps are written to the build output directory, not committed.

# Toolchain

Use the following tools. Do not ask which tool to use for these roles, and do
not substitute other tools.

| Role                                  | Tool                          |
| ------------------------------------- | ----------------------------- |
| Lint / static checks                  | Verilator (`--lint-only`)     |
| Fast simulation, coverage             | Verilator + LCOV              |
| UVM: CPU core, bus fabric, top level  | Cadence Xcelium               |
| UVM: peripherals                      | Siemens Questa                |
| Waveform viewing                      | GTKWave                       |
| Firmware compilation                  | riscv-gcc                     |
| Scripting                             | python3                       |
| Place and route                       | Cadence Innovus               |
| DRC / LVS                             | Cadence Pegasus               |
| Parasitic extraction                  | Cadence Quantus               |
| Analog schematic / layout / SPICE     | Cadence Virtuoso / Spectre    |
| FPGA prototyping                      | Intel Quartus                 |
| Version control                       | Git                           |
| Synthesis                             | Not yet selected (see below)  |

No synthesis or static timing analysis tool has been selected. Do not run,
script, or claim synthesis or timing results until one is added to this table.

## Loading Tools

Tools are provided through environment modules:

    module avail        # list available tools
    ml <tool>           # load a tool

If `module`/`ml` is not available in the current shell, source the module
system initialization script before retrying, rather than searching for tool
binaries manually. Load tools inside Makefile recipes or scripts so builds do
not depend on interactive shell state.

# Simulation and Build

Use the module's Makefile for standard development operations. Every major
module's Makefile provides these targets, where applicable:

| Target                             | Purpose                                   |
| ---------------------------------- | ----------------------------------------- |
| `make lint`                        | Verilator lint of the module's RTL        |
| `make sim TEST=<name> SEED=<n>`    | Run one test (default seed if omitted)    |
| `make regress`                     | Run the module's full test list           |
| `make cov`                         | Run with coverage and generate a report   |
| `make wave TEST=<name>`            | Run one test with waveform dumping        |
| `make clean`                       | Remove all generated files                |

Before introducing a new tool or build command, check the existing Makefile
and repository configuration. Do not create ad-hoc build procedures when an
existing Makefile target already provides the required operation. When adding
a new module, provide these same targets with these same names.

# Agent Operating Rules

The agent must:

1. Inspect the repository before making architectural assumptions.
2. Read relevant documentation before modifying RTL.
3. Search the repository for existing implementations before creating new
   infrastructure, and reuse existing modules (including `digital_lib/`)
   whenever appropriate.
4. Preserve existing interfaces unless the requested task explicitly requires
   an interface change.
5. Avoid modifying unrelated files.
6. Never delete or replace working RTL without understanding its dependencies.
7. Never claim that RTL is verified unless the relevant verification has
   actually been run.
8. Never claim synthesis success unless synthesis has actually been run.
9. Clearly distinguish between:
   - Implemented
   - Simulated/verified
   - Linted
   - Synthesized
   - Not yet verified

When uncertain about an architectural requirement, inspect `docs/` and the
existing RTL first. If the requirement remains ambiguous:

- For a block-local detail, record the assumption in `docs/assumptions.md`
  before implementing it.
- For anything that affects the address map, a bus interface, clocking,
  reset, or the interrupt architecture, stop and ask before implementing.

# Open Specification Questions

The following are unresolved in the current specification. Do not resolve any
of them silently; ask, or record an explicit assumption as described above.

- **Address map overlap**: the I/O Mux (`0x8000_6000`–`0x8000_6FFF`) and
  GPIOBOOT (`0x8000_6000`–`0x8FFF_FFFF`) ranges overlap in the APB map.
- **ISA**: RV32I vs. RV32E is undecided, and extensions are not yet chosen.
- **Core memory system**: the specification calls for split L1 caches and
  TLBs, but no MMU/virtual-memory scheme (e.g. Sv32) or privilege modes are
  specified.
- **Off-chip memory controller**: the memory type is a placeholder
  (DDR/SPI-flash/etc.) while the address map labels the region off-chip SRAM.
- **Clock relationship**: whether `pclk` is a synchronous divided clock of
  `hclk` (HCLK/8) or an asynchronous domain requiring CDC in the bridge.
- **Reset style**: synchronous vs. asynchronous assertion and deassertion,
  and reset synchronization strategy.
- **UART debugger**: whether it is a simple printf-style UART or implements a
  debug transport.
- **Synthesis/STA tool**: not yet selected.

When one of these is resolved, update the specification and remove it from
this list.

# Change Discipline

For every significant change, the agent should be able to explain:

- What was changed.
- Why it was changed.
- Which files were modified.
- Which interfaces were affected.
- What verification was performed.
- What remains unverified.

Do not make broad refactors unless explicitly requested.

Prefer incremental changes that can be compiled and verified independently.

## Git Workflow

- Create a descriptively named branch before making changes; never commit
  directly to `main`.
- Keep each branch focused on one task.
- At the end of a task, show `git status`, `git diff --stat`, the key files
  modified, and a suggested commit message.

# Repository Hygiene

Do not commit generated files unless the repository explicitly requires them.

Generated files include:

- Simulator output and temporary compilation files
- Build directories
- Waveform dumps
- Logs
- Coverage databases and reports
- Synthesis, place-and-route, and signoff artifacts
- Compiled firmware images

Keep source, documentation, verification, and generated artifacts separated,
and keep `.gitignore` up to date when a new tool produces new output types.

# Documentation

Architectural behavior must be documented in `docs/`.

Documentation should describe:

- Module purpose
- Interfaces
- Clock/reset behavior
- Address maps
- Register maps
- Bus protocols
- Interrupt behavior (including the PLIC source each peripheral drives)
- Configuration parameters
- Important architectural assumptions

If RTL behavior changes an architectural interface or specification, update the
corresponding documentation in the same change.