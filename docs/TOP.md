# AiFT SoC Top Level: Integration and Verification Spec

**Location:** `top_level/TOP.md`
**Status:** DRAFT. Not frozen until every decision in Section 3 is closed and this file has passed `md-revision`.
**Repo snapshot reviewed:** `main` at `372acf9` (2024-11-03). Re-check Section 4 against the current tree before relying on it.
**Authority:** `NEX.md` -> this file -> `docs/memory_map.md` / `docs/memory_structure.md` -> block specs. Stop and report any conflict. Do not resolve a conflict in code.

---

## 1. Scope

Build and verify `aft_top`, the top level connecting one RISC-V core, the AHB and APB fabrics, memories, and peripherals. Bring it up in the stages in Section 9.

**In scope:**
- Merging the remaining branches and fixing shared-code conflicts that block integration
- `aft_top`, adapters, clock/reset wiring, interrupt wiring, and pin wiring
- Firmware-driven SoC tests, bus-level tests, assertions, and a synthesis check

**Out of scope:**
- New peripheral features
- Pad cells, floorplanning, place and route, and sign-off
- Gate-level simulation (next phase, after this spec's exit criteria are met)

---

## 2. Rules for Nex

All `NEX.md` rules apply. In addition:

- **[TOP-PROC-001]** Do not start a stage until every decision that blocks it in Section 3 has a recorded owner decision. Recommendations are not approvals.
- **[TOP-PROC-002]** Work on one stage at a time. Stop at the end of each stage and report. Do not start the next stage without user approval.
- **[TOP-PROC-003]** Add one block per commit. Top-level wiring, shared-code fixes, and block RTL fixes go in separate commits.
- **[TOP-PROC-004]** Do not change `docs/`, block specs, block interfaces, or verified block RTL without user approval. Each approved RTL fix needs a root cause and a regression test.
- **[TOP-PROC-005]** Do not weaken, skip, or delete tests or assertions, change expected values, or lower coverage targets without user approval and a spec citation.
- **[TOP-PROC-006]** Classify every failure as RTL bug, TB bug, or spec gap, with evidence. The user decides the fix.
- **[TOP-PROC-007]** Only report a result if its command ran in this session. Quote the command and the pass/fail count. After 3 failed attempts on the same failure, stop and report what was tried.
- **[TOP-PROC-008]** RTL sessions (`top-rtl`) never edit `top_level/verification/`. Verification sessions (`top-verif`) never edit RTL, and do not read `top_level/rtl/` until their tests are written.

Do not use `make -f tools/flow/flow.mk top_level`: the flow only looks up blocks under `peripherals/`, `bus/`, and `digital_lib/`, and it fixes failures on its own. Use the `rtl-from-spec`, `tb-from-spec`, and `regress-triage` skills one stage at a time.

---

## 3. Open Decisions

The owner fills in the last column. These decisions are system-level, so Nex must not make them.

| ID | Blocks stage | Question | Recommendation | Owner decision |
|---|---|---|---|---|
| D-01 | S1 | `apb_if` signals: upper case (`PADDR`) or lower case (`paddr`)? | Upper case. It matches AMBA, the APB RTL, the bridge, and `integration/soc-peripherals`. Update `dma_controller`, `spi_wrapper`, and their testbenches. | Approved as recommended. |
| D-02 | S1 | Which document wins when the system spec and `docs/memory_map.md` disagree? Which core spec wins on TLBs? | Commit the system spec as `docs/AiFT_spec.md`. `docs/memory_map.md` wins on addresses. `riscv/SPEC.md` wins on the core (no TLB). | Approved as recommended. |
| D-03 | S2 | Corrected implemented sizes in `docs/memory_map.md` (see Section 6.3)? | Accept the sizes in Section 6.3. | Approved as recommended. |
| D-04 | S3 | Reset PC: `0x0000_8400` (`docs/memory_map.md`) or Boot ROM `0x0000_0400`? RAM has no contents at reset in silicon, unless something loads it. | Reset to Boot ROM at `0x0000_0400`. Boot code jumps to RAM. Simulation may preload both. | Approved as recommended. |
| D-05 | S3 | Clock source, and how PCLK relates to HCLK? | External HCLK input; PCLK = HCLK / 8 from a `soc_clk_rst` block. Treat the domains as asynchronous for CDC. | Approved as recommended. |
| D-06 | S4 | Which regions can the caches hold? The core currently caches every address, including peripherals. | D-cache: Boot ROM and off-chip SRAM only. I-cache: Boot ROM, on-chip RAM, and off-chip SRAM. All other accesses use a new uncached path with correct `HSIZE` and `HWSTRB`. | Approved as recommended. |
| D-07 | S4 | Core configuration: `RV32I` or `RV32E`, and cache sizes? | `RV32I`, with the existing `l1_cache` defaults until performance data justifies a change. | Approved as recommended. |
| D-08 | S6 | Which UART RTL is the real one, and how does it attach to AHB? | `uart_top` is more complete. It uses APB, so it should sit behind the APB bridge rather than attaching directly to AHB. | Selected `uart_top.sv`. Moved to APB subsystem. |
| D-09 | S6 | How do DMA registers attach, given they are an APB port in an AHB address slot? What drives `drq`? | Use a dedicated `ahb2apb` instance on HCLK at `0x9000_1000`. Tie `drq` low until a peripheral request source is specified. | Approved as recommended. |
| D-10 | S6 | How is DMA kept coherent with the write-back D-cache, given there is no flush instruction? | DMA buffers live in on-chip RAM, which D-06 makes uncached. Document this as a firmware rule. | Approved as recommended. |
| D-11 | S5, S6 | Final PLIC source IDs? | Use the table in Section 8.1. | Approved as recommended. |
| D-12 | S5 | Pin list: GPIO widths, total pads, mux functions per pad, and whether `GPIOBOOT` is instantiated? | Connect peripherals directly to `aft_top` ports until a pin table is approved. Mux routing tests stay blocked until then. | Approved as recommended. |
| D-13 | S7 | Does the core gain interrupts? `riscv/SPEC.md` excludes `Zicsr` and interrupts, but the system spec relies on trap handlers. | Add machine-mode `Zicsr`, `mret`, and timer, software, and external interrupts as a separately specified core change. Use polling tests until then. | Approved as recommended. |

---

## 4. Known Issues at the Reviewed Snapshot

Nex must confirm each item during S0 and report any that no longer apply. These came from static review and elaboration, not from running regressions.

| ID | Issue | Evidence |
|---|---|---|
| K-01 | Resolved. GPIO, PWM, and Timer integrated from `integration/soc-peripherals`. | `peripherals/{gpio,pwm,timer}` |
| K-02 | Resolved. Changed `apb_if` to use uppercase signal names across the codebase per D-01. | `apb_if.sv`, `dma_controller.sv`, `spi_wrapper.sv`, `uart_top.sv` |
| K-03 | Resolved. Case mismatch fixed by resolving K-02. | `dma_controller.sv`, `spi_wrapper.sv` |
| K-04 | Resolved. Renamed local submodules in DMA and SPI to `dma_fifo`, `spi_fifo`, and `dma_counter` to avoid collisions. | `peripherals/{dma,spi}/rtl/fifo.sv`; `peripherals/dma/rtl/counter.sv` |
| K-05 | Resolved. Consolidated `sync_2ff` instances to `digital_lib/sync_2ff.sv` using standard ports (`clk`, `rst_n`, `d_in`, `d_out`). | `digital_lib/sync_2ff.sv`; `digital_io_mux_cell.sv` |
| K-06 | Resolved. Fixed include guards in `bus_protocol_if` and `clint_if`, and removed illegal assignments to `ahb` interface inputs in `ahb_manager`. | `bus_protocol_if.sv`; `clint_if.sv`; `ahb_manager.sv` |
| K-07 | Resolved. Commented out the `bind` statement in `ahb_sva.sv`. TBs must bind or instantiate SVA manually. | `ahb_sva.sv` |
| K-08 | The AHB decoder uses base and mask, which cannot represent the map's unaligned windows such as `0x400-0x83FF`. | `ahb_interconnect.sv` |
| K-09 | The AHB arbiter rotates between managers, but both specs require fixed priority. | `ahb_interconnect.sv`; `bus/ahb/SPEC.md` |
| K-10 | `ahb2apb` removes `BASE_ADDR`, so completers see bridge-relative addresses. `i2c` defaults to the absolute `0x8000_5000`, and the mux on `main` decodes `0x5000` instead of its mapped `0x6000`. | `ahb2apb.sv:170`; `i2c.sv`; `digital_io_mux_apb.sv:24` |
| K-11 | The core's `bus_ahbm_if` (`req/ack`) has no adapter to `ahb_manager`'s `bus_protocol_if`. | `riscv/include/bus_ahbm_if.sv`; `ahb_manager.sv` |
| K-12 | The caches have no uncached path, and the core always requests word size with no write strobes. Peripheral access would cause line fills, and PLIC claims or FIFO pops could fire unintentionally. | `l1_cache.sv`; `bus_controller.sv:79` |
| K-13 | `ahb_manager` always drives `HSIZE = WORD`. | `ahb_manager.sv` |
| K-14 | The core has no CSRs, trap entry, or interrupt inputs. | `riscv/SPEC.md`; `riscv/rtl/riscv.sv` |
| K-15 | `BOOT_ADDR` defaults to `0`, and `link.ld` places code at `0x0`. Both fall in an unmapped region. | `riscv.sv`; `riscv/verification/cFiles/link.ld` |
| K-16 | `peripheral_subsystem` omits SPI0, I2C0, and `GPIOBOOT`, and has only the mux's APB registers. It does not include the PLIC. | `integration/soc_peripherals/peripheral_subsystem.sv` |
| K-17 | Resolved in `feat/uart-integration` (Selected `uart_top` and fixed APB read logic). | `uart_top.sv` |
| K-18 | No Printer RTL or model exists. | Named only in `docs/memory_map.md` |
| K-19 | Resolved. ORed the 6 internal IRQ bits to drive a 1-bit `spi_if.irq`. | `spi_wrapper.sv`; `spi_if.sv` |
| K-20 | Resolved. Timer and PWM PLIC integration testbenches updated to use their final IRQ assignments (Timer=6, PWM=5). | `peripherals/timer/tb/timer_plic_integration_tb.sv`, `peripherals/pwm/tb/pwm_tb_plic.sv` |
| K-21 | `riscv/SPEC.md` expects AHB `INCR` bursts, but `ahb_manager` issues single transfers. Functionally acceptable; report any performance impact. | `riscv/SPEC.md` §4.1; `ahb_manager.sv` |
| K-22 | Resolved. Added APB address window checks and full 12-bit address decoding. | `spi_wrapper.sv` |

---

## 5. Architecture

### 5.1 File Layout

```
top_level/
├── TOP.md
├── include/          # aft_top_if and generated map package
├── map/              # aft_map.yaml and generator
├── rtl/              # aft_top, adapters, soc_clk_rst
└── verification/
    ├── Makefile
    ├── tb/           # tb_aft_top, BFMs, SRAM model, Printer model, SVA binds
    └── fw/           # crt0, linker script, generated header, tests
```

Move or adapt `integration/soc_peripherals/peripheral_subsystem.sv` into `top_level/rtl/` during S2. Keep its existing tests passing.

### 5.2 Blocks

| Instance | Module | Fabric connection | Adapter | Clock | Base Addr | IRQ |
|---|---|---|---|---|---|---|
| Core | `riscv` | AHB mgr 0 (highest prio) | New shim to `ahb_manager` | HCLK | - | - |
| DMA data | `dma_controller.mem_bus` | AHB mgr 1 | None | HCLK | - | - |
| Boot ROM | `ff_ram` (`ROM=1`) | AHB subord | `ahb_subordinate` | HCLK | `0x0000_0400` | - |
| On-chip RAM | `ff_ram` | AHB subord | `ahb_subordinate` | HCLK | `0x0000_8400` | - |
| Off-chip SRAM | `sram_controller` | AHB subord | `ahb_subordinate` | HCLK | `0x0002_0000` | - |
| APB bridge | `ahb2apb` | AHB subord | None | HCLK, PCLK | `0x8000_0000` | - |
| DMA registers | `dma_controller.reg_bus` | AHB subord | Per D-09 | HCLK | `0x9000_1000` | 10 |
| UART | `uart_top` | APB completer | None | PCLK | `0x8000_6000` | 9 |
| CLINT | `clint` | AHB subord | `ahb_subordinate` | HCLK | `0x9001_0000` | - |
| PLIC | `plic` | AHB subord | `ahb_subordinate` | HCLK | `0xA000_0000` | - |
| Printer | TB model only | AHB subord | None | HCLK | `0xB000_0000` | - |
| GPIO0-3, GPIOBOOT | `gpio_apb_wrapper` | APB completer | None | PCLK | `0x8000_0000` (See 6.3) | 1-4, 11 |
| PWM0 | `pwm_apb_wrapper` | APB completer | None | PCLK | `0x8000_1000` | 5 |
| Timer0 | `timer_apb_wrapper` | APB completer | None | PCLK | `0x8000_2000` | 6 |
| SPI0 | `spi_wrapper` | APB completer | None | PCLK | `0x8000_4000` | 7 |
| I2C0 | `i2c` | APB completer | None | PCLK | `0x8000_5000` | 8 |
| I/O Mux | `digital_io_mux` | APB completer | None | PCLK | `0x8000_7000` | - |

- **[TOP-ARCH-001]** `aft_top` contains structural wiring only: no behavioral logic beyond tie-offs and instantiation.
- **[TOP-ARCH-002]** `aft_top` contains nothing simulation-only. The Printer and external-device models attach from the testbench. In synthesis, Printer addresses return a bus error.
- **[TOP-ARCH-003]** Each block is compiled exactly once. No duplicate module or package definitions may exist in the top-level filelist.
- **[TOP-ARCH-004]** Each new module has its own interface file and follows `NEX.md` coding rules.

---

## 6. Address Map

### 6.1 Rules

- **[TOP-MAP-001]** `top_level/map/aft_map.yaml` is the single source for SoC addresses and IRQ IDs. It generates the SV package and C header. Do not hand-edit generated files.
- **[TOP-MAP-002]** The YAML must match `docs/memory_map.md`. The build fails if generated files are stale.
- **[TOP-MAP-003]** Every address outside an implemented range returns a bus error. Registers do not alias at higher addresses.
- **[TOP-MAP-004]** Each decode window is a single inclusive range, and no windows overlap. Elaboration or a generator check fails otherwise.
- **[TOP-MAP-005]** APB completers use bridge-relative addresses. `ahb2apb.BASE_ADDR = 0x8000_0000`; instantiate each completer's base as its offset from that value.

### 6.2 AHB Windows

| Subordinate | Window | Implemented |
|---|---|---|
| Boot ROM | `0x0000_0400 - 0x0000_83FF` | 1,024 words |
| On-chip RAM | `0x0000_8400 - 0x0001_FFFF` | 4,096 words |
| Off-chip SRAM | `0x0002_0000 - 0x7FFF_FFFF` | 524,288 words |
| APB bridge | `0x8000_0000 - 0x9000_0FFF` | `0x8000_0000 - 0x8000_7FFF` |
| DMA | `0x9000_1000 - 0x9000_1FFF` | 5 words |
| UART | Moved to APB (See Section 6.3) | Per D-08 |
| CLINT | `0x9001_0000 - 0x9FFF_FFFF` | See 6.3 |
| PLIC | `0xA000_0000 - 0xAFFF_FFFF` | 16,777,216 words |
| Printer (simulation only) | `0xB000_0000 - 0xBFFF_FFFF` | 1 word |
| Unmapped | Everything else, including `0x0000_0000 - 0x0000_03FF` | Bus error |

### 6.3 APB Windows and Proposed Corrections (D-03)

| Peripheral | Base | Window | `memory_map.md` size | Size needed by RTL |
|---|---|---|---|---|
| GPIO0-3 | `0x8000_0000/100/200/300` | 256 B each | 8 words | 18 words (through `0x44`) |
| PWM0 | `0x8000_1000` | 4 KiB | 6 words | 67 words (through `0x108`) |
| Timer0 | `0x8000_2000` | 8 KiB | 20 words | 8 words (through `0x1C`) |
| SPI0 | `0x8000_4000` | 4 KiB | 8 words | Confirm in S0 |
| I2C0 | `0x8000_5000` | 4 KiB | TBD | 6 words (`NWORDS` default) |
| UART | `0x8000_6000` | 4 KiB | TBD | 9 words (through `0x20`) |
| I/O Mux | `0x8000_7000` | 4 KiB | 1-2 words | 2 words |
| GPIOBOOT | `0x8000_8000` | 256 B | 8 words | 18 words, if instantiated |

CLINT also needs correcting: `memory_map.md` gives 8,192 words, but `MTIME` is at `0xBFF8`, which requires at least 12,288 words. `ahb_subordinate` would reject those registers at the documented size.

The system spec's overlapping mux and `GPIOBOOT` ranges (both at `0x8000_6000`) are superseded by `memory_map.md`, subject to D-02.

---

## 7. Clocks and Resets

| Domain | Clock | Target | Blocks |
|---|---|---|---|
| Core / AHB | `HCLK` | 100 MHz | Core, fabric, memories, DMA, UART, CLINT, PLIC |
| APB | `PCLK` | 12.5 MHz | APB fabric and completers |

- **[TOP-CLK-001]** Only `ahb2apb` and approved synchronizers may cross between HCLK and PCLK.
- **[TOP-CLK-002]** Every PCLK-domain interrupt passes through a 2-flop synchronizer before reaching the HCLK-domain PLIC.
- **[TOP-CLK-003]** Asynchronous external inputs pass through a 2-flop synchronizer in the receiving domain.
- **[TOP-RST-001]** One external active-low reset drives both domains. Assertion is asynchronous. Deassertion is synchronized separately to each domain.
- **[TOP-RST-002]** Reset leaves all pads undriven until firmware configures them, and no interrupts are pending.
- **[TOP-RST-003]** The core fetches its first instruction from the reset PC set by D-04.

---

## 8. Interrupts and Pins

### 8.1 PLIC Sources (Proposed, D-11)

Source 0 is reserved.

| Source | Device | Domain | Notes |
|---|---|---|---|
| 1-4 | GPIO0-GPIO3 | PCLK | One aggregate level per bank |
| 5 | PWM0 | PCLK | |
| 6 | Timer0 | PCLK | |
| 7 | SPI0 | PCLK | OR of the six `spi_if.irq` bits |
| 8 | I2C0 | PCLK | |
| 9 | UART | HCLK | Requires a working IRQ (K-17) |
| 10 | DMA | HCLK | |
| 11 | GPIOBOOT | PCLK | Only if instantiated |

- **[TOP-IRQ-001]** Each device interrupt reaches exactly one PLIC source, as listed above. Unused sources are tied to 0.
- **[TOP-IRQ-002]** The PLIC target output and CLINT `timer_int` and `soft_int` connect to the core once D-13 is implemented. Until then they stay observable to the testbench.

### 8.2 Pins

- **[TOP-PIN-001]** All external signals go through `aft_top_if`, with input, output, and output-enable signals kept separate. `aft_top` contains no tri-states.
- **[TOP-PIN-002]** Off-chip SRAM uses `sram_if`: 19-bit address, 16-bit data, and two sets of chip controls.
- **[TOP-PIN-003]** Peripheral pins connect as specified by D-12. Mux routing is not implemented or tested until a pin table is approved.

---

## 9. Bring-Up Stages

Every stage gate requires: lint and `make synth-check` clean or with listed waivers, all earlier SoC tests passing, and that stage's tests passing. Report results using Section 13.

| Stage | Work | Tests | Exit gate |
|---|---|---|---|
| S0 | Audit only, with no edits. Confirm Section 4, list block regressions and commands, and report anything missing from this spec. | None | User reviews the audit and closes the decisions for S1 |
| S1 | Create `integration/soc-top` from `main`. Merge `integration/soc-peripherals`, apply D-01, and record a block regression baseline. Do not merge `dualcore`, `jason`, or other stale branches. | Block regressions | All blocks compile; each pre-existing failure is listed and classified |
| S2 | Fix K-04 to K-10 and K-13 in separate commits. Generate the map. | T01, T02, plus affected block regressions | Bridge and APB subsystem elaborate in one filelist |
| S3 | Build `aft_top` with fabric, Boot ROM, RAM, off-chip SRAM controller, clock/reset, and a TB bus master replacing the core. | T03-T09 | All pass |
| S4 | Add core, adapter, and uncached path (D-06). Add firmware build and Printer model. | T10-T14 | All pass |
| S5 | Add peripherals one per commit, in this order: GPIO0, Timer0, PWM0, GPIO1-3, SPI0, I2C0, I/O Mux registers. | T15-T20 | All pass; each peripheral adds its own test |
| S6 | Add one per commit: CLINT, PLIC, UART, DMA. | T21-T25 | All pass, using polling |
| S7 | Implement D-13 from an approved core spec change. | T26-T28 | All pass |
| S8 | Run full-system stress, reset, fault-injection, CDC review, and coverage closure. | T29-T33 | Section 12 exit criteria met |

---

## 10. Requirements

- **[TOP-BUS-001]** The AHB arbiter uses fixed priority: core over DMA. An accepted transfer is never interrupted by arbitration.
- **[TOP-BUS-002]** AHB wait states propagate to the requesting manager with no loss or duplication of a transfer.
- **[TOP-BUS-003]** Byte, halfword, and word accesses use correct `HSIZE`, `HWSTRB`, `PSTRB`, and read byte lanes where the target supports them.
- **[TOP-BUS-004]** `PSLVERR` becomes an AHB error response. The bridge never hangs on an error.
- **[TOP-BUS-005]** Only single-beat transfers reach APB.
- **[TOP-CORE-001]** Accesses to a region not marked cacheable by D-06 make exactly one bus transfer, with no line fill or write-back.
- **[TOP-CORE-002]** Cacheable accesses preserve data through eviction and refill, including with off-chip SRAM wait states.
- **[TOP-CORE-003]** A bus error halts the core, as `riscv/SPEC.md` specifies, until reset. The TB can observe the halt.
- **[TOP-DMA-001]** DMA transfers succeed while the core accesses other targets, and the core retains priority.
- **[TOP-FW-001]** Firmware reaches each register only through generated addresses.
- **[TOP-SIM-001]** A Printer write with `wdata[31] = 0` prints `wdata[7:0]`. Writing `0x8000_0000` ends the run as PASS. Writing `0x8000_0000 | code`, with nonzero `code`, ends it as FAIL.
- **[TOP-SIM-002]** Each test has a timeout. Timeout, assertion failure, core halt, and any unexpected bus error all produce a nonzero exit.
- **[TOP-SIM-003]** `make regress` fails if the number of tests run differs from the number expected.

---

## 11. Verification Plan

**Environment:** `cadence/xcelium/23.03`, `verilator/5.036` lint, `riscv-gcc/13.2.0`, and SVA binds for AHB and APB protocol checks at every fabric boundary.

**Independence:** Compute expected values from this spec and block specs, not from RTL. Tests use only `aft_top` ports, bus transactions, and firmware results, except the approved observation points in TOP-IRQ-002 and TOP-CORE-003.

**Core error handling:** Because a bus error halts the core until reset (TOP-CORE-003), negative access tests each run as a separate simulation or use the TB bus master.

| Test | Stage | Description | Requirements |
|---|---|---|---|
| T01 | S2 | Generated files match the YAML and the map has no overlaps | TOP-MAP-001, TOP-MAP-002, TOP-MAP-004 |
| T02 | S2 | Full top-level filelist has no duplicate definitions | TOP-ARCH-003 |
| T03 | S3 | TB master accesses first and last implemented word of each subordinate present | TOP-BUS-002, TOP-MAP-004 |
| T04 | S3 | Each unmapped address and reserved hole returns an error; no aliasing | TOP-MAP-003 |
| T05 | S3 | Byte, halfword, and word accesses on every byte lane | TOP-BUS-003 |
| T06 | S3 | Back-to-back transfers and random wait states, with AHB SVA active | TOP-BUS-002 |
| T07 | S3 | Off-chip SRAM reads and writes against the external model | TOP-PIN-002, TOP-BUS-002 |
| T08 | S3 | Clock ratio, reset sequencing, and synchronized deassertion in each domain | TOP-RST-001 |
| T09 | S3 | Bridge access to an out-of-range APB address returns an error without hanging | TOP-BUS-004, TOP-BUS-005, TOP-MAP-005 |
| T10 | S4 | Core fetches first from the reset PC and runs a directed program | TOP-RST-003 |
| T11 | S4 | `riscv-tests` or `riscv-arch-test` RV32 base suite | TOP-SIM-002 |
| T12 | S4 | C program with stack, globals, and Printer output, plus failing-run detection | TOP-SIM-001, TOP-SIM-002 |
| T13 | S4 | Cache eviction and refill across RAM and off-chip SRAM | TOP-CORE-002 |
| T14 | S4 | Uncached accesses make exactly one transfer with correct size and strobes | TOP-CORE-001, TOP-BUS-003 |
| T15 | S5 | Firmware checks GPIO0 reset values, readback, and pin loopback | TOP-FW-001, TOP-RST-002, TOP-MAP-005 |
| T16 | S5 | Firmware runs Timer0 count and capture | TOP-CLK-003, TOP-FW-001 |
| T17 | S5 | Firmware runs PWM0, and the TB checks the waveform | TOP-FW-001, TOP-PIN-001 |
| T18 | S5 | GPIO1-3 instance isolation, including width masking | TOP-MAP-003, TOP-MAP-005 |
| T19 | S5 | Firmware transfers through SPI0 and I2C0 against device models | TOP-BUS-003, TOP-PIN-001, TOP-PIN-003 |
| T20 | S5 | I/O Mux register readback; routing only after D-12 | TOP-PIN-003 |
| T21 | S6 | CLINT `mtime` and `mtimecmp` access, including all registers near `0xBFFC` | TOP-MAP-003, TOP-IRQ-002 |
| T22 | S6 | Each PLIC source: assert, poll, claim, and complete, with distinct IDs | TOP-IRQ-001, TOP-CLK-002 |
| T23 | S6 | PCLK-domain interrupt pulse and level behavior across the synchronizer | TOP-CLK-001, TOP-CLK-002 |
| T24 | S6 | UART transmit and receive against a serial model, including its IRQ | TOP-PIN-001, TOP-IRQ-001 |
| T25 | S6 | DMA memory-to-memory transfer under core traffic; checks priority and done IRQ | TOP-BUS-001, TOP-DMA-001 |
| T26 | S7 | Timer interrupt enters a handler and returns with `mret` | TOP-IRQ-002 |
| T27 | S7 | Software interrupt enters a handler and returns correctly | TOP-IRQ-002 |
| T28 | S7 | External interrupt: handler claims from PLIC and dispatches by source | TOP-IRQ-001, TOP-IRQ-002 |
| T29 | S8 | Concurrent core, DMA, APB, and interrupt traffic with a firmware workload | TOP-BUS-001, TOP-BUS-002, TOP-DMA-001 |
| T30 | S8 | Reset during active AHB, APB, and DMA transfers; the system recovers and reruns | TOP-RST-001, TOP-RST-002 |
| T31 | S8 | Core access to an unmapped address halts as specified | TOP-CORE-003, TOP-MAP-003 |
| T32 | S8 | Regression detects each injected fault in Section 12 and a missing test | TOP-SIM-002, TOP-SIM-003 |
| T33 | S8 | Inspect the netlist and top-level RTL: structural only, no Printer or simulation-only code | TOP-ARCH-001, TOP-ARCH-002, TOP-ARCH-004 |

Requirements covered by review rather than simulation are reported in the S8 traceability table with evidence: TOP-PROC-*, and synthesis results for TOP-ARCH-002.

### 11.1 Make Targets

Run from `top_level/verification/`:

| Target | Purpose |
|---|---|
| `make lint` | Verilator lint of `aft_top` |
| `make synth-check` | Elaboration or synthesis check, with simulation-only code excluded |
| `make fw TEST=<name>` | Build one firmware test |
| `make sim TEST=<name>` | Run one test |
| `make regress` | Run every test and enforce TOP-SIM-003 |
| `make cov` | Merge and report coverage |
| `make clean` | Remove `build/` |

Build output goes in `build/`.

---

## 12. Exit Criteria

| Metric | Target |
|---|---|
| Test results | T01-T33 pass from a clean checkout, including T26-T28 unless D-13 explicitly defers them |
| Block regressions | Pass, with any waiver approved by the user |
| Top-level functional coverage | 100% of: each map region, each byte lane, each IRQ source, each manager/subordinate pair, error responses, and reset during transfers |
| Top-level connectivity | Every block port is connected or has a listed reason. Toggle of each top-level connection is covered. |
| Line, branch, and toggle | Follow the block-level targets in `NEX.md` for new top-level RTL, with listed exclusions |
| Protocol assertions | No AHB or APB SVA failures |
| CDC | Every HCLK/PCLK crossing is listed with its method and reviewed. A CDC tool run is a separate sign-off item. |

**Required fault injections for T32:** swap two PLIC sources, swap two APB bases, disconnect `HREADY`, skip a PCLK-to-HCLK IRQ synchronizer, and force a Printer FAIL. Each must make the regression fail. Run these on a throwaway copy and do not commit them.

---

## 13. Stage Report

End each stage with:

1. Commands run, each with pass/fail counts
2. Requirement traceability: requirement ID to test ID and result
3. Files changed and proposed commit message(s) (`feat(top): ...`, `test(top): ...`, `fix(<block>): ...`)
4. Failures, each classified as RTL bug, TB bug, or spec gap, with root cause and evidence
5. Waivers, skipped tests, and disabled assertions
6. Spec gaps and decisions needed
7. Human interventions during the stage, and elapsed time
8. `git status` and `git diff --stat`, as required by `NEX.md`
