/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module registers #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COUNT_W = 8
)(
    input  logic clk,
    input  logic rst_n,
    
    // Register Bus Interface (APB)
    input  logic [ADDR_W-1:0] paddr,
    input  logic              psel,
    input  logic              penable,
    input  logic              pwrite,
    input  logic [DATA_W-1:0] pwdata,
    output logic [DATA_W-1:0] prdata,
    output logic              pready,
    output logic              pslverr,
    
    // Internal hardware interface
    output logic [ADDR_W-1:0] sar,
    output logic [ADDR_W-1:0] dar,
    output logic [COUNT_W-1:0] tsr,
    
    output logic [31:0]       cr,
    
    input  logic              hw_finished,
    input  logic              hw_error,
    output logic              clear_status,
    output logic              irq,
    output logic              hw_clear_en
);

    logic [ADDR_W-1:0] reg_sar;
    logic [ADDR_W-1:0] reg_dar;
    logic [31:0]       reg_tsr;
    logic [31:0]       reg_cr;
    logic [31:0]       reg_sr;
    
    assign sar = reg_sar;
    assign dar = reg_dar;
    assign tsr = reg_tsr[COUNT_W-1:0];
    assign cr  = reg_cr;
    
    assign irq = reg_cr[14] & (reg_sr[0] | reg_sr[1]);
    
    assign pready  = 1'b1;
    
    logic rd_en, wr_en;
    assign rd_en = psel && !pwrite && !penable; // Read starts immediately in APB but data valid next cycle
    assign wr_en = psel && pwrite && penable;
    
    always_comb begin
        pslverr = 1'b0;
        prdata  = '0;
        if (rd_en || (psel && !pwrite)) begin
            case (paddr[7:0])
                8'h04: prdata = reg_sar;
                8'h08: prdata = reg_dar;
                8'h0C: prdata = reg_tsr;
                8'h10: prdata = reg_cr;
                8'h14: prdata = reg_sr;
                default: pslverr = 1'b1;
            endcase
        end else if (wr_en) begin
            case (paddr[7:0])
                8'h04, 8'h08, 8'h0C, 8'h10, 8'h14: pslverr = 1'b0;
                default: pslverr = 1'b1;
            endcase
        end
    end
    
    // Read-to-clear logic for SR
    assign clear_status = (rd_en && (paddr[7:0] == 8'h14));
    assign hw_clear_en  = hw_finished || hw_error;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_sar <= '0;
            reg_dar <= '0;
            reg_tsr <= '0;
            reg_cr  <= '0;
            reg_sr  <= '0;
        end else begin
            // Hardware updates to SR
            if (hw_finished) reg_sr[0] <= 1'b1;
            if (hw_error)    reg_sr[1] <= 1'b1;
            
            // Auto-clear EN on finish/error
            if (hw_clear_en) reg_cr[0] <= 1'b0;
            
            // Clear SR on read
            if (clear_status) reg_sr <= '0;
            
            // Software Writes
            if (wr_en) begin
                case (paddr[7:0])
                    8'h04: reg_sar <= pwdata;
                    8'h08: reg_dar <= pwdata;
                    8'h0C: reg_tsr <= pwdata;
                    8'h10: reg_cr  <= pwdata;
                    default: ; // SR is read-only
                endcase
            end
        end
    end
endmodule
