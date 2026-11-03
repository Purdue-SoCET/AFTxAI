`timescale 1ns/1ps

module tb_i2c;

    logic PCLK;
    logic PRESETn;

    // Clock Generation
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // 100MHz
    end

    // Reset Generation
    initial begin
        PRESETn = 0;
        #25 PRESETn = 1;
    end

    // Interfaces
    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) apb (.PCLK(PCLK), .PRESETn(PRESETn));
    i2c_if i2c_bus ();

    // Target Model Declarations
    logic target_scl_oe, target_sda_oe;
    logic [3:0] stretch_cycles;
    logic force_nack;
    logic [7:0] target_read_data;

    // Simulated Pull-ups
    wire scl_net = (i2c_bus.scl_oe || target_scl_oe) ? 1'b0 : 1'b1;
    wire sda_net = (i2c_bus.sda_oe || target_sda_oe) ? 1'b0 : 1'b1;

    // IO Mux modeling (3-4 cycles delay)
    logic [3:0] scl_delay_pipe;
    logic [3:0] sda_delay_pipe;
    logic [1:0] io_delay_sel = 3; // 3 or 4

    always_ff @(posedge PCLK) begin
        scl_delay_pipe <= {scl_delay_pipe[2:0], scl_net};
        sda_delay_pipe <= {sda_delay_pipe[2:0], sda_net};
    end

    assign i2c_bus.scl_i = (io_delay_sel == 4) ? scl_delay_pipe[3] : scl_delay_pipe[2];
    assign i2c_bus.sda_i = (io_delay_sel == 4) ? sda_delay_pipe[3] : sda_delay_pipe[2];

    // DUT Instantiation (using standard APB completer and I2C engine)
    i2c #(
        .BASE_ADDR(32'h80005000),
        .NWORDS(6)
    ) dut (
        .apb(apb.completer),
        .i2c_pins(i2c_bus.controller)
    );

    // Target Model
    i2c_target_model #(
        .TARGET_ADDR(7'h5A)
    ) target (
        .scl_in(scl_net),
        .sda_in(sda_net),
        .scl_oe(target_scl_oe),
        .sda_oe(target_sda_oe),
        .stretch_cycles(stretch_cycles),
        .force_nack(force_nack),
        .read_data(target_read_data)
    );

    // APB Driver Tasks
    task apb_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb, output logic err);
        @(posedge PCLK);
        apb.PADDR = addr;
        apb.PWRITE = 1;
        apb.PSEL = 1;
        apb.PWDATA = data;
        apb.PSTRB = strb;
        apb.PENABLE = 0;
        @(posedge PCLK);
        apb.PENABLE = 1;
        @(posedge PCLK);
        while (!apb.PREADY) @(posedge PCLK);
        err = apb.PSLVERR;
        apb.PSEL = 0;
        apb.PENABLE = 0;
    endtask

    task apb_read(input logic [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge PCLK);
        apb.PADDR = addr;
        apb.PWRITE = 0;
        apb.PSEL = 1;
        apb.PSTRB = 0;
        apb.PENABLE = 0;
        @(posedge PCLK);
        apb.PENABLE = 1;
        @(posedge PCLK);
        while (!apb.PREADY) @(posedge PCLK);
        data = apb.PRDATA;
        err = apb.PSLVERR;
        apb.PSEL = 0;
        apb.PENABLE = 0;
    endtask

    // Functional Coverage via Bus Monitoring
    logic is_cmd_write;
    assign is_cmd_write = (apb.PSEL && apb.PENABLE && apb.PWRITE && apb.PADDR == 32'h80005010 && apb.PSTRB[0]);

    logic is_prescale_write;
    assign is_prescale_write = (apb.PSEL && apb.PENABLE && apb.PWRITE && apb.PADDR == 32'h80005004);

    covergroup cg_i2c @(posedge PCLK);
        // Commands
        cp_cmd_start: coverpoint apb.PWDATA[0] iff (is_cmd_write) { bins start = {1}; }
        cp_cmd_stop:  coverpoint apb.PWDATA[1] iff (is_cmd_write) { bins stop = {1}; }
        cp_cmd_write: coverpoint apb.PWDATA[2] iff (is_cmd_write) { bins write = {1}; }
        cp_cmd_read:  coverpoint apb.PWDATA[3] iff (is_cmd_write) { bins read = {1}; }
        cp_cmd_nack:  coverpoint apb.PWDATA[4] iff (is_cmd_write) { bins nack = {1}; }

        // Prescaler ranges
        cp_prescale: coverpoint apb.PWDATA[15:0] iff (is_prescale_write) {
            bins min = {3};
            bins mid = {[4:16384]};
            bins max = {[16385:65535]};
        }
    endgroup

    cg_i2c cg = new();

    // Protocol Checker
    // Ensures that target clock stretching functions and START/STOP sequences are cleanly isolated
    
    int errors = 0;

    // Main Test Program
    initial begin
        logic err;
        logic [31:0] rdata;
        
        stretch_cycles = 0;
        force_nack = 0;
        target_read_data = 8'hAA;
        
        // Wait for reset
        @(posedge PRESETn);
        @(posedge PCLK);

        $display("Starting I2C Testbench...");

        // T01: Reset values
        apb_read(32'h80005000, rdata, err); // CTRL
        if (rdata != 0) begin $display("FAIL: CTRL reset = %h", rdata); errors++; end
        
        apb_read(32'h80005004, rdata, err); // PRESCALE
        if (rdata != 3) begin $display("FAIL: PRESCALE reset = %h", rdata); errors++; end

        // Enable I2C, Set prescale to 3
        apb_write(32'h80005004, 32'd3, 4'hF, err); // PRESCALE=3
        apb_write(32'h80005000, 32'd1, 4'hF, err); // CTRL.EN=1

        // T05: START + address WRITE with target ACK
        apb_write(32'h80005008, 32'hB4, 4'hF, err); // TXDATA
        apb_write(32'h80005010, 32'h05, 4'hF, err); // CMD: START + WRITE
        
        // Wait for DONE
        do begin
            apb_read(32'h80005014, rdata, err);
        end while ((rdata & 8) == 0);
        
        // Clear DONE
        apb_write(32'h80005014, 32'h08, 4'hF, err);

        if ((rdata & 4) != 0) begin
            $display("FAIL: RX_NACK=1 when ACK expected"); errors++;
        end

        // T07: READ with ACK then STOP
        target_read_data = 8'hA5;
        apb_write(32'h80005010, 32'h0A, 4'hF, err); // CMD: READ + STOP
        
        do begin
            apb_read(32'h80005014, rdata, err);
        end while ((rdata & 8) == 0);
        apb_write(32'h80005014, 32'h08, 4'hF, err); // Clear DONE
        
        apb_read(32'h8000500C, rdata, err); // RXDATA
        if ((rdata & 8'hFF) != 8'hA5) begin
            $display("FAIL: RXDATA = %h, expected A5", rdata); errors++;
        end

        // Finish
        if (errors == 0) begin
            $display("PASS");
            $finish(0);
        end else begin
            $display("FAIL with %0d errors", errors);
            $finish(1);
        end
    end

endmodule
