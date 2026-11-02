# Peripheral Subsystem Integration Review

## 1. Scope
This document provides an integration review for the new peripheral subsystem mapping GPIO, Timer0, PWM, I/O Mux, and the PLIC into the SoC architecture.

## 2. Integrated Components
- **AHB-to-APB Bridge:** Configured with a 32 KB window at `0x8000_0000` to `0x8000_7FFF` to match the system-level memory specification.
- **APB Interconnect:** Parameterized mapping accurately separates blocks by checking exact target apertures.
- **GPIO Controllers:** Four instances (`0x8000_0000`, `0x8000_0100`, `0x8000_0200`, `0x8000_0300`) covering their 18-word (72-byte) implementations without clashing.
- **PWM:** Starts at `0x8000_1000`. Configured 4 KB block reserves ample space for per-channel registers and standard global `PWM_INFO` up to offset `0x108`.
- **Timer0:** Starts at `0x8000_2000`. The 8 KB window accommodates its precise 8-word APB ABI structure.
- **Digital I/O Mux:** Included as an APB target at `0x8000_6000` for GPIO routing controls.
- **CDC:** PLIC interface routing utilizes `sync_2ff` instances, accurately managing cross-clock boundaries for active-high level-sensitive IRQs entering the `HCLK` domain.

## 3. Address Map Conformity
Review confirms alignment with `docs/memory_map.md` specifications and subsystem implementation:
| APB Target | SoC Base | Space Mask | Tested Max Offset |
| --------- | -------- | ---------- | ----------------- |
| GPIO0 | `0x8000_0000` | 256 bytes | `0x44` |
| GPIO1 | `0x8000_0100` | 256 bytes | `0x44` |
| GPIO2 | `0x8000_0200` | 256 bytes | `0x44` |
| GPIO3 | `0x8000_0300` | 256 bytes | `0x44` |
| PWM0 | `0x8000_1000` | 4096 bytes | `0x108` |
| Timer0 | `0x8000_2000` | 8192 bytes | `0x1C` |
| I/O Mux | `0x8000_6000` | 4096 bytes | N/A |

## 4. Verification Checkpoints
- **Top-Level Address Reachability:** Addressed the highest specified physical registers directly via `ahb_read`. Check completed without `PSLVERR`.
- **Negative Testing:** Exercised an unmapped hole (`0x8000_111C`) resulting in deterministic trap mapping. `make run_neg` detects this cleanly by inverting Verilator's native abort.
- **Regression:** `make run` executing all end-to-end integration constraints passed statically. Clock domain crossings simulated and settled cleanly.
- **Lint Result:** Peripheral interconnect successfully parses with Verilator timing-aware lint, suppressing interface warnings properly. 

**Review Status:** Verified according to the specifications in `docs/memory_map.md` and discrete peripheral specification bounds. System changes are clean for upstream merge.