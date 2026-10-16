# NEX.md

## Overview
AFT is a RISC-V SoC with memory mapped peripherals.
You assist across the full pre-silicon flow:
1. Architecture & spec
2. RTL design + verification (in parallel, both derived from the spec)
3. Synthesis + equivalence check
4. Place & route
5. Sign-off (STA, DRC, LVS)
6. Tape-out (GDS submission)

## Rules
### Whenever modifying this repository:
- create a semantic feature branch; if already on one, stay on it; if on `main` create on first. Never switch branches during a task.
- avoid unrelated refactoring;
- preserve the existing coding style;
- after completing the task, summarize the work by showing:
  - git status
  - git diff --stat
  - key files modified
  - a suggested commit message

### Coding Rules:
- Never put logic in an always_ff block, use next logic in always_comb;
- Create an interface file for each module;

```markdown
### Block Workflow
Each block is built from a spec file in its directory (e.g. `peripherals/spi/SPI.md`).
The spec is the only source of truth; RTL and verification are both derived from it.


| Stage | How | Session name |
|---|---|---|
| 1. Spec review | `md-revision` skill; spec is frozen after review | — |
| 2a. RTL + lint | `rtl-from-spec` skill | `<block>-rtl` |
| 2b. Testbench (parallel with 2a) | `tb-from-spec` skill | `<block>-verif` |
| 3. Independent lint | `nex --agent=linter --input-file=<file>` per RTL file | headless |
| 4. Regression + coverage | `regress-triage` skill, continuing `<block>-verif` | `<block>-verif` |
| 5. Bug fixes | reload `<block>-rtl` (`/session load`) | `<block>-rtl` |


Rules:
- RTL sessions never create or edit files under `verification/`.
- Verification sessions never edit `rtl/`, and must not read `rtl/` until their tests are written.
  Before then, they may read only the spec and the interface files in `include/`.
- If the spec is ambiguous, stop and ask. Never resolve it in code. Spec changes go back through stage 1.
- Never weaken a test to make it pass: don't change expected values, remove checks or lower coverage
  targets without the user's approval and a citation from the spec.
- Every failure is classified as one of: RTL bug, TB bug, or spec gap, with evidence.
  The user decides the fix before anything is changed.
- Reference requirement IDs (e.g. `SPI-ENG-006`) and test IDs (e.g. `T07`) in reports and commit messages.
- At the end of each stage, propose a commit (`feat(<block>): ...` for RTL, `test(<block>): ...` for verification).
  Commit only when the user approves.


Default coverage targets (a block spec may override):
| Metric | Target |
|---|---|
| Functional coverage | 100% |
| Line / branch | 100%, with listed exclusions for code that can't be reached, each with a reason |
| Toggle | >= 95%, with listed exclusions for unused bits |
```


## Repository Structure

```
AFTxAI/
├── bus/                    # On-chip bus fabric: protocols, interconnects, and bridges
│   ├── ahb/                # AMBA AHB-Lite implementation
│   │   ├── ahb_interconnect/   # Address decode and arbitration between managers and subordinates
│   │   ├── ahb_manager/        # AHB manager (initiator) interface
│   │   ├── ahb_subordinate/    # AHB subordinate (target) interface
│   │   ├── include/            # Shared packages, typedefs, and interface definitions
│   │   └── verification/       # AHB testbenches
│   ├── apb/                # AMBA APB implementation for low-bandwidth peripherals
│   │   ├── apb_completer/      # APB completer (target) interface
│   │   ├── apb_interconnect/   # APB address decode and select logic
│   │   ├── apb_requester/      # APB requester (initiator) interface
│   │   ├── include/            # Shared packages, typedefs, and interface definitions
│   │   └── verification/       # APB testbenches
│   ├── bridge/             # Protocol bridges between bus domains (e.g., AHB-to-APB)
│   └── generic/            # Protocol-agnostic interface between bus and peripherals;
│                           # simple single-cycle, register-access-based bus protocol
├── digital_lib/            # Reusable RTL building blocks (synchronizers, FIFOs, counters, etc.)
├── docs/                   # System-wide documentation 
├── peripherals/            # Memory-mapped peripheral IP
│   ├── digital_io_mux/     # Pin multiplexing between peripheral functions and GPIO
│   ├── dma/                # Direct memory access controller
│   ├── ff_ram/             # On-chip flip-flop-based RAM
│   ├── gpio/               # General-purpose I/O
│   ├── i2c/                # I2C controller
│   ├── interrupt_controller/   # RISC-V interrupt infrastructure
│   │   ├── clint/              # Core-Local Interruptor: timer and software interrupts
│   │   └── plic/               # Platform-Level Interrupt Controller: external interrupts
│   ├── pwm/                # Pulse-width modulation generator
│   ├── spi/                # SPI controller
│   ├── sram_controller/    # Off-chip SRAM controller
│   ├── timer/              # General-purpose timers
│   └── uart/               # UART serial interface
├── riscv/                  # RISC-V processor
│   ├── include/            # Core packages, ISA definitions, and shared types
│   ├── rtl/                # Synthesizable processor RTL
│   │   ├── caches/             # Instruction and data caches
│   │   ├── datapath/           # Pipeline datapath and control
│   │   └── memory/             # Memory interface and bus adapters
│   └── verification/       # Processor verification
│       ├── asmFiles/           # Assembly test programs
│       ├── tb/                 # Directed SystemVerilog testbenches
│       └── uvm/                # UVM verification environment
└── top_level/              # SoC integration connecting core, bus, and peripherals
```

## Tools and Commands
Tools are provided through environment modules:

    module list         # list loaded tools
    module avail        # list available tools
    ml <tool>           # load a tool

| Stage                              | Recommended Tool       |
| ---------------------------------- | ---------------------- |
| PDK                                | sky130/2.1.306         |
| Firmware / tests                   | riscv-gcc/13.2.0       |
| Lint + fast simulation             | verilator/5.036        |
| Coverage (Verilator)               | lcov/2.1               |
| Verification (RTL + gate-level)    | cadence/xcelium/23.03  |
| Synthesis                          | cadence/genus/21.17    |
| Equivalence (post-synth, post-PnR) | cadence/confrml/24.10  |
| Place and route                    | cadence/innovus/21.17  |
| Parasitic extraction               | cadence/quantus/23.11  |
| STA                                | cadence/ssv/21.12      |
| DRC / LVS                          | cadence/pegasus/23.20  |
