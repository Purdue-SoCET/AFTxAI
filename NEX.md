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
│   │   ├── core/               # Pipeline datapath and control
│   │   └── memory/             # Memory interface and bus adapters
│   └── verification/       # Processor verification
│       ├── asmFiles/           # Assembly test programs
│       ├── tb/                 # Directed SystemVerilog testbenches
│       └── uvm/                # UVM verification environment
└── top_level/              # SoC integration connecting core, bus, and peripherals
```

## Tools and Commands

## Coding Standards

## Workflow

## Architecture