# Memory Structure

## Bus

- The data bus is 32 bits wide.
- A 4-bit write strobe gives one enable bit per byte, so byte, halfword and word writes are supported.
- Each slave responds only within its own range. Registers do not repeat (alias) at higher addresses.

## On-chip RAM (`ff_ram`)

A scratchpad with a parameterizable size of 8–32 KiB. Its implementation depends on the build target:

| Build target   | Implementation                       |
|----------------|--------------------------------------|
| Simulation     | Flip-flop array                      |
| FPGA synthesis | Wrapper around an Altera RAM         |
| ASIC           | Wrapper around a Synopsys SRAM macro |

## Off-chip SRAM Controller

- External interface: 19-bit address bus, 16-bit data bus and 10-bit control bus. That gives 2^19 × 4 B = 2 MiB, installed at `0x0002_0000 – 0x0021_FFFF`.
- Each 32-bit AHB word becomes two 16-bit external transfers.
