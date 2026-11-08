`ifndef STAGE_WB_IF_SV
`define STAGE_WB_IF_SV
interface stage_wb_if;
    logic ex_valid, ex_reg_write, ex_mem_read, ex_mem_write, ex_wb_src_mem, ex_wb_src_pc, halt; 
    logic [31:0] ex_pc, ex_alu_result, ex_store_data; 
    logic [4:0] ex_rd; 
    logic [2:0] ex_mem_size; 
    
    logic ex_wb_src_csr, ex_is_mret, ex_is_csr;
    logic [31:0] ex_csr_read_data; // Needed for WB data mux
    logic [11:0] ex_csr_addr;      // Passed from EX
    logic [31:0] ex_csr_write_data; // Passed from EX
    
    logic dcache_valid; 
    logic [31:0] dcache_addr, dcache_wdata, dcache_rdata; 
    logic [3:0] dcache_wstrb; 
    logic [31:0] wb_data_out; 
    logic wb_reg_write_out; 
    logic [4:0] wb_rd_out; 

    // Interacting with CSR / Hazard
    logic interrupt_pending;
    logic [31:0] interrupt_cause;
    
    logic trap_req_out;
    logic [31:0] trap_cause_out;
    logic [31:0] trap_pc_out;
    logic mret_req_out;
    
    logic csr_write_en_out;
    logic [11:0] csr_write_addr_out;
    logic [31:0] csr_write_data_out;

    modport mp (
        input ex_valid, ex_pc, ex_alu_result, ex_store_data, ex_rd, ex_reg_write, ex_mem_size, ex_mem_read, ex_mem_write, ex_wb_src_mem, ex_wb_src_pc, ex_wb_src_csr, ex_is_mret, ex_is_csr, ex_csr_read_data, ex_csr_addr, ex_csr_write_data, halt, dcache_rdata, interrupt_pending, interrupt_cause,
        output dcache_valid, dcache_addr, dcache_wdata, dcache_wstrb, wb_data_out, wb_reg_write_out, wb_rd_out, trap_req_out, trap_cause_out, trap_pc_out, mret_req_out, csr_write_en_out, csr_write_addr_out, csr_write_data_out
    );
endinterface
`endif
