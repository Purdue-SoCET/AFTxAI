# AMBA AHB-Lite Subsystem

## General Features
- **Data Width**: Configurable via `HDATA_WIDTH` parameter (default: 32 bits).
- **Transfer Types**: Burst transfers (`HBURST`) are supported.

## AHB Interconnect
- **Type**: Multi-manager AHB-Lite interconnect.
- **Parameters**: 
  - `NMANAGERS` (int): Number of manager ports.
  - `NSUBORDINATES` (int): Number of subordinate ports.
  - `AHB_MAP[NSUBORDINATES]` (logic [31:0]): Array of base addresses for subordinates.
  - `HDATA_WIDTH` (int): Data bus width, default 32.
- **Arbitration**: Fixed-priority arbiter selects the active manager.
- **Address Decoding**: Generates subordinate `HSEL` by matching the highest base address in `AHB_MAP` that is less than or equal to the transaction address (no size/mask array).
- **Multiplexing**: `ahb_mux` routes signals between the active manager and selected subordinate.
- **Interfaces**: Modports are logically reversed; the interconnect acts as a subordinate to the managers, and as a manager to the subordinates.
- **Open Items**: Implementation of a default subordinate for unmapped memory (TBD); interconnect wait state insertion logic (TBD).

## AHB Manager Adapter
- **Role**: Bridges a generic initiator to the AHB bus.
- **Parameters**: `HDATA_WIDTH` (default 32).
- **Upstream Interface**: Uses `bus_protocol_if` (`bus/generic/`) to connect to the generic manager.
- **Downstream Interface**: Uses `ahb_if` to connect to the AHB interconnect.

## AHB Subordinate Adapter
- **Role**: Bridges the AHB bus to a generic peripheral.
- **Parameters**:
  - `BASE_ADDR`: Base address of the peripheral.
  - `NUM_WORDS`: Number of words in the address space.
  - `HDATA_WIDTH`: Data bus width, default 32.
- **Address Checking & Error Handling**: The subordinate performs its own bounds checking against `BASE_ADDR` and `NUM_WORDS`. If the check fails (accessing an unmapped/invalid offset), the subordinate adapter generates an AHB error response (`HRESP = ERROR`).
- **Upstream Interface**: Uses `ahb_if` to connect to the AHB interconnect.
- **Downstream Interface**: Uses `bus_protocol_if` (`bus/generic/`) to connect to the generic subordinate.

## Shared Includes

### AHB Package (`ahb_pkg`)
- **Path**: `bus/ahb/include/ahb_pkg.sv`
- **Purpose**: Defines standard AMBA AHB-Lite enumeration types.
- **Types Defined**:
  - `HTRANS_t` (logic [1:0]): Transfer types (`IDLE`, `BUSY`, `NONSEQ`, `SEQ`).
  - `HBURST_t` (logic [2:0]): Burst types (`SINGLE`, `INCR`, `WRAP_4`, `INCR_4`, `WRAP_8`, `INCR_8`, `WRAP_16`, `INCR_16`).
  - `HSIZE_t` (logic [2:0]): Transfer sizes (`BYTE`, `HALFWORD`, `WORD`, `DOUBLEWORD`, `FOUR_WORD_LINE`, `EIGHT_WORD_LINE`).

### AHB Interface (`ahb_if`)
- **Path**: `bus/ahb/include/ahb_if.sv`
- **Purpose**: Parameterized SystemVerilog interface carrying AHB signals.
- **Parameters**: 
  - `ADDR_WIDTH` (default 32)
  - `DATA_WIDTH` (default 32)
- **Features**: 
  - Includes `HWSTRB` for write strobes.
  - Internally ties `HREADY` to `HREADYOUT` for simplified connections in single-subordinate local contexts.
- **Modports**:
  - `manager`: Drives control, address, and write data (`HWRITE`, `HADDR`, `HWDATA`, etc.); reads responses (`HREADY`, `HRESP`, `HRDATA`).
  - `subordinate`: Reads control and address (`HSEL`, `HADDR`, `HWRITE`, etc.); drives responses (`HREADYOUT`, `HRESP`, `HRDATA`).

