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
            
            // Note: Since ahb_if doesn't have an external HREADY_in, 
            // we assume that when we assert HREADYOUT, the current phase completes.
            if (state == IDLE || ahb.HREADYOUT) begin
                if (valid_addr_phase) begin
                    saved_addr <= ahb.HADDR - BASE_ADDR; // Offset address
                    saved_write <= ahb.HWRITE;
                end
            end
        end
    end

    always_comb begin
        next_state = state;
        
        // Generic defaults
        generic_if.wen = 1'b0;
        generic_if.ren = 1'b0;
        generic_if.addr = saved_addr;
        generic_if.wdata = ahb.HWDATA;
        generic_if.strobe = ahb.HWSTRB;
        generic_if.is_burst = 1'b0;
        generic_if.burst_type = 2'b0;
        generic_if.burst_length = '0;
        generic_if.secure_transfer = 1'b0;

        // AHB defaults
        ahb.HREADYOUT = 1'b1;
        ahb.HRESP = 1'b0; // OKAY
        ahb.HRDATA = generic_if.rdata;

        case (state)
            IDLE: begin
                if (valid_addr_phase) begin
                    if (!addr_in_range) begin
                        next_state = ERROR_PHASE1;
                    end else begin
                        next_state = DATA_PHASE;
                    end
                end
            end

            DATA_PHASE: begin
                generic_if.wen = saved_write;
                generic_if.ren = !saved_write;
                generic_if.addr = saved_addr;
                generic_if.wdata = ahb.HWDATA;
                generic_if.strobe = ahb.HWSTRB;

                if (!generic_if.request_stall) begin
                    ahb.HREADYOUT = 1'b1;
                    ahb.HRDATA = generic_if.rdata;
                    
                    // Check if a new transfer is pending
                    if (valid_addr_phase) begin
                        if (!addr_in_range) begin
                            next_state = ERROR_PHASE1;
                        end else begin
                            next_state = DATA_PHASE;
                        end
                    end else begin
                        next_state = IDLE;
                    end
                end else begin
                    ahb.HREADYOUT = 1'b0;
                end
            end

            ERROR_PHASE1: begin
                ahb.HREADYOUT = 1'b0;
                ahb.HRESP = 1'b1; // ERROR
                next_state = ERROR_PHASE2;
            end

            ERROR_PHASE2: begin
                ahb.HREADYOUT = 1'b1;
                ahb.HRESP = 1'b1; // ERROR
                
                if (valid_addr_phase) begin
                    if (!addr_in_range) begin
                        next_state = ERROR_PHASE1;
                    end else begin
                        next_state = DATA_PHASE;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule
