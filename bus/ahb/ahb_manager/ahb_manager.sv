`include "ahb_pkg.sv"

module ahb_manager #(
    parameter int HDATA_WIDTH = 32
) (
    input logic HCLK,
    input logic HRESETn,
    bus_protocol_if.peripheral_vital generic_if,
    ahb_if.manager ahb
);

    import ahb_pkg::*;

    typedef enum logic [1:0] {
        IDLE,
        ADDR_PHASE,
        DATA_PHASE
    } state_t;

    state_t state, next_state;

    // Latch generic bus signals since they might drop?
    // Usually a generic bus holds signals if stalled, but let's just use them directly if possible.
    // Actually, we must register wdata for the data phase.
    logic [31:0] saved_addr;
    logic [HDATA_WIDTH-1:0] saved_wdata;
    logic [(HDATA_WIDTH/8)-1:0] saved_strobe;
    logic saved_wen;
    logic saved_ren;

    assign ahb.HCLK = HCLK;
    assign ahb.HRESETn = HRESETn;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
            saved_addr <= '0;
            saved_wdata <= '0;
            saved_strobe <= '0;
            saved_wen <= 1'b0;
            saved_ren <= 1'b0;
        end else begin
            state <= next_state;
            
            if (state == IDLE && (generic_if.wen || generic_if.ren)) begin
                saved_addr <= generic_if.addr;
                saved_wdata <= generic_if.wdata;
                saved_strobe <= generic_if.strobe;
                saved_wen <= generic_if.wen;
                saved_ren <= generic_if.ren;
            end
        end
    end

    always_comb begin
        next_state = state;
        
        // AHB outputs default
        ahb.HTRANS = ahb_pkg::IDLE;
        ahb.HADDR = '0;
        ahb.HWRITE = 1'b0;
        ahb.HSIZE = ahb_pkg::WORD; // Default size, could be based on strobe but let's assume WORD
        ahb.HBURST = ahb_pkg::SINGLE;
        ahb.HMASTLOCK = 1'b0;
        ahb.HWDATA = '0;
        ahb.HWSTRB = '0;
        ahb.HSEL = 1'b0;

        // Generic outputs default
        generic_if.request_stall = 1'b0;
        generic_if.rdata = '0;
        generic_if.error = 1'b0;

        case (state)
            IDLE: begin
                if (generic_if.wen || generic_if.ren) begin
                    // Initiate AHB address phase
                    ahb.HTRANS = ahb_pkg::NONSEQ;
                    ahb.HADDR = generic_if.addr;
                    ahb.HWRITE = generic_if.wen;
                    generic_if.request_stall = 1'b1;
                    
                    if (ahb.HREADY) begin
                        next_state = DATA_PHASE;
                    end else begin
                        next_state = ADDR_PHASE;
                    end
                end
            end
            
            ADDR_PHASE: begin
                generic_if.request_stall = 1'b1;
                ahb.HTRANS = ahb_pkg::NONSEQ;
                ahb.HADDR = saved_addr;
                ahb.HWRITE = saved_wen;
                
                if (ahb.HREADY) begin
                    next_state = DATA_PHASE;
                end
            end
            
            DATA_PHASE: begin
                generic_if.request_stall = 1'b1;
                ahb.HWDATA = saved_wdata;
                ahb.HWSTRB = saved_strobe;
                
                if (ahb.HREADY) begin
                    generic_if.rdata = ahb.HRDATA;
                    generic_if.error = ahb.HRESP;
                    generic_if.request_stall = 1'b0;
                    
                    // Back-to-back? Let's just go to IDLE to keep it simple.
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule
