`timescale 1ns/1ps
module ff_ram #(
    parameter int NBYTES = 1024,
    parameter bit ROM = 1'b0,
    parameter int LATENCY = 0,
    parameter string INIT_FILE = "meminit.bin",
    parameter string DUMP_FILE = "memsim.hex",
    parameter int DATA_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    bus_protocol_if.peripheral_vital bus
);
    localparam int WORD_BYTES = DATA_WIDTH / 8;
    localparam int NUM_WORDS = NBYTES / WORD_BYTES;
    localparam int ADDR_SHIFT = $clog2(WORD_BYTES);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [NUM_WORDS];

    // Initialization and Dump
    initial begin
        $readmemb(INIT_FILE, mem);
    end

    final begin
        $writememh(DUMP_FILE, mem);
    end

    // Latency handling
    logic [31:0] wait_cnt_q;
    logic [31:0] wait_cnt_d;
    logic active_trans_q;
    logic active_trans_d;

    always_comb begin
        wait_cnt_d = wait_cnt_q;
        active_trans_d = active_trans_q;

        if (!active_trans_q) begin
            if (bus.wen || bus.ren) begin
                if (LATENCY > 0) begin
                    active_trans_d = 1'b1;
                    wait_cnt_d = LATENCY - 1;
                end
            end
        end else begin
            if (wait_cnt_q > 0) begin
                wait_cnt_d = wait_cnt_q - 1;
            end else begin
                active_trans_d = 1'b0;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_cnt_q <= '0;
            active_trans_q <= 1'b0;
        end else begin
            wait_cnt_q <= wait_cnt_d;
            active_trans_q <= active_trans_d;
        end
    end

    logic stall_comb;
    always_comb begin
        stall_comb = 1'b0;
        if (LATENCY > 0) begin
            if (!active_trans_q && (bus.wen || bus.ren)) begin
                stall_comb = 1'b1;
            end else if (active_trans_q && wait_cnt_q > 0) begin
                stall_comb = 1'b1;
            end
        end
    end

    assign bus.request_stall = stall_comb;

    logic completing_now;
    assign completing_now = (bus.wen || bus.ren) && !stall_comb;

    // Address Decode
    logic [31:0] word_idx;
    assign word_idx = bus.addr >> ADDR_SHIFT;

    logic valid_addr;
    assign valid_addr = (bus.addr < NBYTES);

    always_comb begin
        bus.rdata = '0;
        bus.error = 1'b0;
        
        if (completing_now) begin
            if (!valid_addr) begin
                bus.error = 1'b1;
            end else begin
                if (bus.ren) begin
                    bus.rdata = mem[word_idx];
                end
                if (bus.wen) begin
                    if (ROM) begin
                        bus.error = 1'b1;
                    end
                end
            end
        end
    end

    // Memory Writes (Synchronous)
    // Directly updating memory without combinational array for simulation performance.
    always_ff @(posedge clk) begin
        if (completing_now && bus.wen && !ROM && valid_addr) begin
            for (int i = 0; i < WORD_BYTES; i++) begin
                if (bus.strobe[i]) begin
                    mem[word_idx][i*8 +: 8] <= bus.wdata[i*8 +: 8];
                end
            end
        end
    end

endmodule
