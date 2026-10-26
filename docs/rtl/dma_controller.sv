module dma_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter COUNT_W = 8,
    parameter FIFO_DEPTH = 8,
    parameter FIFO_PKT_W = 2 + ADDR_WIDTH + DATA_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    // CPU slave interface
    input  logic        wen,
    input  logic        ren,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        ready,
    output logic        irq,

    // AHB Master interface
    ahb_if.manager      ahb_m
);

    logic [ADDR_WIDTH-1:0] sar;
    logic [ADDR_WIDTH-1:0] dar;
    logic [COUNT_W-1:0]    tsr;
    logic [31:0]           cr;

    logic fsm_finished;
    logic fsm_error;
    logic fsm_clear_en;

    logic read_error, write_error;
    logic write_unit_done;
    
    // Overall completion check
    logic [COUNT_W-1:0] write_count;
    logic write_count_done;
    logic write_count_clear;

    // Registers
    registers #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .COUNT_W(COUNT_W)
    ) regs (
        .clk(clk),
        .rst_n(rst_n),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .ready(ready),
        .sar(sar),
        .dar(dar),
        .tsr(tsr),
        .cr(cr),
        .fsm_finished(fsm_finished),
        .fsm_error(fsm_error),
        .fsm_clear_en(fsm_clear_en),
        .irq(irq)
    );

    // Arbiter internal interface
    memArb_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_arb_if();

    // Arbiter
    memArbiter #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_if(mem_arb_if.arbiter_port),
        .ahb_m(ahb_m)
    );

    // FIFO signals
    logic fifo_full, fifo_empty, fifo_push, fifo_pop;
    logic [1:0]            push_psize, pop_psize;
    logic [ADDR_WIDTH-1:0] push_dest, pop_dest;
    logic [DATA_WIDTH-1:0] push_data, pop_data;
    logic fifo_clear;

    // Flush FIFO on error or when disabled
    assign fifo_clear = fsm_error || !cr[0];

    fifo #(
        .DATA_WIDTH(FIFO_PKT_W),
        .DEPTH(FIFO_DEPTH)
    ) data_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .clear(fifo_clear),
        .push(fifo_push),
        .data_in({push_psize, push_dest, push_data}),
        .full(fifo_full),
        .pop(fifo_pop),
        .data_out({pop_psize, pop_dest, pop_data}),
        .empty(fifo_empty)
    );

    // Read Controller
    read_control #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .COUNT_W(COUNT_W)
    ) r_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .sar(sar),
        .dar(dar),
        .tsr(tsr),
        .cr(cr),
        .fifo_full(fifo_full),
        .fifo_push(fifo_push),
        .fifo_psize(push_psize),
        .fifo_dest(push_dest),
        .fifo_data(push_data),
        .fsm_error(read_error),
        .arb_if(mem_arb_if.read_port)
    );

    // Write Controller
    write_control #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) w_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .cr(cr),
        .fifo_empty(fifo_empty),
        .fifo_pop(fifo_pop),
        .fifo_psize(pop_psize),
        .fifo_dest(pop_dest),
        .fifo_data(pop_data),
        .fsm_error(write_error),
        .fsm_finished(write_unit_done),
        .arb_if(mem_arb_if.write_port)
    );

    // Track write completions
    counter #(COUNT_W) write_cnt (
        .clk(clk),
        .rst_n(rst_n),
        .clear(write_count_clear),
        .inc(write_unit_done),
        .limit(tsr),
        .count(write_count),
        .done(write_count_done)
    );

    assign write_count_clear = !cr[0]; // Clear count when transfer starts/ends
    assign fsm_error = read_error | write_error;
    
    // Overall finish: The write side has finished the requested number of units,
    // and there is no error.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_finished <= 1'b0;
            fsm_clear_en <= 1'b0;
        end else begin
            if (cr[0] && write_count_done && !fsm_error) begin
                fsm_finished <= 1'b1;
                fsm_clear_en <= 1'b1;
            end else begin
                fsm_finished <= 1'b0;
                fsm_clear_en <= 1'b0;
            end
        end
    end

endmodule
