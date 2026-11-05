`include "apb_if.sv"

module digital_io_mux_apb #(
    parameter int NUM_PINS = 32,
    parameter int NUM_BITS = 2,
    parameter int NUM_REGS = 2,
    parameter logic [31:0] BASE_ADDR = 32'h8000_6000
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

    assign apb.PREADY = 1'b1;
    
    always_comb begin
        is_sel0_access = (apb.PADDR == BASE_ADDR);
        is_sel1_access = (apb.PADDR == BASE_ADDR + 32'h4) && (NUM_REGS == 2);
        is_valid_access = is_sel0_access || is_sel1_access;
        
        // Error on active cycle for invalid addresses
        access_err = apb.PSEL && apb.PENABLE && !is_valid_access;
        
        apb.PSLVERR = access_err;
        apb.PRDATA  = '0;
        
        reg_sel_next = reg_sel;
        
        if (apb.PSEL && apb.PENABLE) begin
            if (is_sel0_access) begin
                if (!apb.PWRITE) begin
                    apb.PRDATA = reg_sel[31:0];
                end else begin
                    if (apb.PSTRB[0]) reg_sel_next[7:0]   = apb.PWDATA[7:0];
                    if (apb.PSTRB[1]) reg_sel_next[15:8]  = apb.PWDATA[15:8];
                    if (apb.PSTRB[2]) reg_sel_next[23:16] = apb.PWDATA[23:16];
                    if (apb.PSTRB[3]) reg_sel_next[31:24] = apb.PWDATA[31:24];
                end
            end else if (is_sel1_access) begin
                if (!apb.PWRITE) begin
                    apb.PRDATA = reg_sel[(NUM_REGS-1)*32 +: 32];
                end else begin
                    if (apb.PSTRB[0]) reg_sel_next[(NUM_REGS-1)*32 + 0  +: 8] = apb.PWDATA[7:0];
                    if (apb.PSTRB[1]) reg_sel_next[(NUM_REGS-1)*32 + 8  +: 8] = apb.PWDATA[15:8];
                    if (apb.PSTRB[2]) reg_sel_next[(NUM_REGS-1)*32 + 16 +: 8] = apb.PWDATA[23:16];
                    if (apb.PSTRB[3]) reg_sel_next[(NUM_REGS-1)*32 + 24 +: 8] = apb.PWDATA[31:24];
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