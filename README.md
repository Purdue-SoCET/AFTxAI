# AFTxAI

AFTxAI is an open-source 32-bit RISC-V System-on-Chip (SoC) featuring AHB-Lite and APB on-chip interconnects, cache controllers, direct memory access (DMA), vectored interrupt management (CLINT & PLIC), flexible digital I/O multiplexing, and memory-mapped peripherals.

## ASIC Synthesis and Implementation Documentation
Comprehensive guides and reproducible automation scripts for ASIC synthesis, timing analysis, and OpenRAM macro integration targeting SkyWater SKY130HD are available under:

- **[ASIC Synthesis & Implementation Guide](docs/synthesis/README.md)**
  - [01 - Environment Setup & Prerequisites](docs/synthesis/01_environment_setup.md)
  - [02 - Design Architecture & Elaboration](docs/synthesis/02_design_architecture.md)
  - [03 - Synthesis Flow & Technology Mapping](docs/synthesis/03_synthesis_flow.md)
  - [04 - Static Timing Analysis (OpenROAD STA)](docs/synthesis/04_timing_analysis.md)
  - [05 - OpenRAM Macro Optimization & Verification](docs/synthesis/05_sram_optimization.md)
  - [06 - Troubleshooting & Verified Fixes](docs/synthesis/06_troubleshooting.md)
  - [07 - Project Status & Implementation Roadmap](docs/synthesis/07_status_and_roadmap.md)

### One-Command Quick Start
```bash
# Check your local EDA setup
bash synth/scripts/check_environment.sh

# Run the 30-test SRAM equivalence regression
bash synth/scripts/run_sram_tests.sh
```

