`timescale 1ns/1ps

module l1_cache #(
    parameter int CACHE_SIZE = 1024,
    parameter int BLOCK_SIZE = 4,
    parameter int ASSOCIATIVITY = 1,
    parameter bit CACHE_TYPE = 1 // 0 for iCache (Read-Only), 1 for dCache (Write-Back/Write-Allocate)
) (
    input  logic HCLK,
    input  logic nRST,

    // CPU to Cache Interface
    cpu_cache_if.cache cpu_if,

    // Cache to Bus Controller Interface
    cache_bus_if.cache bus_if
);

    // TODO: Implement Cache Control FSM
    // TODO: Implement Cache Tag and Data arrays
    // TODO: Implement True LRU for 2-way associative configuration
    // TODO: Implement Write-Back/Write-Allocate for dCache, Read-Only for iCache

    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            cpu_if.ready <= 1'b0;
            cpu_if.rdata <= 32'b0;
            cpu_if.error <= 1'b0;
            
            bus_if.req <= 1'b0;
            bus_if.addr <= 32'b0;
            bus_if.rnw <= 1'b0;
            bus_if.wdata <= 32'b0;
        end else begin
            // Stub logic
        end
    end

endmodule
