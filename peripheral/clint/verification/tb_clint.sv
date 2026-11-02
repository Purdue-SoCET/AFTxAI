`default_nettype none
`timescale 1ns/1ns

module tb_clint;
    parameter NUM_HARTS = 1;
    
    logic CLK;
    logic nRST;
    
    // Interfaces
    bus_protocol_if #(32, 32) busif ();
    clint_if #(NUM_HARTS) clif ();
    
    // DUT
    clint #(NUM_HARTS) dut (
        .CLK(CLK),
        .nRST(nRST),
        .busif(busif.peripheral_vital),
        .clif(clif.clint)
    );
    
    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end
    
    // Bus driver tasks
    task write_reg(input logic [31:0] addr, input logic [31:0] data);
        @(posedge CLK);
        busif.wen <= 1;
        busif.ren <= 0;
        busif.addr <= addr;
        busif.wdata <= data;
        busif.strobe <= 4'hF;
        @(posedge CLK);
        busif.wen <= 0;
        busif.addr <= 32'h0;
        busif.wdata <= 32'h0;
    endtask
    
    task read_reg(input logic [31:0] addr, output logic [31:0] rdata, output logic error);
        @(posedge CLK);
        busif.wen <= 0;
        busif.ren <= 1;
        busif.addr <= addr;
        @(posedge CLK);
        // data and error are available combinationally during the read cycle if combinatorial read
        // But per spec, it says "always_comb begin {busif.error, busif.rdata} = ..."
        // So the read data is immediately available when addr is provided.
        // Wait, always_comb reads busif.addr, so rdata is available combinationally in the same cycle.
        // Let's capture it just before the next clock edge.
        #1;
        rdata = busif.rdata;
        error = busif.error;
        busif.ren <= 0;
    endtask

    // Expected state
    logic [63:0] exp_mtimefull;
    always_ff @(posedge CLK or negedge nRST) begin
        if (!nRST)
            exp_mtimefull <= 0;
        else begin
            if (busif.wen && busif.addr == 32'hBFF8)
                exp_mtimefull <= {exp_mtimefull[63:32], busif.wdata};
            else if (busif.wen && busif.addr == 32'hBFFC)
                exp_mtimefull <= {busif.wdata, exp_mtimefull[31:0]};
            else
                exp_mtimefull <= exp_mtimefull + 1;
        end
    end

    // Assertions for protocol
    always @(posedge CLK) begin
        if (nRST) begin
            assert(busif.request_stall == 1'b0) else $fatal("request_stall must be 0");
            assert(clif.mtime == exp_mtimefull) else $fatal("mtime mismatch: exp %0h, got %0h", exp_mtimefull, clif.mtime);
        end
    end

    // Coverage
    covergroup cg_clint @(posedge CLK);
        cp_addr: coverpoint busif.addr {
            bins mtime     = {32'hBFF8};
            bins mtimeh    = {32'hBFFC};
            bins msip_0    = {32'h0000};
            bins mtimecmp_0 = {32'h4000};
            bins mtimecmph_0= {32'h4004};
            bins invalid   = default;
        }
        cp_wen: coverpoint busif.wen;
        cp_ren: coverpoint busif.ren;
        cross cp_addr, cp_wen;
        cross cp_addr, cp_ren;
        cp_timer_int: coverpoint clif.timer_int[0];
        cp_soft_int: coverpoint clif.soft_int[0];
        cp_clear_timer_int: coverpoint clif.clear_timer_int[0];
        cp_clear_soft_int: coverpoint clif.clear_soft_int[0];
    endgroup

    cg_clint cg = new();

    logic [31:0] rdata;
    logic err;

    initial begin
        // Reset
        nRST = 0;
        busif.wen = 0;
        busif.ren = 0;
        busif.addr = 0;
        busif.wdata = 0;
        busif.strobe = 0;
        #20 nRST = 1;
        
        // TEST 1: Timer increment and read
        #20;
        read_reg(32'hBFF8, rdata, err);
        if (err || rdata !== exp_mtimefull[31:0]) $fatal("Test 1 Failed");
        
        // TEST 2: Timer write
        write_reg(32'hBFF8, 32'h100);
        write_reg(32'hBFFC, 32'h200);
        #10;
        if (exp_mtimefull[63:32] != 32'h200 || exp_mtimefull[31:0] < 32'h100) $fatal("Test 2 Failed");

        // TEST 3: Timer compare interrupt
        write_reg(32'h4000, 32'hFFFFFFFF);
        write_reg(32'h4004, 32'hFFFFFFFF); // Max value, no int
        #20;
        if (clif.timer_int[0]) $fatal("Test 3 Failed: spurious timer int");

        write_reg(32'hBFF8, 32'h500); // Set time to 500
        write_reg(32'hBFFC, 32'h0);
        write_reg(32'h4000, 32'h505); // Set cmp to 505
        write_reg(32'h4004, 32'h0);
        #100; // wait for time to pass 505
        if (!clif.timer_int[0]) $fatal("Test 3 Failed: missing timer int");
        
        // Clear timer interrupt by increasing mtimecmp
        write_reg(32'h4000, 32'h600);
        #10;
        if (clif.timer_int[0]) $fatal("Test 3 Failed: timer int didn't clear");
        
        // TEST 4: MSIP interrupt
        write_reg(32'h0000, 32'h1);
        #10;
        if (!clif.soft_int[0]) $fatal("Test 4 Failed: soft int didn't set");
        write_reg(32'h0000, 32'h0);
        #10;
        if (clif.soft_int[0]) $fatal("Test 4 Failed: soft int didn't clear");

        // TEST 5: Invalid access
        read_reg(32'h1000, rdata, err);
        if (!err || rdata !== 32'hBAD1BAD1) $fatal("Test 5 Failed");

        $display("PASS");
        $finish;
    end
endmodule
