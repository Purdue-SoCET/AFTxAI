# Timer0 Integration Report

## 1. Architecture and Purpose
Timer0 is a 32-bit APB peripheral providing timekeeping, prescaled counting, interrupts (match and overflow), and asynchronous external event capture.

## 2. Address Map
- **Absolute Base Address:** `0x8000_2000`
- **Allocated Space:** 8 KB (`0x8000_2000` to `0x8000_3FFF`)
- **Note on Discrepancy:** The system memory map (`docs/memory_map.md`) allocates 20 words (80 bytes) for Timer0. However, the standalone APB adapter (`timer_apb_wrapper.sv`) checks a 13-bit offset (`offset[12:0]`) and rejects aliases across an 8 KB region by throwing an APB `PSLVERR`. Moreover, the standalone timer contract exposes 8 registers (32 bytes) starting at offset 0x00. The global system memory map needs updating to reflect the 8 registers (32 bytes) actual usage rather than 20 words, while maintaining the 8 KB alias rejection.

## 3. Decoder Configuration
The Timer sits behind the `apb_interconnect`, connected via an `ahb2apb` bridge from the main AHB matrix.
- `ahb2apb` base: `0x8000_0000`
- Timer APB Wrapper base parameter: `0x8000_2000`.
- The interconnect passes physical addresses transparently. The wrapper calculates the local offset `apb.PADDR - BASE_ADDR`.
- **Alias Rejection:** Accesses to `0x8000_2000 + offset` where `offset >= 8 KB` result in `PSLVERR`.

## 4. Interrupt Routing
- Timer `irq_o` is routed to PLIC source ID 6 in the testbench.
- The wrapper and PLIC integration testbench confirms that Timer interrupts successfully hit the PLIC, evaluate priority against thresholds, and can be claimed and completed by a CPU target.

## 5. Input Capture
- The asynchronous `capture_i` line uses a robust 2-flop synchronization (`sync_2ff`) crossing into `pclk`.
- **Note:** The Timer uses a shared `sync_2ff` module exactly once in the combined compile.
- This has been verified to reliably detect rising, falling, and both-edge captures, setting `IRQ_PENDING[2]`.
- I/O Mux connection: The `capture_i` logical signal is intended to be driven by the digital I/O mux (`origin/feat/digital-io-mux`).

## 6. Test Results
- `timer_uvm_pkg`: Solved the PSTRB partial-write coverage hole in the shadow model. Regression passes 100%.
- `timer_apb_integration_tb`: Passes (verifies error behavior on aliases and misaligned addresses).
- `timer_ahb_integration_tb`: Passes (verifies AHB bridge translations and error propagation up to the AHB master).
- `timer_plic_integration_tb`: Passes (verifies end-to-end interrupt lifecycle).
- `timer_capture_integration_tb`: Passes (verifies 2-flop synchronizer, modes, overruns, and the architectural constraint that mode/edge configurations cannot be modified while the timer is running `EN=1`).

## 7. Outstanding Decisions
- **System Clock Alignment:** Confirm if `pclk` is asynchronous to the `hclk`. The current capture synchronizer uses `pclk` to sample `capture_i`, but if `pclk` is heavily divided, capture precision is reduced.
- **I/O Mux Mapping:** The exact physical pad mapping for `capture_i` remains to be finalized in the I/O mux specification.