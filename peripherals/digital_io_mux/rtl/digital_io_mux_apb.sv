`include "apb_if.sv"

module digital_io_mux_apb #(
    parameter int NUM_PINS = 32,
    parameter int NUM_BITS = 2,
    parameter int NUM_REGS = 2
) (
    input logic pclk,
    input logic presetn,
    apb_if.completer apb,
    output logic [(NUM_REGS*32)-1:0] fsel_out
);
    localparam int TOTAL_BITS = NUM_PINS * NUM_BITS;
    
    logic [(NUM_REGS*32)-1:0] reg_sel, reg_sel_next;
    logic                     is_valid_access;
    logic                     is_sel0_access;
    logic                     is_sel1_access;
    logic                     access_err;

    assign apb.pready = 1'b1;
    
    always_comb begin
        is_sel0_access = (apb.paddr == 32'h5000);
        is_sel1_access = (apb.paddr == 32'h5004) && (NUM_REGS == 2);
        is_valid_access = is_sel0_access || is_sel1_access;
        
        // Error on active cycle for invalid addresses
        access_err = apb.psel && apb.penable && !is_valid_access;
        
        apb.pslverr = access_err;
        apb.prdata  = '0;
        
        reg_sel_next = reg_sel;
        
        if (apb.psel && apb.penable) begin
            if (is_sel0_access) begin
                if (!apb.pwrite) begin
                    apb.prdata = reg_sel[31:0];
                end else begin
                    if (apb.pstrb[0]) reg_sel_next[7:0]   = apb.pwdata[7:0];
                    if (apb.pstrb[1]) reg_sel_next[15:8]  = apb.pwdata[15:8];
                    if (apb.pstrb[2]) reg_sel_next[23:16] = apb.pwdata[23:16];
                    if (apb.pstrb[3]) reg_sel_next[31:24] = apb.pwdata[31:24];
                end
            end else if (is_sel1_access) begin
                if (!apb.pwrite) begin
                    apb.prdata = reg_sel[(NUM_REGS-1)*32 +: 32];
                end else begin
                    if (apb.pstrb[0]) reg_sel_next[(NUM_REGS-1)*32 + 0  +: 8] = apb.pwdata[7:0];
                    if (apb.pstrb[1]) reg_sel_next[(NUM_REGS-1)*32 + 8  +: 8] = apb.pwdata[15:8];
                    if (apb.pstrb[2]) reg_sel_next[(NUM_REGS-1)*32 + 16 +: 8] = apb.pwdata[23:16];
                    if (apb.pstrb[3]) reg_sel_next[(NUM_REGS-1)*32 + 24 +: 8] = apb.pwdata[31:24];
                end
            end
        end
        
        // Mask out unused bits
        for (int i = TOTAL_BITS; i < (NUM_REGS*32); i++) begin
            reg_sel_next[i] = 1'b0;
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_sel <= '0;
        end else begin
            reg_sel <= reg_sel_next;
        end
    end

    assign fsel_out = reg_sel;
endmodule