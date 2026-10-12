`timescale 1ns/1ps
module ahb_memory (
    input logic HCLK,
    input logic nRST,
    bus_ahbm_if.subordinate ahbm_if
);
    logic [31:0] mem [0:2047]; // 8KB
    
    initial begin
        for(int i=0; i<2048; i++) mem[i] = 32'b0;
        $readmemh("mem.hex", mem);
    end

    // Combinational 0-wait state memory
    always_ff @(posedge HCLK) begin
        if (ahbm_if.req && !ahbm_if.rnw && ahbm_if.addr < 8192) begin
            mem[ahbm_if.addr[12:2]] <= ahbm_if.wdata;
        end
    end

    assign ahbm_if.ack = ahbm_if.req;
    assign ahbm_if.rdata = (ahbm_if.req && ahbm_if.addr < 8192) ? mem[ahbm_if.addr[12:2]] : 32'b0;
    assign ahbm_if.error = 0;

    always_ff @(posedge HCLK) begin
        if (ahbm_if.req && !ahbm_if.rnw && ahbm_if.addr == 32'h00001000) begin
            $display("SUCCESS: Magic write to 0x1000 with data %08x", ahbm_if.wdata);
            $writememh("mem_out.hex", mem);
            $finish;
        end
    end
endmodule
