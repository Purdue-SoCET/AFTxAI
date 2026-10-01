`timescale 1ns/1ps

module hazard_unit (
    input  logic [4:0] fe_rs1_addr,
    input  logic [4:0] fe_rs2_addr,
    input  logic       em_mem_read_en,
    input  logic [4:0] em_rd_addr,
    input  logic       branch_mispredict,
    
    output logic       stall_fetch,
    output logic       flush_execute
);

    logic load_use_hazard;
    
    always_comb begin
        load_use_hazard = em_mem_read_en && (em_rd_addr != 0) &&
                          ((em_rd_addr == fe_rs1_addr) || (em_rd_addr == fe_rs2_addr));
                          
        if (branch_mispredict) begin
            stall_fetch = 1'b0;
            flush_execute = 1'b1;
        end else if (load_use_hazard) begin
            stall_fetch = 1'b1;
            flush_execute = 1'b1;
        end else begin
            stall_fetch = 1'b0;
            flush_execute = 1'b0;
        end
    end

endmodule