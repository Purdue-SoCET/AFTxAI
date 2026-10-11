`timescale 1ns/1ps

module core #(
    parameter int RV32E = 0,
    parameter logic [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic HCLK,
    input  logic nRST,

    // Instruction Cache Interface
    cpu_cache_if.cpu icache_if,

    // Data Cache Interface
    cpu_cache_if.cpu dcache_if
);

    // -- Opcodes --
    localparam [6:0] OPC_LOAD   = 7'b0000011;
    localparam [6:0] OPC_IMM    = 7'b0010011;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_STORE  = 7'b0100011;
    localparam [6:0] OPC_OP     = 7'b0110011;
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_BRANCH = 7'b1100011;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_JAL    = 7'b1101111;

    // -- Pipeline Registers --
    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] instr;
        logic        pred_taken;
    } if_ex_reg_t;

    typedef struct packed {
        logic        valid;
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] store_data;
        logic [4:0]  rd;
        logic        reg_write;
        logic [2:0]  mem_size;
        logic        mem_read;
        logic        mem_write;
        logic        wb_src_mem;
        logic        wb_src_pc;
    } ex_wb_reg_t;

    if_ex_reg_t if_ex_n, if_ex_q;
    ex_wb_reg_t ex_wb_n, ex_wb_q;

    // -- Global Halt & Stall --
    logic halt_q;
    logic illegal_instr_ex;

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) halt_q <= 1'b0;
        else if (illegal_instr_ex || icache_if.error || dcache_if.error) halt_q <= 1'b1;
    end

    logic global_stall;
    assign global_stall = halt_q || 
                          (icache_if.valid && !icache_if.ready) || 
                          (dcache_if.valid && !dcache_if.ready);

    // -- IF Stage --
    logic [31:0] pc_q, next_pc;
    logic        flush_if;
    logic [31:0] mispredict_target;
    logic        bp_predict_taken;

    assign icache_if.valid = !halt_q;
    assign icache_if.addr  = pc_q;
    assign icache_if.wdata = 32'b0;
    assign icache_if.wstrb = 4'b0;

    // Decode branch/jump immediates early to allow target prediction
    logic [31:0] if_imm_b;
    assign if_imm_b = {{20{icache_if.rdata[31]}}, icache_if.rdata[7], icache_if.rdata[30:25], icache_if.rdata[11:8], 1'b0};
    logic [31:0] if_imm_j;
    assign if_imm_j = {{12{icache_if.rdata[31]}}, icache_if.rdata[19:12], icache_if.rdata[20], icache_if.rdata[30:21], 1'b0};
    
    logic if_is_branch, if_is_jal;
    assign if_is_branch = (icache_if.rdata[6:0] == OPC_BRANCH);
    assign if_is_jal    = (icache_if.rdata[6:0] == OPC_JAL);

    logic [31:0] pc_target_if;
    assign pc_target_if = pc_q + (if_is_jal ? if_imm_j : if_imm_b);

    always_comb begin
        if (flush_if) next_pc = mispredict_target;
        else if (global_stall) next_pc = pc_q;
        else if (if_is_jal || (if_is_branch && bp_predict_taken)) next_pc = pc_target_if;
        else next_pc = pc_q + 32'd4;
    end

    // -- Pipeline Flip-Flops --
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            pc_q <= BOOT_ADDR;
            if_ex_q <= '0;
            ex_wb_q <= '0;
        end else begin
            if (!global_stall) begin
                pc_q <= next_pc;
                
                if (flush_if) begin
                    if_ex_q <= '0; // Bubble
                end else begin
                    if_ex_q.valid      <= 1'b1;
                    if_ex_q.pc         <= pc_q;
                    if_ex_q.instr      <= icache_if.rdata;
                    if_ex_q.pred_taken <= (if_is_branch && bp_predict_taken);
                end
                
                ex_wb_q <= ex_wb_n;
            end
        end
    end

    // -- EX Stage --
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;
    
    assign opcode = if_ex_q.instr[6:0];
    assign funct3 = if_ex_q.instr[14:12];
    assign funct7 = if_ex_q.instr[31:25];
    assign rs1    = if_ex_q.instr[19:15];
    assign rs2    = if_ex_q.instr[24:20];
    assign rd     = if_ex_q.instr[11:7];

    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    assign imm_i = {{20{if_ex_q.instr[31]}}, if_ex_q.instr[31:20]};
    assign imm_s = {{20{if_ex_q.instr[31]}}, if_ex_q.instr[31:25], if_ex_q.instr[11:7]};
    assign imm_b = {{20{if_ex_q.instr[31]}}, if_ex_q.instr[7], if_ex_q.instr[30:25], if_ex_q.instr[11:8], 1'b0};
    assign imm_u = {if_ex_q.instr[31:12], 12'b0};
    assign imm_j = {{12{if_ex_q.instr[31]}}, if_ex_q.instr[19:12], if_ex_q.instr[20], if_ex_q.instr[30:21], 1'b0};

    logic [31:0] wb_data; // From WB stage for forwarding
    logic [31:0] rdata1, rdata2;

    regfile #(.NUM_REGS(RV32E ? 16 : 32)) rf_inst (
        .HCLK(HCLK), 
        .nRST(nRST),
        .rs1(rs1), 
        .rdata1(rdata1),
        .rs2(rs2), 
        .rdata2(rdata2),
        .we(ex_wb_q.reg_write && ex_wb_q.valid),
        .rd(ex_wb_q.rd), 
        .wdata(wb_data)
    );

    // Hazard Forwarding Logic (WB -> EX)
    logic [31:0] fwd_rs1, fwd_rs2;
    always_comb begin
        fwd_rs1 = rdata1;
        fwd_rs2 = rdata2;
        if (ex_wb_q.valid && ex_wb_q.reg_write && ex_wb_q.rd == rs1 && rs1 != 0) begin
            fwd_rs1 = wb_data;
        end
        if (ex_wb_q.valid && ex_wb_q.reg_write && ex_wb_q.rd == rs2 && rs2 != 0) begin
            fwd_rs2 = wb_data;
        end
    end

    // Branch Resolution
    logic branch_taken_ex;
    always_comb begin
        branch_taken_ex = 1'b0;
        case (funct3)
            3'b000: branch_taken_ex = (fwd_rs1 == fwd_rs2);
            3'b001: branch_taken_ex = (fwd_rs1 != fwd_rs2);
            3'b100: branch_taken_ex = ($signed(fwd_rs1) < $signed(fwd_rs2));
            3'b101: branch_taken_ex = ($signed(fwd_rs1) >= $signed(fwd_rs2));
            3'b110: branch_taken_ex = (fwd_rs1 < fwd_rs2);
            3'b111: branch_taken_ex = (fwd_rs1 >= fwd_rs2);
            default: ;
        endcase
    end

    logic [3:0] alu_op;
    logic [31:0] alu_a, alu_b, alu_result;
    logic alu_src_a_pc, alu_src_b_imm;
    logic [31:0] alu_imm;

    alu alu_inst (
        .a(alu_a), 
        .b(alu_b), 
        .alu_op(alu_op),
        .result(alu_result), 
        .zero()
    );

    assign alu_a = alu_src_a_pc ? if_ex_q.pc : fwd_rs1;
    assign alu_b = alu_src_b_imm ? alu_imm : fwd_rs2;

    logic is_branch_ex;
    logic bp_update_valid;
    
    // Update predictor when instruction is valid and it's a branch
    assign bp_update_valid = if_ex_q.valid && is_branch_ex && !global_stall;

    // Main Control Decode
    always_comb begin
        ex_wb_n.valid      = if_ex_q.valid;
        ex_wb_n.pc         = if_ex_q.pc;
        ex_wb_n.alu_result = alu_result;
        ex_wb_n.store_data = fwd_rs2;
        ex_wb_n.rd         = rd;
        ex_wb_n.reg_write  = 1'b0;
        ex_wb_n.mem_size   = funct3;
        ex_wb_n.mem_read   = 1'b0;
        ex_wb_n.mem_write  = 1'b0;
        ex_wb_n.wb_src_mem = 1'b0;
        ex_wb_n.wb_src_pc  = 1'b0;
        
        alu_op = 4'd0;
        alu_src_a_pc = 1'b0;
        alu_src_b_imm = 1'b0;
        alu_imm = 32'b0;
        
        is_branch_ex = 1'b0;
        illegal_instr_ex = 1'b0;
        
        flush_if = 1'b0;
        mispredict_target = 32'b0;

        if (if_ex_q.valid) begin
            case (opcode)
                OPC_LUI: begin
                    ex_wb_n.reg_write = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_u;
                    alu_op = 4'd10; // PASS_B
                end
                OPC_AUIPC: begin
                    ex_wb_n.reg_write = 1'b1;
                    alu_src_a_pc = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_u;
                    alu_op = 4'd0; // ADD
                end
                OPC_JAL: begin
                    ex_wb_n.reg_write = 1'b1;
                    ex_wb_n.wb_src_pc = 1'b1;
                end
                OPC_JALR: begin
                    ex_wb_n.reg_write = 1'b1;
                    ex_wb_n.wb_src_pc = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_i;
                    alu_op = 4'd0; // ADD
                    
                    flush_if = 1'b1;
                    mispredict_target = (alu_result & ~32'b1);
                end
                OPC_BRANCH: begin
                    is_branch_ex = 1'b1;
                    if (branch_taken_ex != if_ex_q.pred_taken) begin
                        flush_if = 1'b1;
                        mispredict_target = branch_taken_ex ? (if_ex_q.pc + imm_b) : (if_ex_q.pc + 32'd4);
                    end
                end
                OPC_LOAD: begin
                    ex_wb_n.reg_write = 1'b1;
                    ex_wb_n.mem_read = 1'b1;
                    ex_wb_n.wb_src_mem = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_i;
                    alu_op = 4'd0; // ADD
                end
                OPC_STORE: begin
                    ex_wb_n.mem_write = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_s;
                    alu_op = 4'd0; // ADD
                end
                OPC_IMM: begin
                    ex_wb_n.reg_write = 1'b1;
                    alu_src_b_imm = 1'b1;
                    alu_imm = imm_i;
                    case (funct3)
                        3'b000: alu_op = 4'd0; // ADD
                        3'b010: alu_op = 4'd3; // SLT
                        3'b011: alu_op = 4'd4; // SLTU
                        3'b100: alu_op = 4'd5; // XOR
                        3'b110: alu_op = 4'd8; // OR
                        3'b111: alu_op = 4'd9; // AND
                        3'b001: alu_op = 4'd2; // SLL
                        3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRA : SRL
                    endcase
                end
                OPC_OP: begin
                    ex_wb_n.reg_write = 1'b1;
                    case (funct3)
                        3'b000: alu_op = funct7[5] ? 4'd1 : 4'd0; // SUB : ADD
                        3'b010: alu_op = 4'd3; // SLT
                        3'b011: alu_op = 4'd4; // SLTU
                        3'b100: alu_op = 4'd5; // XOR
                        3'b110: alu_op = 4'd8; // OR
                        3'b111: alu_op = 4'd9; // AND
                        3'b001: alu_op = 4'd2; // SLL
                        3'b101: alu_op = funct7[5] ? 4'd7 : 4'd6; // SRA : SRL
                    endcase
                end
                default: illegal_instr_ex = 1'b1;
            endcase
        end
    end

    // -- Predictor Instantiation --
    branch_predictor #(.BHT_ENTRIES(64)) bp_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .fetch_pc(pc_q),
        .predict_taken(bp_predict_taken),
        .update_valid(bp_update_valid),
        .update_pc(if_ex_q.pc),
        .update_taken(branch_taken_ex)
    );

    // -- WB Stage --
    assign dcache_if.valid = ex_wb_q.valid && (ex_wb_q.mem_read || ex_wb_q.mem_write) && !halt_q;
    assign dcache_if.addr  = ex_wb_q.alu_result;
    assign dcache_if.wdata = ex_wb_q.store_data;
    
    always_comb begin
        dcache_if.wstrb = 4'b0000;
        if (ex_wb_q.valid && ex_wb_q.mem_write) begin
            case (ex_wb_q.mem_size[1:0]) // based on funct3[1:0]
                2'b00: dcache_if.wstrb = 4'b0001; // B
                2'b01: dcache_if.wstrb = 4'b0011; // H
                2'b10: dcache_if.wstrb = 4'b1111; // W
                default: dcache_if.wstrb = 4'b1111;
            endcase
        end
    end

    logic [31:0] load_data;
    always_comb begin
        load_data = dcache_if.rdata;
        if (ex_wb_q.valid && ex_wb_q.mem_read) begin
            case (ex_wb_q.mem_size)
                3'b000: load_data = {{24{dcache_if.rdata[7]}}, dcache_if.rdata[7:0]};
                3'b001: load_data = {{16{dcache_if.rdata[15]}}, dcache_if.rdata[15:0]};
                3'b010: load_data = dcache_if.rdata;
                3'b100: load_data = {24'b0, dcache_if.rdata[7:0]};
                3'b101: load_data = {16'b0, dcache_if.rdata[15:0]};
                default: load_data = dcache_if.rdata;
            endcase
        end
    end

    assign wb_data = ex_wb_q.wb_src_mem ? load_data : 
                     ex_wb_q.wb_src_pc  ? (ex_wb_q.pc + 32'd4) : 
                     ex_wb_q.alu_result;

endmodule
