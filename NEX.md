# Project Overview

This project is a complete RISC-V microcontroller implemented in SystemVerilog.
The design includes a RISC-V 32-bit CPU core, system buses, memory, and peripheral
modules. The long-term goal is a fully synthesizable, verified design suitable
for tapeout.

The AI agent must treat this document as the primary engineering guidance for
working within this repository.

# Project Structure

## Top-Level Resources

- `/docs` — Architecture documentation, specifications, and design notes.
- `/digital_lib` — Reusable RTL/IP including FIFOs, CDC synchronizers,
  arbiters, and other common digital building blocks.
- Each major hardware block should have its own directory.

## Major Module Structure

Each major module should use the following structure:

- `/include` — Interfaces, packages, parameters, and shared definitions.
- `/src` — Synthesizable SystemVerilog source files.
- `/tb` — Testbenches and verification code.
- `/wav` — Simulation waveforms and waveform configuration files.

When adding a new major module, follow this structure unless there is a
documented reason not to.

# Engineering Conventions

## SystemVerilog

- All RTL must be written in SystemVerilog.
- Prefer synthesizable SystemVerilog constructs.
- Do not introduce Verilog-only coding styles unless required for tool
  compatibility.
- Use `interface` definitions for connections between major modules where
  practical.
- Use one primary module/class/interface per source file when practical.
- Use `.sv` for SystemVerilog source files and `.vh`/`.svh` only for
  appropriate include/header content.
- Use `snake_case` for signal, module-local variable, and instance names.
- Use descriptive signal names. Avoid abbreviations unless they are
  industry-standard.
- Use parameters instead of hard-coded architectural constants.
- Avoid unnecessary global state.
- Clearly separate combinational and sequential logic.
- Explicitly define reset behavior for every state-holding element.
- Do not infer hardware behavior from comments when the RTL behavior is
  different; the RTL is authoritative.

## RTL Design Rules

Before modifying RTL:

1. Understand the existing module hierarchy.
2. Identify the module's interfaces and architectural role.
3. Check `/docs` for specifications or requirements.
4. Check existing implementations for established design patterns.
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

1. Define or confirm the required behavior.
2. Implement the RTL.
3. Create or update the corresponding testbench.
4. Run simulation.
5. Inspect failures and waveforms when necessary.
6. Fix RTL or testbench issues.
7. Run lint/static checks.
8. Run synthesis checks when applicable.
9. Only consider the change complete after verification passes.

Write the source RTL before writing the testbench when implementing a new
module, unless the existing project methodology explicitly requires
test-first development.

# Verification Strategy

Every major hardware block must have a dedicated verification environment.

Use:

- SystemVerilog testbenches for smaller modules.
- UVM testbenches for major/complex blocks when appropriate.
- SystemVerilog assertions for protocol, timing-independent functional,
  and invariant checks.
- Directed tests for known corner cases.
- Randomized testing where it provides useful coverage.

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

# Simulation and Build

Use the module's Makefile for standard development operations.

The Makefile should provide targets for, where applicable:

- Simulation
- Test execution
- Waveform generation
- Linting
- Synthesis
- Cleaning generated files

Before introducing a new tool or build command, check the existing Makefile
and repository configuration.

Do not create ad-hoc build procedures when an existing Makefile target already
provides the required operation.

# AI Agent Operating Rules

The AI agent must:

1. Inspect the repository before making architectural assumptions.
2. Read relevant documentation before modifying RTL.
3. Search for existing implementations before creating new infrastructure.
4. Reuse existing modules/IP whenever appropriate.
5. Preserve existing interfaces unless the requested task explicitly requires
   an interface change.
6. Avoid modifying unrelated files.
7. Never delete or replace working RTL without understanding its dependencies.
8. Never claim that RTL is verified unless the relevant verification has
   actually been run.
9. Never claim synthesis success unless synthesis has actually been run.
10. Clearly distinguish between:
    - Implemented
    - Simulated/verified
    - Linted
    - Synthesized
    - Not yet verified

When uncertain about an architectural requirement, inspect `/docs` and the
existing RTL first. If the requirement remains ambiguous, document the
assumption before implementing it.

# Change Discipline

For every significant change, the AI agent should be able to explain:

- What was changed.
- Why it was changed.
- Which files were modified.
- Which interfaces were affected.
- What verification was performed.
- What remains unverified.

Do not make broad refactors unless explicitly requested.

Prefer incremental changes that can be compiled and verified independently.

# Repository Hygiene

Do not commit generated files unless the repository explicitly requires them.

Generated files include, where applicable:

- Simulator output
- Temporary compilation files
- Build directories
- Generated waveforms
- Logs
- Synthesis artifacts

Keep source, documentation, verification, and generated artifacts separated.

# Documentation

Architectural behavior must be documented in `/docs`.

Documentation should describe:

- Module purpose
- Interfaces
- Clock/reset behavior
- Address maps
- Register maps
- Bus protocols
- Interrupt behavior
- Configuration parameters
- Important architectural assumptions

If RTL behavior changes an architectural interface or specification, update the
corresponding documentation.

# Available Tools

Run:

    module avail

to see available tools.

Run:

    ml <tool>

to load a required tool/module.

Before using a tool not already used by the project, inspect the existing
Makefiles and documentation to determine the expected toolchain.