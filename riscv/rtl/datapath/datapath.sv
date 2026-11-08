`timescale 1ns/1ps
module datapath #(parameter int RV32E = 0, parameter logic [31:0] BOOT_ADDR = 32'h0000_0000) (
    input logic HCLK, input logic nRST,
    datapath_if.mp port
);
    logic halt, next_halt;
    
    stage_if_if if_if();
    stage_ex_if ex_if();
    stage_wb_if wb_if();
    hazard_unit_if hz_if();
    branch_predictor_if bp_if();
    csr_unit_if csr_if();

    always_comb begin
        next_halt = halt;
        if (ex_if.illegal_instr || port.icache_error || port.dcache_error) next_halt = 1'b1;
    end
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) halt <= 1'b0;
        else halt <= next_halt;
    end
    assign port.halt = halt;
    
    assign hz_if.global_stall_in = halt || (port.icache_valid && !port.icache_ready) || (port.dcache_valid && !port.dcache_ready);
    assign hz_if.ex_is_branch = ex_if.ex_is_branch;
    assign hz_if.ex_branch_taken = ex_if.ex_branch_taken;
    assign hz_if.ex_pred_taken = ex_if.ex_pred_taken_out;
    assign hz_if.ex_is_jalr = ex_if.ex_is_jalr;
    assign hz_if.trap_flush = wb_if.trap_req_out || wb_if.mret_req_out;
    hazard_unit hz_inst(.port(hz_if.mp));

    assign bp_if.fetch_pc = if_if.fetch_pc;
    assign bp_if.update_valid = ex_if.bp_update_valid;
    assign bp_if.update_pc = ex_if.bp_update_pc;
    assign bp_if.update_taken = ex_if.bp_update_taken;
    branch_predictor #(.BHT_ENTRIES(64)) bp_inst(.HCLK(HCLK), .nRST(nRST), .port(bp_if.mp));

    assign port.icache_valid = !halt;
    assign port.icache_addr = if_if.icache_addr;
    assign if_if.global_stall = hz_if.global_stall_out;
    assign if_if.flush_if = hz_if.flush_if;
    assign if_if.trap_flush = hz_if.trap_flush;
    assign if_if.trap_target_pc = wb_if.mret_req_out ? csr_if.mepc_val : csr_if.mtvec_val;
    assign if_if.mispredict_target = ex_if.mispredict_target_out;
    assign if_if.icache_rdata = port.icache_rdata;
    assign if_if.bp_predict_taken = bp_if.predict_taken;
    stage_if #(.BOOT_ADDR(BOOT_ADDR)) if_inst(.HCLK(HCLK), .nRST(nRST), .port(if_if.mp));

    assign ex_if.global_stall = hz_if.global_stall_out;
    assign ex_if.flush_ex = hz_if.flush_ex;
    assign ex_if.if_valid_in = if_if.if_valid_out;
    assign ex_if.if_pc_in = if_if.if_pc_out;
    assign ex_if.if_instr_in = if_if.if_instr_out;
    assign ex_if.if_pred_taken_in = if_if.if_pred_taken_out;
    assign ex_if.wb_data_in = wb_if.wb_data_out;
    assign ex_if.wb_reg_write_in = wb_if.wb_reg_write_out;
    assign ex_if.wb_rd_in = wb_if.wb_rd_out;
    assign ex_if.csr_read_data_in = csr_if.csr_read_data;
    stage_ex #(.RV32E(RV32E)) ex_inst(.HCLK(HCLK), .nRST(nRST), .port(ex_if.mp));

    assign wb_if.ex_valid = ex_if.ex_valid_out;
    assign wb_if.ex_pc = ex_if.ex_pc_out;
    assign wb_if.ex_alu_result = ex_if.ex_alu_result_out;
    assign wb_if.ex_store_data = ex_if.ex_store_data_out;
    assign wb_if.ex_rd = ex_if.ex_rd_out;
    assign wb_if.ex_reg_write = ex_if.ex_reg_write_out;
    assign wb_if.ex_mem_size = ex_if.ex_mem_size_out;
    assign wb_if.ex_mem_read = ex_if.ex_mem_read_out;
    assign wb_if.ex_mem_write = ex_if.ex_mem_write_out;
    assign wb_if.ex_wb_src_mem = ex_if.ex_wb_src_mem_out;
    assign wb_if.ex_wb_src_pc = ex_if.ex_wb_src_pc_out;
    assign wb_if.ex_wb_src_csr = ex_if.ex_wb_src_csr_out;
    assign wb_if.ex_is_mret = ex_if.ex_is_mret_out;
    assign wb_if.ex_is_csr = ex_if.ex_is_csr_out;
    assign wb_if.ex_csr_addr = ex_if.ex_csr_addr_out;
    assign wb_if.ex_csr_read_data = ex_if.ex_csr_read_data_out;
    assign wb_if.ex_csr_write_data = ex_if.ex_csr_write_data_out;
    assign wb_if.halt = halt;
    assign wb_if.dcache_rdata = port.dcache_rdata;
    assign wb_if.interrupt_pending = csr_if.interrupt_pending;
    assign wb_if.interrupt_cause = csr_if.interrupt_cause;
    
    assign port.dcache_valid = wb_if.dcache_valid;
    assign port.dcache_addr = wb_if.dcache_addr;
    assign port.dcache_wdata = wb_if.dcache_wdata;
    assign port.dcache_wstrb = wb_if.dcache_wstrb;
    stage_wb wb_inst(.port(wb_if.mp));
    
    assign csr_if.mtip = port.mtip;
    assign csr_if.msip = port.msip;
    assign csr_if.meip = port.meip;
    assign csr_if.csr_read_addr = ex_if.csr_read_addr;
    assign csr_if.csr_write_en = wb_if.csr_write_en_out;
    assign csr_if.csr_write_addr = wb_if.csr_write_addr_out;
    assign csr_if.csr_write_data = wb_if.csr_write_data_out;
    assign csr_if.trap_req = wb_if.trap_req_out;
    assign csr_if.trap_cause = wb_if.trap_cause_out;
    assign csr_if.trap_pc = wb_if.trap_pc_out;
    assign csr_if.mret_req = wb_if.mret_req_out;
    csr_unit csr_inst(.HCLK(HCLK), .nRST(nRST), .port(csr_if.mp));
endmodule
