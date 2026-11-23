/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module memArbiter #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    memArb_if.arbiter arb,
    ahb_if.manager    ahb
);

    typedef enum logic {
        GRANT_READ,
        GRANT_WRITE
    } grant_t;
    
    grant_t grant;
    grant_t data_phase_grant;
    logic data_phase_active;
    
    always_ff @(posedge arb.clk or negedge arb.rst_n) begin
        if (!arb.rst_n) begin
            grant <= GRANT_READ;
            data_phase_active <= 1'b0;
        end else begin
            // Round-robin arbitration
            if (arb.r_req && !arb.w_req) grant <= GRANT_READ;
            else if (!arb.r_req && arb.w_req) grant <= GRANT_WRITE;
            else if (arb.r_req && arb.w_req) begin
                if (ahb.HREADY) grant <= (grant == GRANT_READ) ? GRANT_WRITE : GRANT_READ;
            end
            
            if (ahb.HREADY) begin
                data_phase_active <= (grant == GRANT_READ && arb.r_req) || (grant == GRANT_WRITE && arb.w_req);
                data_phase_grant <= grant;
            end
        end
    end
    
    assign arb.r_gnt = (grant == GRANT_READ) && arb.r_req && ahb.HREADY;
    assign arb.w_gnt = (grant == GRANT_WRITE) && arb.w_req && ahb.HREADY;
    
    assign arb.r_ready = data_phase_active && (data_phase_grant == GRANT_READ) && ahb.HREADY;
    assign arb.w_ready = data_phase_active && (data_phase_grant == GRANT_WRITE) && ahb.HREADY;
    
    assign arb.r_err = data_phase_active && (data_phase_grant == GRANT_READ) && ahb.HRESP;
    assign arb.w_err = data_phase_active && (data_phase_grant == GRANT_WRITE) && ahb.HRESP;
    
    assign arb.r_rdata = ahb.HRDATA;
    
    function logic [3:0] get_strb(input logic [1:0] addr, input logic [2:0] size);
        case (size)
            3'b000: return 4'b0001 << addr;
            3'b001: return 4'b0011 << {addr[1], 1'b0};
            default: return 4'b1111;
        endcase
    endfunction
    
    always_comb begin
        ahb.HTRANS = 2'b00; // IDLE
        ahb.HWRITE = 1'b0;
        ahb.HADDR  = '0;
        ahb.HSIZE  = 3'b010; // Default 32-bit
        ahb.HBURST = 3'b000; // SINGLE
        ahb.HMASTLOCK = 1'b0;
        ahb.HWDATA = arb.w_data;
        ahb.HWSTRB = get_strb(arb.w_addr[1:0], arb.w_size);
        ahb.HSEL   = 1'b0;
        
        if (grant == GRANT_READ && arb.r_req) begin
            ahb.HTRANS = 2'b10; // NONSEQ
            ahb.HWRITE = 1'b0;
            ahb.HADDR  = arb.r_addr;
            ahb.HSIZE  = arb.r_size;
            ahb.HSEL   = 1'b1;
        end else if (grant == GRANT_WRITE && arb.w_req) begin
            ahb.HTRANS = 2'b10; // NONSEQ
            ahb.HWRITE = 1'b1;
            ahb.HADDR  = arb.w_addr;
            ahb.HSIZE  = arb.w_size;
            ahb.HSEL   = 1'b1;
        end
    end
endmodule
