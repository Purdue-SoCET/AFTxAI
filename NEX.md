# Project Overview
This project is a microcontroller with a RISCV32 core, buses, and peripherals. Goal is full tapeout from scratch.

# Top Level Resource Locations
- Documentation: `/docs`
- Reusable IP (FIFOs, CDC synchronizers, arbiters): `/digital_lib`

# Submodule Resource Locations
- Each major block has its own folder with following subfolders
- Interfaces and Packages: `/include`
- Testbenches: `/tb`
- Source Files: `/src`
- Waveforms: `/wav`

# Engineering Conventions
- Use interfaces across all source modules, create new ones when necessary
- Write Source Files first, then testbench to verify functionality
- Write source files purely in SystemVerilog
- Use Makefiles for simulation, synthesis, waves, linting
- Use underscores to divide words in signal names

# Verification Strategy
- Create UVM testbenches for each major block and SystemVerilog assertion-based testbenches for every smaller submodule

# Available Tools
- Git
- gcc
- python3
- riscv-gcc
- Verilator
- Cadence Xcelium
- Siemens Questa
- GTKWave
- LCOV
- Cadence Innovus
- Cadence Virtuoso
- Cadence Spectre
- Cadence Pegasus
- Cadence Quantus
- Intel Quartus


