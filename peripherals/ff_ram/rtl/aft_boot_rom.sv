`timescale 1ns/1ps

module aft_boot_rom #(
    parameter int NBYTES = 4096,
    parameter int DATA_WIDTH = 32
) (
    input  logic clk,
    input  logic rst_n,
    bus_protocol_if.peripheral_vital bus
);
    localparam int WORD_BYTES = DATA_WIDTH / 8;
    localparam int NUM_WORDS = NBYTES / WORD_BYTES;
    localparam int ADDR_SHIFT = $clog2(WORD_BYTES);

    logic [31:0] word_idx;
    assign word_idx = bus.addr >> ADDR_SHIFT;

    logic valid_addr;
    assign valid_addr = (bus.addr < NBYTES);

    // Latency handling (0-wait state synchronous response)
    logic [31:0] rom_data;

    always_comb begin
        case (word_idx)
            // Word 0 (0x400): Set GPIO0 Direction: REG32(0x80000008) = 0x0000FFFF
            // lui t0, 0x80000
            32'd0: rom_data = 32'h800002b7;
            // li t1, 0xFFFF:
            // lui t1, 0x10 (16 << 12 = 0x10000)
            32'd1: rom_data = 32'h00010337;
            // addi t1, t1, -1 (0x10000 - 1 = 0x0000FFFF)
            32'd2: rom_data = 32'hfff30313;
            // sw t1, 8(t0) -> writes to GPIO0_DIR (0x80000008)
            32'd3: rom_data = 32'h0062a423;

            // Word 4 (0x410): Write test pattern to GPIO0_DATA (0x80000004): REG32(0x80000004) = 0x0000A5A5
            // li t1, 0xA5A5:
            // lui t1, 0xA (10 << 12 = 0x0000A000)
            32'd4: rom_data = 32'h0000a337;
            // addi t1, t1, 0x5a5 (0x0000A000 + 0x5A5 = 0x0000A5A5)
            32'd5: rom_data = 32'h5a530313;
            // sw t1, 4(t0) -> writes to GPIO0_DATA (0x80000004)
            32'd6: rom_data = 32'h0062a223;

            // Word 7 (0x41C): Write and readback test on On-Chip SRAM (0x00008400)
            // lui t2, 0x8
            32'd7: rom_data = 32'h000083b7;
            // addi t2, t2, 0x400 -> t2 = 0x00008400
            32'd8: rom_data = 32'h40038393;
            // sw t1, 0(t2) -> store 0x0000A5A5 to SRAM word 0
            32'd9: rom_data = 32'h0063a023;
            // lw t3, 0(t2) -> load back into t3
            32'd10: rom_data = 32'h0003a383;

            // Word 11 (0x42C): Verify readback value == 0x0000A5A5
            // sub t4, t3, t1 (should be 0 if match)
            32'd11: rom_data = 32'h40638eb3;
            // bne t4, x0, fail (jump to fail: pc + 16 -> word 16)
            32'd12: rom_data = 32'h000eb863;

            // Word 13 (0x434): PASS sequence!
            // Update GPIO0_DATA to 0x00005A5A (signals PASS to outside world)
            // li t1, 0x5A5A:
            // lui t1, 0x6 (6 << 12 = 24576 = 0x00006000)
            32'd13: rom_data = 32'h00006337;
            // addi t1, t1, -1446 (0x6000 - 0x5A6 = 0x00005A5A; 12'hA5A is sign-extended -1446)
            32'd14: rom_data = 32'ha5a30313;
            // sw t1, 4(t0) -> writes 0x5A5A to GPIO0_DATA
            32'd15: rom_data = 32'h0062a223;

            // Word 16 (0x440): Infinite loop / halt (pass or fail)
            // 1: j 1b (jal x0, 0)
            32'd16: rom_data = 32'h0000006f;

            default: rom_data = 32'h00000013; // nop (addi x0, x0, 0)
        endcase
    end

    always_comb begin
        bus.rdata = '0;
        bus.error = 1'b0;
        bus.request_stall = 1'b0;

        if (bus.ren && valid_addr) begin
            bus.rdata = rom_data;
        end else if (bus.wen) begin
            // ROM is read-only
            bus.error = 1'b1;
        end else if (bus.ren && !valid_addr) begin
            bus.error = 1'b1;
        end
    end

endmodule
