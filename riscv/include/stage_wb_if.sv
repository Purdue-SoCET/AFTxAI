`ifndef STAGE_WB_IF_SV
`define STAGE_WB_IF_SV
interface stage_wb_if;
    logic ex_valid, ex_reg_write, ex_mem_read, ex_mem_write, ex_wb_src_mem, ex_wb_src_pc, halt; logic [31:0] ex_pc, ex_alu_result, ex_store_data; logic [4:0] ex_rd; logic [2:0] ex_mem_size; logic dcache_valid; logic [31:0] dcache_addr, dcache_wdata, dcache_rdata; logic [3:0] dcache_wstrb; logic [31:0] wb_data_out; logic wb_reg_write_out; logic [4:0] wb_rd_out; modport mp (input ex_valid, ex_pc, ex_alu_result, ex_store_data, ex_rd, ex_reg_write, ex_mem_size, ex_mem_read, ex_mem_write, ex_wb_src_mem, ex_wb_src_pc, halt, dcache_rdata, output dcache_valid, dcache_addr, dcache_wdata, dcache_wstrb, wb_data_out, wb_reg_write_out, wb_rd_out);
endinterface
`endif
