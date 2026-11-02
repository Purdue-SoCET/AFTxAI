# PWM0 Bus Integration Report

## 1. Commits and Source Information
- **Integration Base Commit (origin/main):** `6a689dbb8a66aa12cb319c6662444acb3c6a811a`
- **Source PWM Commit (origin/feat/pwm-peripheral):** `4d49268248d36b68a33ff7e235602ec5d86e1363`
- **Actual Git commit SHA:** `478547fff2b4bbc04339bf98059713d84c761a0d`
- **Clean-tree status:** Yes (after commit)

## 2. PWM Wrapper and Interface Implementation
A lightweight wrapper `pwm_apb_wrapper.sv` maps the shared `apb_if.completer` to the core's scalar APB4 ports. It ensures requests are bounded within a 4-KiB window, explicitly validating the base address and asserting `PSLVERR` for aliases, thereby isolating the core from higher-address out-of-range requests.

## 3. Absolute-to-Local Address Translation
The AHB-to-APB bridge translates AHB addresses by subtracting `BASE_ADDR` (`0x8000_0000`).
The wrapper translates Bridge-Relative APB addresses into a 12-bit local offset by matching `apb.PADDR & ~32'hFFF` against a configurable `BASE_ADDR` parameter (set to `0x0000_1000`), passing `PADDR[11:0]` directly to the core.
**Translation Path:**
`0x8000_1108` (AHB) -> Bridge (`-0x8000_0000`) -> `0x0000_1108` (APB interconnect) -> Wrapper (truncates) -> `0x108` (PWM local offset).

## 4. Provisional PWM Address Window
- **Provisional Window:** 4-KiB window starting at `0x8000_1000`.
- This accommodates the required span `0x000 - 0x10B` implemented by the core's local registers.
- **System Change Required:** The memory map in `docs/memory_map.md` presently lists `0x8000_1000` with an "Address Range" of 6 words. **This is inadequate and obsolete.** The ABI spans offsets up to `0x108`.

## 5. APB Interconnect Configuration & Decoder Limitations
- The current `apb_interconnect.sv` enforces a uniform `COMPLETER_ADDR_BITS` system-wide mask.
- A 256-byte granularity (`COMPLETER_ADDR_BITS=8`)—required to distinguish `GPIO0` through `GPIO3`—masks out the upper bounds of the PWM address range, causing legitimate PWM global accesses (e.g., `0x1108`) to fall out of the decoder's target match and falsely return `PSLVERR`.
- **Proposed Solution:** Modify `apb_interconnect.sv` to accept heterogeneous `APB_MASK` arrays:
  `parameter logic [31:0] APB_MASK [NCOMPLETERS] = '{default: ~((1<<COMPLETER_ADDR_BITS)-1)}`
  and update the check: `((requester.PADDR & APB_MASK[i]) == (APB_MAP[i] & APB_MASK[i]))`.
- PWM integration testing temporarily bypassed this by using `COMPLETER_ADDR_BITS=12` in the test harness. Mixed GPIO/PWM integration is currently blocked on this shared bus change.

## 6. AHB-to-APB Bridge Configuration
- Standard 16-KiB window tested at base `0x8000_0000`.
- Discovered and addressed a stringent PWM requirement (`PWM-APB-004`) returning `PSLVERR` if `PSTRB` is non-zero during reads. AHB integration tests were augmented to mask `HWSTRB` during read phases.

## 7. Clock and Reset Relationships
- Tests configured with nominal `HCLK` (100 MHz) and `PCLK` (12.5 MHz).
- Reset sequence tested: asynchronous assertion, synchronous deassertion per IP block.
- Tested and confirmed stable AHB stalling during asynchronous wait cycles.

## 8. Four-Channel Output Integration
- The 4-channel logical vectors (`pwm_out_o`, `pwm_oe_o`) successfully drive outputs configured via AHB programming.
- Disabled and enabled channels maintain isolated behavior under concurrent and disconnected bus traffic.

## 9. I/O Mux Logical Interface
- PWM logic vectors are fully integrated at the logical level.
- The I/O mux block (`feat/digital-io-mux`) implementation is assumed as a black box and physically integrating pins is pending global approval. PWM respects the logical `output`/`oe` protocol without physically commanding IO pads.

## 10. PLIC Interrupt Routing
- **Test-Only Assignment:** IRQ Source `15`.
- Implemented and verified a 2-flop synchronizer since PLIC and PWM exist in separate clock domains. 
- *Persistence justification:* The PWM `irq_pending` signal uses sticky registers that remain asserted until cleared by an explicit W1C access. It therefore intrinsically spans the cross-domain gap without loss.

## 11. Testing and Tools
- **Tool Version:** Cadence Xcelium 25.09-s001 (`xrun(64)`)
- **Commands:** 
  - `module load cadence/xcelium`
  - `./run_apb_test_xrun.sh`
  - `./run_ahb_test_xrun.sh`
  - `./run_waveform_test_xrun.sh`
  - `./run_plic_test_xrun.sh`

## 12. Pass/Fail Results
- **APB Integration:** 17 checks (17/17 PASS)
- **AHB Integration:** 10 checks (10/10 PASS)
- **Waveform & T22:** 10 checks (10/10 PASS)
- **PLIC Routing:** 6 checks (6/6 PASS)
- **Total:** 43 executed checks, all passed.

## 13. Coverage Measurements and Limitations
- Integration coverage heavily focuses on behavioral correctness (transaction mapping, PSTRB masking, CDC integrity).
- UVM formal coverage is deferred to the standalone testbench regression.

## 14. Remaining Standalone Verification Debt
- Standalone UVM limitations (such as T04 checking only PERIOD for PSTRB masks) remain. 
- The UVM predictor lacks prescaler and ARM logic perfection.
- `T22` (ARM while disabled) was executed as a targeted integration check, proving correctness independent of the standalone missing test.

## 15. Global Integration Decisions Requiring Owner Approval
1. **Memory Map Window:** Expanding PWM's window from 6 words to 4-KiB (or equivalent necessary size) in `docs/memory_map.md`.
2. **APB Decoder Granularity:** Implementing the proposed `APB_MASK` system in the shared `apb_interconnect.sv` to support mixed device scopes.
3. **Physical I/O Mux:** Final approval for assigning PWM logical lines to pad candidates in `digital_io_mux.sv`.
4. **PLIC Vector:** Finalizing the production `irq_source` ID.

## 16. Requirement-to-Test Matrix
| Requirement | Status | Notes |
|-------------|--------|-------|
| 12-bit Address Decode / APB Wrapper | PASS | Aliasing safely rejected |
| AHB-to-APB absolute addressing | PASS | Registers 0x100+ accessible |
| APB Interconnect Decoder Isolation | BLOCKED | Requires shared bus fix (see Sec 5) |
| Read `PSTRB` behavior | PASS | PWM-APB-004 validated |
| HREADY Stalling / Bridge FSM | PASS | Multi-cycle response verified |
| T22: ARM while disabled | PASS | Pending cleared, inactive output |
| Buffered Update Atomicity | PASS | Boundary edge synchronization tested |
| PLIC Sync and Interrupt Claims | PASS | CDC latency accommodated |
| I/O Mux Physical Pad Assignment | BLOCKED | Dependent on global assignment |
