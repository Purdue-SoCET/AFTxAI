`timescale 1ns/1ps

module sky130_sram_banked_16k (
    input  logic        clk,
    input  logic        rst_n,
    bus_protocol_if.peripheral_vital bus
);

    // 16 KiB = 4096 words x 32 bits
    // 8 macros of sky130_sram_1rw1r_64x256_8 (256 words x 64 bits = 2048 bytes each)
    // 1 macro = 256 rows x 64 bits = 512 words x 32 bits.
    // 8 macros = 4096 words x 32 bits = 16384 bytes = 16 KiB.
    
    localparam int TOTAL_BYTES = 16384;
    localparam int NUM_BANKS   = 8;

    logic valid_addr;
    assign valid_addr = (bus.addr < TOTAL_BYTES);

    typedef enum logic [1:0] {
        IDLE,
        READ_WAIT,
        READ_DATA
    } state_t;

    state_t state_q, state_d;

    // Address breakdown:
    // bus.addr[1:0]   : byte within 32-bit word
    // bus.addr[2]     : word in 64-bit double-word (0 = low 32 bits, 1 = high 32 bits)
    // bus.addr[10:3]  : 8-bit row address for the macro (256 rows)
    // bus.addr[13:11] : 3-bit macro/bank select (8 macros)
    
    logic [2:0]  bank_sel;
    logic [7:0]  macro_addr;
    logic        word_hi;

    assign bank_sel   = bus.addr[13:11];
    assign macro_addr = bus.addr[10:3];
    assign word_hi    = bus.addr[2];

    logic [2:0]  read_bank_q;
    logic [7:0]  read_macro_addr_q;
    logic        read_hi_q;

    always_comb begin
        state_d = state_q;
        case (state_q)
            IDLE: begin
                if (bus.ren && valid_addr) begin
                    state_d = READ_WAIT;
                end
            end
            READ_WAIT: begin
                state_d = READ_DATA;
            end
            READ_DATA: begin
                // Transfer completes on this cycle (request_stall = 0)
                state_d = IDLE;
            end
            default: state_d = IDLE;
        endcase
    end

    // Macro interface signals
    logic [7:0]  csb0;
    logic [7:0]  web0;
    logic [7:0]  wmask0 [8];
    logic [63:0] din0   [8];
    logic [63:0] dout0  [8];

    // Hold captured data across the completion cycle
    logic [63:0] rdata_captured_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q           <= IDLE;
            read_bank_q       <= '0;
            read_macro_addr_q <= '0;
            read_hi_q         <= 1'b0;
            rdata_captured_q  <= 64'b0;
        end else begin
            state_q <= state_d;
            if (state_q == IDLE && bus.ren && valid_addr) begin
                read_bank_q       <= bank_sel;
                read_macro_addr_q <= macro_addr;
                read_hi_q         <= word_hi;
            end

            // Capture stable macro output at posedge clk when entering READ_DATA
            // At this rising edge, dout0 has been stable since the preceding falling edge.
            // In Verilator / SystemVerilog semantics, evaluating dout0 on posedge clk
            // samples the old value before the macro's posedge clk block clears dout0 to 'x.
            if (state_q == READ_WAIT) begin
                rdata_captured_q <= dout0[read_bank_q];
            end
        end
    end

    // Stall master while read is in progress (Cycle 0 setup and Cycle 1 macro read wait)
    // Deasserts stall during READ_DATA (Cycle 2) so master accepts valid data
    assign bus.request_stall = (bus.ren && (state_q == IDLE)) || (state_q == READ_WAIT);

    // Address and control to macro:
    // Drive macro during IDLE when ren starts, and maintain csb0/web0 through READ_WAIT
    logic [2:0]  active_bank;
    logic [7:0]  active_macro_addr;
    logic        active_word_hi;

    assign active_bank       = (state_q == IDLE) ? bank_sel   : read_bank_q;
    assign active_macro_addr = (state_q == IDLE) ? macro_addr : read_macro_addr_q;
    assign active_word_hi    = (state_q == IDLE) ? word_hi    : read_hi_q;

    // Read port 1 is unused (tied off)
    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b++) begin : gen_sram_banks
            always_comb begin
                csb0[b] = 1'b1;
                web0[b] = 1'b1;
                din0[b] = 64'b0;
                wmask0[b] = 8'b0;

                if (valid_addr && (bank_sel == b[2:0])) begin
                    if (bus.wen) begin
                        // Single-cycle synchronous write
                        csb0[b] = 1'b0;
                        web0[b] = 1'b0;
                        if (!word_hi) begin
                            din0[b][31:0]   = bus.wdata;
                            wmask0[b][3:0]  = bus.strobe;
                        end else begin
                            din0[b][63:32]  = bus.wdata;
                            wmask0[b][7:4]  = bus.strobe;
                        end
                    end else if (bus.ren && (state_q == IDLE)) begin
                        // Setup read address and enable to macro in cycle 0
                        csb0[b] = 1'b0;
                        web0[b] = 1'b1;
                    end
                end

                // In READ_DATA, ensure macro csb0 is inactive so it does not trigger a false read on the next cycle
                if (state_q == READ_WAIT && (read_bank_q == b[2:0])) begin
                    // Read active in macro during this cycle
                    csb0[b] = 1'b0;
                    web0[b] = 1'b1;
                end
            end

            sky130_sram_1rw1r_64x256_8 u_sram (
                .clk0   (clk),
                .csb0   (csb0[b]),
                .web0   (web0[b]),
                .wmask0 (wmask0[b]),
                .addr0  (active_macro_addr),
                .din0   (din0[b]),
                .dout0  (dout0[b]),
                // Port 1 (Read-only) tied off
                .clk1   (clk),
                .csb1   (1'b1),
                .addr1  ('0),
                .dout1  ()
            );
        end
    endgenerate

    // Read data multiplexer
    always_comb begin
        bus.rdata = '0;
        bus.error = 1'b0;
        if (!valid_addr && (bus.ren || bus.wen)) begin
            bus.error = 1'b1;
        end else if (state_q == READ_DATA) begin
            if (!read_hi_q) begin
                bus.rdata = rdata_captured_q[31:0];
            end else begin
                bus.rdata = rdata_captured_q[63:32];
            end
        end
    end

endmodule
