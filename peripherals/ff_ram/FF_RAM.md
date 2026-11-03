# FF_RAM Specification

## Overview
FF_RAM is a simulation-only flip-flop based RAM. It is used as a generic memory endpoint on the generic bus protocol.

## Features
- **Simulation Only**: Implemented using flip-flops/logic array with `$readmemb` and `$writememh`.
- **Parameterizable Size**: Configured via the `NBYTES` parameter.
- **ROM Mode**: Configurable as read-only via the `ROM` parameter (writes are ignored and may return an error).
- **Variable Latency**: Configurable via the `LATENCY` parameter (default 0), utilizing `request_stall` to delay the response.
- **Initialization**: Loads `meminit.bin` at time zero.
- **Dump**: Dumps contents to `memsim.hex` at the end of simulation.

## Interfaces
- **Clock & Reset**: Standard synchronous clock `clk` and active-low reset `rst_n`.
- **Bus Interface**: `bus_protocol_if.peripheral_vital` (supports `wen`, `ren`, `addr`, `wdata`, `strobe`, `rdata`, `error`, `request_stall`).

## Requirements
- `FF_RAM-REQ-001`: Shall instantiate an array of memory scaled by `NBYTES`.
- `FF_RAM-REQ-002`: Shall initialize memory from `meminit.bin` in an `initial` block.
- `FF_RAM-REQ-003`: Shall write memory to `memsim.hex` in a `final` block.
- `FF_RAM-REQ-004`: When `ROM` parameter is true, writes shall be ignored.
- `FF_RAM-REQ-005`: Memory accesses shall insert `LATENCY` wait states using `request_stall`.
- `FF_RAM-REQ-006`: Reads and writes shall respect the generic bus protocol timing (address/data sampled together).
