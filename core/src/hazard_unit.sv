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

    always_comb begin
        stall_fetch = 1'b0;
        flush_execute = 1'b0;

        // Load-use hazard detection
        if (em_mem_read_en && (em_rd_addr != 5'd0) &&
            ((em_rd_addr == fe_rs1_addr) || (em_rd_addr == fe_rs2_addr))) begin
            stall_fetch = 1'b1;
            flush_execute = 1'b1;
        end

        // Branch misprediction flush
        if (branch_mispredict) begin
            flush_execute = 1'b1;
        end
    end

endmodule
