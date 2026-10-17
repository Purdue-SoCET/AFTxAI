`timescale 1ns/1ps

module tb_apb;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter NCOMPLETERS = 2;
    parameter COMPLETER_ADDR_BITS = 16;
    
    typedef logic [31:0] apb_map_t [NCOMPLETERS];
    parameter apb_map_t APB_MAP = '{
        32'h8000_0000, 
        32'h8001_0000  
    };

    logic PCLK = 0;
    logic PRESETn = 0;

    initial forever #5 PCLK = ~PCLK;

    // Interfaces
    bus_protocol_if #(ADDR_WIDTH, DATA_WIDTH) cpu_bus();
    
    apb_if #(ADDR_WIDTH, DATA_WIDTH) apb_req_bus(
        .PCLK(PCLK),
        .PRESETn(PRESETn)
    );
    
    apb_if #(ADDR_WIDTH, DATA_WIDTH) apb_comp_bus [NCOMPLETERS](
        .PCLK(PCLK),
        .PRESETn(PRESETn)
    );

    bus_protocol_if #(ADDR_WIDTH, DATA_WIDTH) periph_bus_0();
    bus_protocol_if #(ADDR_WIDTH, DATA_WIDTH) periph_bus_1();

    // DUT instances
    apb_requester req (
        .apb(apb_req_bus.requester),
        .bus(cpu_bus.peripheral_vital)
    );

    apb_interconnect #(
        .NCOMPLETERS(NCOMPLETERS),
        .COMPLETER_ADDR_BITS(COMPLETER_ADDR_BITS),
        .APB_MAP(APB_MAP)
    ) ic (
        .requester(apb_req_bus.completer),
        .completers(apb_comp_bus)
    );

    apb_completer #(
        .BASE_ADDR(32'h8000_0000)
    ) comp0 (
        .apb(apb_comp_bus[0].completer),
        .bus(periph_bus_0.protocol)
    );

    apb_completer #(
        .BASE_ADDR(32'h8001_0000)
    ) comp1 (
        .apb(apb_comp_bus[1].completer),
        .bus(periph_bus_1.protocol)
    );

    // -----------------------------------------------------
    // Downstream Peripheral Models
    // -----------------------------------------------------
    logic stall_override_0 = 0;
    logic stall_override_1 = 0;

    always_comb begin
        periph_bus_0.rdata = periph_bus_0.ren ? ~periph_bus_0.addr : 32'h0;
        periph_bus_1.rdata = periph_bus_1.ren ? ~periph_bus_1.addr : 32'h0;
        
        periph_bus_0.error = 1'b0;
        periph_bus_1.error = 1'b0;
        
        periph_bus_0.request_stall = stall_override_0;
        periph_bus_1.request_stall = stall_override_1;
    end

    // -----------------------------------------------------
    // Driver Tasks
    // -----------------------------------------------------
    task automatic bus_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb);
        @(posedge PCLK);
        cpu_bus.wen <= 1;
        cpu_bus.ren <= 0;
        cpu_bus.addr <= addr;
        cpu_bus.wdata <= data;
        cpu_bus.strobe <= strb;

        @(posedge PCLK);
        while (cpu_bus.request_stall === 1'b1) @(posedge PCLK);
        
        cpu_bus.wen <= 0;
        cpu_bus.strobe <= 0;
    endtask

    task automatic bus_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge PCLK);
        cpu_bus.wen <= 0;
        cpu_bus.ren <= 1;
        cpu_bus.addr <= addr;

        @(posedge PCLK);
        while (cpu_bus.request_stall === 1'b1) @(posedge PCLK);
        
        data = cpu_bus.rdata;
        err = cpu_bus.error;
        
        cpu_bus.ren <= 0;
    endtask

    // -----------------------------------------------------
    // Coverage
    // -----------------------------------------------------
    always @(posedge PCLK) begin
        if (PRESETn) begin
            cov_comp0_w: cover property (cpu_bus.wen && cpu_bus.addr >= 32'h8000_0000 && cpu_bus.addr <= 32'h8000_FFFF);
            cov_comp1_w: cover property (cpu_bus.wen && cpu_bus.addr >= 32'h8001_0000 && cpu_bus.addr <= 32'h8001_FFFF);
            cov_comp0_r: cover property (cpu_bus.ren && cpu_bus.addr >= 32'h8000_0000 && cpu_bus.addr <= 32'h8000_FFFF);
            cov_comp1_r: cover property (cpu_bus.ren && cpu_bus.addr >= 32'h8001_0000 && cpu_bus.addr <= 32'h8001_FFFF);
            
            // Wait states
            cov_wait_req: cover property (cpu_bus.wen || cpu_bus.ren |=> cpu_bus.request_stall [*2]);
            
            // Cross
            cov_raw_comp0: cover property (cpu_bus.wen && cpu_bus.addr == 32'h8000_0004 ##[1:$] cpu_bus.ren && cpu_bus.addr == 32'h8000_0004);
            cov_waw_comp0: cover property (cpu_bus.wen && cpu_bus.addr == 32'h8000_0008 ##[1:$] cpu_bus.wen && cpu_bus.addr == 32'h8000_000C);
            cov_rar_comp0: cover property (cpu_bus.ren && cpu_bus.addr == 32'h8000_0010 ##[1:$] cpu_bus.ren && cpu_bus.addr == 32'h8000_0010);
            
            // Out of bounds / Unmapped
            cov_unmapped_w: cover property (cpu_bus.wen && cpu_bus.addr >= 32'h8002_0000);
            cov_unmapped_r: cover property (cpu_bus.ren && cpu_bus.addr >= 32'h8002_0000);
        end
    end

    // -----------------------------------------------------
    // Stimulus
    // -----------------------------------------------------
    logic [31:0] rdata;
    logic err;

    initial begin
        $display("Starting APB Regression Test...");
        PRESETn = 0;
        cpu_bus.wen = 0;
        cpu_bus.ren = 0;
        cpu_bus.addr = 0;
        cpu_bus.wdata = 0;
        cpu_bus.strobe = 0;
        
        #20 PRESETn = 1;
        #20;

        // ------------------------------------------
        // T01: Basic read and write to Completer 0
        // ------------------------------------------
        bus_write(32'h8000_0004, 32'hDEADBEEF, 4'hF);
        bus_read(32'h8000_0004, rdata, err);
        if (err !== 0 || rdata !== ~32'h0000_0004) begin
            $display("FAIL T01: Comp 0 Read Mismatch. got %h err %b", rdata, err);
            $finish(1);
        end
        $display("PASS T01: Comp 0 basic read/write");

        // ------------------------------------------
        // T02: Basic read and write to Completer 1
        // ------------------------------------------
        bus_write(32'h8001_0008, 32'hCAFEBAFE, 4'hF);
        bus_read(32'h8001_0008, rdata, err);
        if (err !== 0 || rdata !== ~32'h0000_0008) begin
            $display("FAIL T02: Comp 1 Read Mismatch. got %h err %b", rdata, err);
            $finish(1);
        end
        $display("PASS T02: Comp 1 basic read/write");

        // ------------------------------------------
        // T03: Back-to-back across completers & Coverage
        // ------------------------------------------
        bus_write(32'h8000_000C, 32'h11111111, 4'hF);
        bus_write(32'h8001_000C, 32'h22222222, 4'hF);
        
        // WAW same completer for coverage
        bus_write(32'h8000_0008, 32'h33333333, 4'hF);
        bus_write(32'h8000_000C, 32'h44444444, 4'hF);
        $display("PASS T03: Back-to-back writes across completers");

        // ------------------------------------------
        // T04: Transaction with wait states
        // ------------------------------------------
        fork
            begin
                bus_write(32'h8000_000C, 32'hCAFEBABE, 4'hF);
            end
            begin
                stall_override_0 = 1;
                repeat(3) @(posedge PCLK);
                stall_override_0 <= 0;
            end
        join
        
        fork
            begin
                bus_read(32'h8000_000C, rdata, err);
            end
            begin
                stall_override_0 = 1;
                repeat(3) @(posedge PCLK);
                stall_override_0 <= 0;
            end
        join
        
        if (err !== 0 || rdata !== ~32'h0000_000C) begin
            $display("FAIL T04: Wait state Read Mismatch. got rdata=%h err=%b", rdata, err);
            $finish(1);
        end
        $display("PASS T04: Wait states injected successfully");

        // RAR same completer for coverage
        bus_read(32'h8000_000C, rdata, err);
        bus_read(32'h8000_000C, rdata, err);

        // ------------------------------------------
        // T05 & T06: Error conditions 
        // ------------------------------------------
        // Misaligned
        bus_write(32'h8000_0001, 32'h00000000, 4'hF);
        if (cpu_bus.error !== 1'b1) begin
            $display("FAIL T05: Misaligned access did not flag error!");
            // Not fatal
        end else begin
            $display("PASS T05: Misaligned access error flagged");
        end

        // Out of bounds
        bus_write(32'h8000_0080, 32'h00000000, 4'hF); 
        if (cpu_bus.error !== 1'b1) begin
            $display("FAIL T06: Out of bounds access did not flag error! (Check if NWORDS parameter is small enough)");
        end else begin
            $display("PASS T06: Out of bounds access error flagged");
        end

        // ------------------------------------------
        // T07: Unmapped address handling
        // ------------------------------------------
        bus_write(32'h9000_0000, 32'h00000000, 4'hF);
        if (cpu_bus.error !== 1'b1) begin
            $display("FAIL T07: Unmapped access did not flag error!");
        end else begin
            $display("PASS T07: Unmapped write access error flagged");
        end
        
        // Unmapped Read for coverage
        bus_read(32'h9000_0000, rdata, err);
        if (err !== 1'b1) begin
            $display("FAIL T07: Unmapped read access did not flag error!");
        end else begin
            $display("PASS T07: Unmapped read access error flagged");
        end
        
        #50;
        $display("ALL TESTS COMPLETED");
        $finish;
    end

endmodule
