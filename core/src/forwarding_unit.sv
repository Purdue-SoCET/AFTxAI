`timescale 1ns/1ps

module forwarding_unit (
    input  logic [4:0] ex_rs1_addr,
    input  logic [4:0] ex_rs2_addr,
    
    input  logic [4:0] mem_rd_addr,
    input  logic       mem_reg_write_en,
    input  logic [31:0] mem_writeback_data,

    output logic        use_forward_a,
    output logic [31:0] forward_a_val,
    
    output logic        use_forward_b,
    output logic [31:0] forward_b_val
);

    always_comb begin
        use_forward_a = 1'b0;
        forward_a_val = 32'd0;
        
        use_forward_b = 1'b0;
        forward_b_val = 32'd0;

        // Forward from Memory/Writeback stage back to Execute stage
        if (mem_reg_write_en && (mem_rd_addr != 5'd0)) begin
            if (mem_rd_addr == ex_rs1_addr) begin
                use_forward_a = 1'b1;
                forward_a_val = mem_writeback_data;
            end
            if (mem_rd_addr == ex_rs2_addr) begin
                use_forward_b = 1'b1;
                forward_b_val = mem_writeback_data;
            end
        end
    end

endmodule
