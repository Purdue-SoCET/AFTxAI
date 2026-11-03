module tb_ahb_top;

    logic HCLK;
    logic HRESETn;

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    // Reset generation
    initial begin
        HRESETn = 0;
        #20 HRESETn = 1;
    end

    // Interfaces
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) gen_manager_1_if();
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) gen_manager_2_if();
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) gen_sub_1_if();
    bus_protocol_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) gen_sub_2_if();
    
    // Interconnect arrays
    ahb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) ahb_manager_if[2](HCLK, HRESETn);
    ahb_if #( .ADDR_WIDTH(32), .DATA_WIDTH(32) ) ahb_sub_if[2](HCLK, HRESETn);

    // AHB Manager 1
    ahb_manager #(
        .HDATA_WIDTH(32)
    ) mgr1 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .generic_if(gen_manager_1_if.peripheral_vital),
        .ahb(ahb_manager_if[0].manager)
    );

    // AHB Manager 2
    ahb_manager #(
        .HDATA_WIDTH(32)
    ) mgr2 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .generic_if(gen_manager_2_if.peripheral_vital),
        .ahb(ahb_manager_if[1].manager)
    );

    // Interconnect
    localparam logic [31:0] ahb_map [2] = '{32'h0000_0000, 32'h1000_0000};
    ahb_interconnect #(
        .NMANAGERS(2),
        .NSUBORDINATES(2),
        .AHB_MAP(ahb_map),
        .HDATA_WIDTH(32)
    ) ic0 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .manager_ports(ahb_manager_if),
        .subordinate_ports(ahb_sub_if)
    );

    // AHB Subordinate 1
    ahb_subordinate #(
        .BASE_ADDR(32'h0000_0000),
        .NUM_WORDS(1024),
        .HDATA_WIDTH(32)
    ) sub1 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .ahb(ahb_sub_if[0].subordinate),
        .generic_if(gen_sub_1_if.protocol)
    );

    // AHB Subordinate 2
    ahb_subordinate #(
        .BASE_ADDR(32'h1000_0000),
        .NUM_WORDS(1024),
        .HDATA_WIDTH(32)
    ) sub2 (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .ahb(ahb_sub_if[1].subordinate),
        .generic_if(gen_sub_2_if.protocol)
    );
    // Simple memory model for subordinates
    logic [31:0] mem1 [1024];
    logic [31:0] mem2 [1024];

    always_ff @(posedge HCLK) begin
        if (gen_sub_1_if.wen) mem1[gen_sub_1_if.addr[11:2]] <= gen_sub_1_if.wdata;
        gen_sub_1_if.rdata <= mem1[gen_sub_1_if.addr[11:2]];
        gen_sub_1_if.request_stall <= 1'b0;
        gen_sub_1_if.error <= 1'b0;

        if (gen_sub_2_if.wen) mem2[gen_sub_2_if.addr[11:2]] <= gen_sub_2_if.wdata;
        gen_sub_2_if.rdata <= mem2[gen_sub_2_if.addr[11:2]];
        gen_sub_2_if.request_stall <= 1'b0;
        gen_sub_2_if.error <= 1'b0;
    end

    // Test stimulus
    initial begin
        // Initialize managers
        gen_manager_1_if.wen = 0;
        gen_manager_1_if.ren = 0;
        gen_manager_1_if.addr = 0;
        gen_manager_1_if.wdata = 0;
        gen_manager_1_if.strobe = 0;

        gen_manager_2_if.wen = 0;
        gen_manager_2_if.ren = 0;
        gen_manager_2_if.addr = 0;
        gen_manager_2_if.wdata = 0;
        gen_manager_2_if.strobe = 0;

        @(posedge HRESETn);
        @(posedge HCLK);

        // Manager 1 writes to sub 1
        gen_manager_1_if.wen = 1;
        gen_manager_1_if.addr = 32'h0000_0004;
        gen_manager_1_if.wdata = 32'hDEADBEEF;
        gen_manager_1_if.strobe = 4'hF;
        @(posedge HCLK);
        while (gen_manager_1_if.request_stall) @(posedge HCLK);
        gen_manager_1_if.wen = 0;
        
        // Wait one cycle for data phase to complete
        @(posedge HCLK);

        // Manager 2 writes to sub 2
        gen_manager_2_if.wen = 1;
        gen_manager_2_if.addr = 32'h1000_0008;
        gen_manager_2_if.wdata = 32'hCAFEBABE;
        gen_manager_2_if.strobe = 4'hF;
        @(posedge HCLK);
        while (gen_manager_2_if.request_stall) @(posedge HCLK);
        gen_manager_2_if.wen = 0;
        
        @(posedge HCLK);
        
        // Manager 1 reads from sub 1
        gen_manager_1_if.ren = 1;
        gen_manager_1_if.addr = 32'h0000_0004;
        @(posedge HCLK);
        while (gen_manager_1_if.request_stall) @(posedge HCLK);
        gen_manager_1_if.ren = 0;
        if (gen_manager_1_if.rdata !== 32'hDEADBEEF) $error("M1 read failed! Got %h", gen_manager_1_if.rdata);
        else $display("M1 read success!");
        
        @(posedge HCLK);

        // Manager 2 reads from sub 2
        gen_manager_2_if.ren = 1;
        gen_manager_2_if.addr = 32'h1000_0008;
        @(posedge HCLK);
        while (gen_manager_2_if.request_stall) @(posedge HCLK);
        gen_manager_2_if.ren = 0;
        if (gen_manager_2_if.rdata !== 32'hCAFEBABE) $error("M2 read failed! Got %h", gen_manager_2_if.rdata);
        else $display("M2 read success!");

        #100;
        $display("Simulation complete.");
        $finish;
    end
endmodule
