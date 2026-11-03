/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module dma_controller #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COUNT_W = 8,
    parameter int FIFO_DEPTH = 8,
    parameter int FIFO_PKT_W = 2 + ADDR_W + DATA_W
)(
    input  logic clk,
    input  logic rst_n,
    
    input  logic drq,
    output logic daq,
    output logic irq,
    
    apb_if.completer reg_bus,
    ahb_if.manager   mem_bus
);

    logic [ADDR_W-1:0]  sar;
    logic [ADDR_W-1:0]  dar;
    logic [COUNT_W-1:0] tsr;
    logic [31:0]        cr;
    
    logic clear_status, hw_clear_en;
    logic hw_finished_r, hw_error_r;
    logic hw_error_w;
    logic write_finished;
    
    logic hw_finished;
    logic hw_error;
    
    assign hw_finished = hw_finished_r;
    assign hw_error    = hw_error_r | hw_error_w;
    
    registers #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COUNT_W(COUNT_W)
    ) i_regs (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(reg_bus.PADDR),
        .psel(reg_bus.PSEL),
        .penable(reg_bus.PENABLE),
        .pwrite(reg_bus.PWRITE),
        .pwdata(reg_bus.PWDATA),
        .prdata(reg_bus.PRDATA),
        .pready(reg_bus.PREADY),
        .pslverr(reg_bus.PSLVERR),
        .sar(sar),
        .dar(dar),
        .tsr(tsr),
        .cr(cr),
        .hw_finished(hw_finished),
        .hw_error(hw_error),
        .clear_status(clear_status),
        .irq(irq),
        .hw_clear_en(hw_clear_en)
    );
    
    logic fifo_full, fifo_empty, fifo_push, fifo_pop, fifo_clear;
    logic [FIFO_PKT_W-1:0] fifo_data_in, fifo_data_out;
    
    fifo #(
        .WIDTH(FIFO_PKT_W),
        .DEPTH(FIFO_DEPTH)
    ) i_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .clear(fifo_clear),
        .push(fifo_push),
        .data_in(fifo_data_in),
        .full(fifo_full),
        .pop(fifo_pop),
        .data_out(fifo_data_out),
        .empty(fifo_empty)
    );
    
    logic cnt_clear, cnt_inc;
    logic [COUNT_W-1:0] count;
    
    counter #(
        .COUNT_W(COUNT_W)
    ) i_counter (
        .clk(clk),
        .rst_n(rst_n),
        .clear(cnt_clear),
        .inc(cnt_inc),
        .count(count)
    );
    
    memArb_if #(
        .ADDR_WIDTH(ADDR_W),
        .DATA_WIDTH(DATA_W)
    ) arb_if (
        .clk(clk),
        .rst_n(rst_n)
    );
    
    read_control #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .COUNT_W(COUNT_W),
        .FIFO_PKT_W(FIFO_PKT_W)
    ) i_read_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .sar(sar),
        .dar(dar),
        .tsr(tsr),
        .cr(cr),
        .drq(drq),
        .daq(daq),
        .cnt_clear(cnt_clear),
        .cnt_inc(cnt_inc),
        .count(count),
        .r_req(arb_if.r_req),
        .r_addr(arb_if.r_addr),
        .r_size(arb_if.r_size),
        .r_gnt(arb_if.r_gnt),
        .r_ready(arb_if.r_ready),
        .r_rdata(arb_if.r_rdata),
        .r_err(arb_if.r_err),
        .fifo_full(fifo_full),
        .fifo_push(fifo_push),
        .fifo_data(fifo_data_in),
        .fifo_clear(fifo_clear),
        .hw_finished(hw_finished_r),
        .hw_error(hw_error_r),
        .write_finished(write_finished)
    );
    
    write_control #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .FIFO_PKT_W(FIFO_PKT_W)
    ) i_write_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .fifo_empty(fifo_empty),
        .fifo_pop(fifo_pop),
        .fifo_data(fifo_data_out),
        .w_req(arb_if.w_req),
        .w_addr(arb_if.w_addr),
        .w_size(arb_if.w_size),
        .w_data(arb_if.w_data),
        .w_gnt(arb_if.w_gnt),
        .w_ready(arb_if.w_ready),
        .w_err(arb_if.w_err),
        .hw_error(hw_error_w),
        .write_finished(write_finished),
        .en(cr[0])
    );
    
    memArbiter #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W)
    ) i_arbiter (
        .arb(arb_if.arbiter),
        .ahb(mem_bus)
    );

endmodule
