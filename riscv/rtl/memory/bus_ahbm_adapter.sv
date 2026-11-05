`timescale 1ns/1ps

module bus_ahbm_adapter (
    bus_ahbm_if.subordinate core_bus,
    bus_protocol_if.protocol generic_bus
);

    assign generic_bus.wen = core_bus.req & ~core_bus.rnw;
    assign generic_bus.ren = core_bus.req & core_bus.rnw;
    assign generic_bus.addr = core_bus.addr;
    assign generic_bus.wdata = core_bus.wdata;
    
    // Convert 3-bit size to byte strobe
    // 000: BYTE, 001: HALFWORD, 010: WORD
    always_comb begin
        if (core_bus.size == 3'b000) begin
            generic_bus.strobe = 4'b0001 << core_bus.addr[1:0];
        end else if (core_bus.size == 3'b001) begin
            generic_bus.strobe = 4'b0011 << {core_bus.addr[1], 1'b0};
        end else begin
            generic_bus.strobe = 4'b1111;
        end
    end

    // The core gets ack when the generic bus finishes the transfer (stops stalling)
    assign core_bus.ack = core_bus.req & ~generic_bus.request_stall;
    assign core_bus.rdata = generic_bus.rdata;
    assign core_bus.error = generic_bus.error;

    // Hint signals
    assign generic_bus.is_burst = 1'b0;
    assign generic_bus.burst_type = 2'b0;
    assign generic_bus.burst_length = '0;
    assign generic_bus.secure_transfer = 1'b0;

endmodule
