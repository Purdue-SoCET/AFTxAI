`ifndef PIPELINE_IF_SV
`define PIPELINE_IF_SV

// Interface between Fetch and Execute stages
interface fetch_exec_if;
    logic [31:0] pc;
    logic [31:0] instruction;
    logic        inst_valid;
    logic        predicted_taken;
    logic [31:0] predicted_target;

    modport fetch (
        output pc, instruction, inst_valid, predicted_taken, predicted_target
    );
    
    modport exec (
        input pc, instruction, inst_valid, predicted_taken, predicted_target
    );
endinterface

// Interface between Execute and Memory stages
interface exec_mem_if;
    logic [31:0] pc;
    logic [31:0] alu_result;
    logic [31:0] store_data;
    logic [4:0]  rd_addr;
    logic        reg_write_en;
    logic        mem_read_en;
    logic        mem_write_en;
    logic [2:0]  mem_size; // byte, half, word
    logic        valid;

    modport exec (
        output pc, alu_result, store_data, rd_addr, reg_write_en, mem_read_en, mem_write_en, mem_size, valid
    );

    modport mem (
        input pc, alu_result, store_data, rd_addr, reg_write_en, mem_read_en, mem_write_en, mem_size, valid
    );
endinterface

// Writeback interface from Memory to Register File (in Execute)
interface mem_wb_if;
    logic [31:0] writeback_data;
    logic [4:0]  rd_addr;
    logic        reg_write_en;

    modport mem (
        output writeback_data, rd_addr, reg_write_en
    );

    modport exec (
        input writeback_data, rd_addr, reg_write_en
    );
endinterface

`endif
