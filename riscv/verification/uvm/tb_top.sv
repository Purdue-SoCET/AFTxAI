`timescale 1ns/1ps
module tb_top;
    logic HCLK;
    logic nRST;

    bus_ahbm_if ahbm_if();
    riscv_if r_if();

    riscv dut (
        .HCLK(HCLK),
        .nRST(nRST),
        .ahbm_if(ahbm_if),
        .port(r_if.mp)
    );

    ahb_memory mem_inst (
        .HCLK(HCLK),
        .nRST(nRST),
        .ahbm_if(ahbm_if)
    );

    initial begin
        $display("Simulation started.");
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    always @(posedge HCLK) begin
        if (nRST && !dut.dp_inst.if_if.global_stall && dut.dp_inst.if_if.if_valid_out)
            $display("Time=%0t Fetch PC=%08x", $time, dut.dp_inst.if_if.if_pc_out);
        if (nRST && dut.dp_inst.wb_if.trap_req_out)
            $display("Time=%0t TRAP_REQ_OUT asserted! Trap PC=%08x Cause=%08x", $time, dut.dp_inst.wb_if.trap_pc_out, dut.dp_inst.wb_if.trap_cause_out);
        if (nRST && dut.dp_inst.wb_if.wb_reg_write_out && !dut.dp_inst.hz_if.global_stall_out && dut.dp_inst.wb_if.wb_rd_out != 0)
            $display("Time=%0t RegWrite rd=%0d data=%08x", $time, dut.dp_inst.wb_if.wb_rd_out, dut.dp_inst.wb_if.wb_data_out);
    end

    initial begin
        nRST = 0;
        r_if.mtip = 0;
        r_if.msip = 0;
        r_if.meip = 0;
        #20 nRST = 1;
        #200;
        r_if.mtip = 1;
        #500;
        r_if.mtip = 0;
        #500000;
        $display("TIMEOUT: Simulation ran too long.");
        $finish;
    end
endmodule
