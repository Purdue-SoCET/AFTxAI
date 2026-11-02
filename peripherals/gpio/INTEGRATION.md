# GPIO Integration Report

## 1. Commits and Base
- **Base SoC branch/commit (`main`)**: `6a689dbb8a66aa12cb319c6662444acb3c6a811a`
- **GPIO source branch/commit (`feat/gpio-peripheral`)**: `dcae94aa48253c62c02b1737670cc810da2cc996`
- **Integration Branch**: `integration/gpio-apb`

## 2. Architecture and Adapters
The integration incorporates the independently verified `gpio_apb` into the SoC's AHB/APB bus subsystem:
- **`gpio_apb_wrapper.sv`**: Connects the `apb_if.completer` to the scalar ports of `gpio_apb`. It routes `apb.PADDR[7:0]` to the peripheral since `gpio_apb` natively decodes 8-bit local register offsets and relies on the interconnect for base address decoding. 
- **APB Interconnect**: The shared interconnect compares the upper bits of `PADDR` to route transactions. Because the `ahb2apb` bridge removes `BASE_ADDR`, the APB interconnect sees a bridge-relative address (starting at `0x0000_0000`).
- **Interrupts**: The `gpio_irq` pins cross the `pclk` to `hclk` domain into the PLIC via its `irq_source` gateway. The testbench wires them to sources 1-4.

## 3. Register Mapping
The testbench mapping aligns with the current proposed memory map using a 256-byte window for each bank:
- `GPIO0`: `0x8000_0000` (mapped to APB relative `0x0000_0000`)
- `GPIO1`: `0x8000_0100` (mapped to APB relative `0x0000_0100`)
- `GPIO2`: `0x8000_0200` (mapped to APB relative `0x0000_0200`)
- `GPIO3`: `0x8000_0300` (mapped to APB relative `0x0000_0300`)

*Note on discrepancy*: The `docs/memory_map.md` proposes 8 words per bank, but the GPIO actually implements registers up to offset `0x44`. The 256-byte window (64 words) safely accommodates this, avoiding aliases in the active range.

## 4. Requirement-to-Test Matrix
| Requirement                                      | Status | Notes |
| ------------------------------------------------ | ------ | ----- |
| APB protocol and address decode                  | PASS   | Verified across 4 instanced banks. |
| Read/write/atomic aliases                        | PASS   | `OUT_SET`, `OUT_CLEAR`, etc., verified. |
| PSTRB masks and unmapped/WO-read errors          | PASS   | Unmapped and WO reads return `PSLVERR`. |
| Asynchronous GPIO inputs crossing synchronizer   | PASS   | IRQ edges reliably detected after `sync_2ff`. |
| Width configuration and masking                  | PASS   | W=1, 7, 16, 32 instanced and tested. |
| IRQ persistence, PLIC routing, and W1C clearance | PASS   | Level IRQ asserted, claimed, and completed. |
| Intentional nonzero failure detection            | PASS   | Make target captures intentional `$error`. |
| Digital I/O Mux Pads integration                 | BLOCKED| Depends on final `feat/digital-io-mux` interface contract. |

## 5. Unresolved Gates & System-Level Decisions
1. **`apb_interconnect` Address Decoder**: By default, `COMPLETER_ADDR_BITS=16` which cannot decode peripherals spaced 256 bytes apart. For GPIO, the integration test overrides it to `8`. A permanent shared-bus update is required (e.g., an array of masks per peripheral) to mix large and small peripheral windows safely on the same interconnect.
2. **PLIC CDC**: GPIO IRQs originate on `pclk` (12.5 MHz) but the PLIC is on `hclk` (100 MHz). A formal CDC strategy (e.g., level synchronizer) is required before final signoff, as currently `irq_o` directly drives `irq_source`.
3. **Mux Integration**: Final pad assignments and OE/pull routing must be agreed upon with the system owner.

## 6. Test Commands
To run the end-to-end integration regression:
```bash
module load siemens/questa/2021.4
make integration
```
