`timescale 1ns/1ps
module stage_wb(stage_wb_if.mp port);
    assign port.dcache_valid = port.ex_valid && (port.ex_mem_read || port.ex_mem_write) && !port.halt;
    assign port.dcache_addr  = port.ex_alu_result;
    assign port.dcache_wdata = port.ex_store_data;
    
    always_comb begin
        port.dcache_wstrb = 4'b0000;
        if (port.ex_valid && port.ex_mem_write) begin
            case (port.ex_mem_size[1:0])
                2'b00: port.dcache_wstrb = 4'b0001; 2'b01: port.dcache_wstrb = 4'b0011; 2'b10: port.dcache_wstrb = 4'b1111; default: port.dcache_wstrb = 4'b1111;
            endcase
        end
    end

    logic [31:0] load_data;
    always_comb begin
        load_data = port.dcache_rdata;
        if (port.ex_valid && port.ex_mem_read) begin
            case (port.ex_mem_size)
                3'b000: load_data = {{24{port.dcache_rdata[7]}}, port.dcache_rdata[7:0]};
                3'b001: load_data = {{16{port.dcache_rdata[15]}}, port.dcache_rdata[15:0]};
                3'b010: load_data = port.dcache_rdata;
                3'b100: load_data = {24'b0, port.dcache_rdata[7:0]};
                3'b101: load_data = {16'b0, port.dcache_rdata[15:0]};
                default: load_data = port.dcache_rdata;
            endcase
        end
    end

    assign port.wb_data_out = port.ex_wb_src_mem ? load_data : (port.ex_wb_src_pc ? (port.ex_pc + 32'd4) : port.ex_alu_result);
    assign port.wb_reg_write_out = port.ex_reg_write && port.ex_valid;
    assign port.wb_rd_out = port.ex_rd;
endmodule
