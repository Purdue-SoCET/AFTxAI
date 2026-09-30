# Project Glossary
- "AFT" = top level project name, microcontroller
- "RISCVBusiness" = core, 3 stage pipeline RISCV32IE

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
- Write Source Files first, then testbench to verify functionality