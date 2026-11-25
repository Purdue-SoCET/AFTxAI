// Generated synthesis-only parent for AFTxAI's verified aft_top interface.
// DO NOT COMMIT THIS FILE INTO THE SOC REPOSITORY.
// This wrapper only converts the external SRAM SystemVerilog interface into
// ordinary top-level pins. It is not a SRAM model, pad macro, or RTL redesign.
// Keep ports of this module synchronized with the verified aft_top.sv.
`ifndef USE_SRAM_MACRO
`define USE_SRAM_MACRO 1'b0
`endif

module aft_synth_top #(
    parameter bit USE_SRAM_MACRO = `USE_SRAM_MACRO
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [31:0] gpio0_in,
    output logic [31:0] gpio0_out, gpio0_oe, gpio0_pu, gpio0_pd,
    input  logic [15:0] gpio1_in,
    output logic [15:0] gpio1_out, gpio1_oe, gpio1_pu, gpio1_pd,
    input  logic [6:0] gpio2_in,
    output logic [6:0] gpio2_out, gpio2_oe, gpio2_pu, gpio2_pd,
    input  logic [0:0] gpio3_in,
    output logic [0:0] gpio3_out, gpio3_oe, gpio3_pu, gpio3_pd,
    output logic [3:0] pwm_out, pwm_oe,
    input  logic timer_capture,
    output logic [18:0] sram_addr,
    output logic [15:0] sram_wdata,
    input  logic [15:0] sram_rdata,
    output logic sram_pad_oe,
    output logic sram_ce0_n, sram_oe0_n, sram_we0_n, sram_ub0_n, sram_lb0_n,
    output logic sram_ce1_n, sram_oe1_n, sram_we1_n, sram_ub1_n, sram_lb1_n,
    input  logic uart_rx,
    output logic uart_tx,
    input  logic spi0_miso,
    output logic spi0_mosi, spi0_sck, spi0_cs_n,
    inout wire i2c0_sda,
    inout wire i2c0_scl
);
    sram_if #(.ADDR_WIDTH(19)) sram_bus();
    assign sram_addr = sram_bus.addr;
    assign sram_wdata = sram_bus.wdata;
    assign sram_bus.rdata = sram_rdata;
    assign sram_pad_oe = sram_bus.pad_oe;
    assign sram_ce0_n = sram_bus.ce0_n;
    assign sram_oe0_n = sram_bus.oe0_n;
    assign sram_we0_n = sram_bus.we0_n;
    assign sram_ub0_n = sram_bus.ub0_n;
    assign sram_lb0_n = sram_bus.lb0_n;
    assign sram_ce1_n = sram_bus.ce1_n;
    assign sram_oe1_n = sram_bus.oe1_n;
    assign sram_we1_n = sram_bus.we1_n;
    assign sram_ub1_n = sram_bus.ub1_n;
    assign sram_lb1_n = sram_bus.lb1_n;

    aft_top #(
        .USE_SRAM_MACRO(USE_SRAM_MACRO)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .gpio0_in(gpio0_in), .gpio0_out(gpio0_out), .gpio0_oe(gpio0_oe),
        .gpio0_pu(gpio0_pu), .gpio0_pd(gpio0_pd),
        .gpio1_in(gpio1_in), .gpio1_out(gpio1_out), .gpio1_oe(gpio1_oe),
        .gpio1_pu(gpio1_pu), .gpio1_pd(gpio1_pd),
        .gpio2_in(gpio2_in), .gpio2_out(gpio2_out), .gpio2_oe(gpio2_oe),
        .gpio2_pu(gpio2_pu), .gpio2_pd(gpio2_pd),
        .gpio3_in(gpio3_in), .gpio3_out(gpio3_out), .gpio3_oe(gpio3_oe),
        .gpio3_pu(gpio3_pu), .gpio3_pd(gpio3_pd),
        .pwm_out(pwm_out), .pwm_oe(pwm_oe),
        .timer_capture(timer_capture),
        .sram(sram_bus.controller),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .spi0_miso(spi0_miso), .spi0_mosi(spi0_mosi),
        .spi0_sck(spi0_sck), .spi0_cs_n(spi0_cs_n),
        .i2c0_sda(i2c0_sda), .i2c0_scl(i2c0_scl)
    );
endmodule
