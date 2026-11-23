`include "ahb_pkg.sv"

module ahb_subordinate #(
    parameter logic [31:0] BASE_ADDR = 32'h0,
    parameter int NUM_WORDS = 1024,
    parameter int HDATA_WIDTH = 32
) (
    input logic HCLK,
    input logic HRESETn,
    ahb_if.subordinate ahb,
    bus_protocol_if.protocol generic_if
);

    import ahb_pkg::*;

    typedef enum logic [1:0] {
        IDLE,
        DATA_PHASE,
        ERROR_PHASE1,
        ERROR_PHASE2
    } state_t;

    state_t state, next_state;

    logic valid_addr_phase;
    assign valid_addr_phase = ahb.HSEL && (ahb.HTRANS == NONSEQ || ahb.HTRANS == SEQ);

    logic addr_in_range;
    assign addr_in_range = (ahb.HADDR >= BASE_ADDR) && (ahb.HADDR < (BASE_ADDR + NUM_WORDS * 4));

    // Latch address phase signals
    logic [31:0] saved_addr;
    logic saved_write;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_write <= 1'b0;
        end else begin
            state <= next_state;
            
            // Update address phase only when previous data phase completes
            if (ahb.HREADY) begin
                if (valid_addr_phase) begin
                    saved_addr <= ahb.HADDR - BASE_ADDR; // Offset address
                    saved_write <= ahb.HWRITE;
                end
            end
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ahb.HREADY && valid_addr_phase) begin
                    if (!addr_in_range) begin
                        next_state = ERROR_PHASE1;
                    end else begin
                        next_state = DATA_PHASE;
                    end
                end
            end

            DATA_PHASE: begin
                if (!generic_if.request_stall) begin
                    // Check if a new transfer is pending
                    if (ahb.HREADY && valid_addr_phase) begin
                        if (!addr_in_range) begin
                            next_state = ERROR_PHASE1;
                        end else begin
                            next_state = DATA_PHASE;
                        end
                    end else begin
                        next_state = IDLE;
                    end
                end
            end

            ERROR_PHASE1: begin
                next_state = ERROR_PHASE2;
            end

            ERROR_PHASE2: begin
                if (ahb.HREADY && valid_addr_phase) begin
                    if (!addr_in_range) begin
                        next_state = ERROR_PHASE1;
                    end else begin
                        next_state = DATA_PHASE;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Generic outputs logic
    always_comb begin
        generic_if.wen = 1'b0;
        generic_if.ren = 1'b0;
        generic_if.addr = saved_addr;
        generic_if.wdata = ahb.HWDATA;
        generic_if.strobe = ahb.HWSTRB;
        generic_if.is_burst = 1'b0;
        generic_if.burst_type = 2'b0;
        generic_if.burst_length = '0;
        generic_if.secure_transfer = 1'b0;

        if (state == DATA_PHASE) begin
            generic_if.wen = saved_write;
            generic_if.ren = !saved_write;
        end
    end

    // AHB outputs logic
    always_comb begin
        ahb.HREADYOUT = 1'b1;
        ahb.HRESP = 1'b0; // OKAY
        ahb.HRDATA = generic_if.rdata;

        case (state)
            DATA_PHASE: begin
                if (generic_if.request_stall) begin
                    ahb.HREADYOUT = 1'b0;
                end
            end

            ERROR_PHASE1: begin
                ahb.HREADYOUT = 1'b1;
                ahb.HRESP = 1'b0; // Suppress error
            end

            ERROR_PHASE2: begin
                ahb.HREADYOUT = 1'b1;
                ahb.HRESP = 1'b0; // Suppress error
            end
            
            default: begin
            end
        endcase
    end

    always_ff @(posedge HCLK) begin
        if (state == DATA_PHASE && !generic_if.request_stall) begin
            if (saved_write)
                $display("[%0t] MEM WRITE base=%h addr=%h data=%h strb=%h", $time, BASE_ADDR, saved_addr, ahb.HWDATA, ahb.HWSTRB);
            else if (BASE_ADDR == 32'h0000_8400)
                $display("[%0t] RAM READ addr=%h data=%h", $time, saved_addr, generic_if.rdata);
        end
    end
endmodule
