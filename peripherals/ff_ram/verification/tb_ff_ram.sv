`timescale 1ns/1ps

module tb_ff_ram;

    logic clk;
    logic rst_n;

    bus_protocol_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) bus ();

    bus_protocol_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) bus_rom ();

    bus_protocol_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) bus_lat ();

    // Instantiate standard RAM
    ff_ram #(
        .NBYTES(16),
        .ROM(0),
        .LATENCY(0),
        .INIT_FILE("peripherals/ff_ram/verification/meminit.bin"),
        .DUMP_FILE("peripherals/ff_ram/verification/memsim.hex"),
        .DATA_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .bus(bus.peripheral_vital)
    );

    // Instantiate ROM
    ff_ram #(
        .NBYTES(16),
        .ROM(1),
        .LATENCY(0),
        .INIT_FILE("peripherals/ff_ram/verification/meminit.bin"),
        .DUMP_FILE("peripherals/ff_ram/verification/memsim_rom.hex"),
        .DATA_WIDTH(32)
    ) dut_rom (
        .clk(clk),
        .rst_n(rst_n),
        .bus(bus_rom.peripheral_vital)
    );

    // Instantiate Latency RAM
    ff_ram #(
        .NBYTES(16),
        .ROM(0),
        .LATENCY(2),
        .INIT_FILE("peripherals/ff_ram/verification/meminit.bin"),
        .DUMP_FILE("peripherals/ff_ram/verification/memsim_lat.hex"),
        .DATA_WIDTH(32)
    ) dut_lat (
        .clk(clk),
        .rst_n(rst_n),
        .bus(bus_lat.peripheral_vital)
    );

    always #5 clk = ~clk;

    task do_write(
        virtual bus_protocol_if b,
        input logic [31:0] waddr,
        input logic [31:0] wdata,
        input logic [3:0] wstrb,
        output logic err
    );
        @(posedge clk);
        #1;
        b.wen = 1'b1;
        b.ren = 1'b0;
        b.addr = waddr;
        b.wdata = wdata;
        b.strobe = wstrb;

        while (1) begin
            @(posedge clk);
            if (!b.request_stall) break;
        end
        err = b.error;
        
        #1;
        b.wen = 1'b0;
    endtask

    task do_read(
        virtual bus_protocol_if b,
        input logic [31:0] raddr,
        output logic [31:0] rdata,
        output logic err
    );
        @(posedge clk);
        #1;
        b.ren = 1'b1;
        b.wen = 1'b0;
        b.addr = raddr;

        while (1) begin
            @(posedge clk);
            if (!b.request_stall) break;
        end
        rdata = b.rdata;
        err = b.error;

        #1;
        b.ren = 1'b0;
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        bus.wen = 0;
        bus.ren = 0;
        bus.addr = 0;
        bus.wdata = 0;
        bus.strobe = 0;

        bus_rom.wen = 0; bus_rom.ren = 0; bus_rom.addr = 0; bus_rom.wdata = 0; bus_rom.strobe = 0;
        bus_lat.wen = 0; bus_lat.ren = 0; bus_lat.addr = 0; bus_lat.wdata = 0; bus_lat.strobe = 0;
        
        #20 rst_n = 1;
        #10;

        // Test 1: Read initial memory from standard RAM
        begin
            logic [31:0] rdata;
            logic err;
            do_read(bus, 32'h0, rdata, err);
            if (rdata !== 32'h1 || err) $display("FAIL: Read 0, got %h, err %b", rdata, err);
            else $display("PASS: Read 0 = %h", rdata);

            do_read(bus, 32'h4, rdata, err);
            if (rdata !== 32'h2 || err) $display("FAIL: Read 4, got %h, err %b", rdata, err);
            else $display("PASS: Read 4 = %h", rdata);
        end

        // Test 2: Write memory
        begin
            logic [31:0] rdata;
            logic err;
            do_write(bus, 32'h8, 32'hDEADBEEF, 4'hF, err);
            if (err) $display("FAIL: Write 8 error");
            else $display("PASS: Write 8 success");

            do_read(bus, 32'h8, rdata, err);
            if (rdata !== 32'hDEADBEEF || err) $display("FAIL: Read 8, got %h, err %b", rdata, err);
            else $display("PASS: Read 8 = %h", rdata);
        end

        // Test 3: Write ROM (should fail)
        begin
            logic err;
            do_write(bus_rom, 32'h0, 32'hBADC0FE, 4'hF, err);
            if (!err) $display("FAIL: Write ROM did not error!");
            else $display("PASS: Write ROM produced error correctly.");
        end

        // Test 4: Latency RAM read
        begin
            logic [31:0] rdata;
            logic err;
            do_read(bus_lat, 32'h0, rdata, err);
            if (rdata !== 32'h1 || err) $display("FAIL: Latency Read 0, got %h", rdata);
            else $display("PASS: Latency Read 0 = %h", rdata);
        end

        // Test 5: Out of bounds
        begin
            logic err;
            logic [31:0] rdata;
            do_read(bus, 32'h100, rdata, err);
            if (!err) $display("FAIL: OOB read did not error");
            else $display("PASS: OOB read produced error");
        end

        #20;
        $display("Simulation complete.");
        $finish;
    end

endmodule
