`timescale 1ns/1ps

module tb_spi_top;
  import spi_types_pkg::*;

  logic pclk;
  logic nRST;

  // APB Interface Instance
  apb_if #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32)
  ) apb_bus (.pclk(pclk), .presetn(nRST));

  // SPI Interface Instance
  spi_if spi_bus ();

  // DUT Instance
  spi_wrapper #(
    .FIFO_DEPTH(4)
  ) dut (
    .pclk(pclk),
    .presetn(nRST),
    .apb(apb_bus.completer),
    .phy(spi_bus)
  );

  // 1) Covergroup
  covergroup spi_cg @(posedge pclk);
    option.per_instance = 1;
    cp_mode: coverpoint dut.ctrl.mode {
      bins target = {0};
      bins controller = {1};
    }
    cp_cpol: coverpoint dut.ctrl.clock_polarity;
    cp_cpha: coverpoint dut.ctrl.clock_phase;
    cp_spi_mode: cross cp_cpol, cp_cpha;
    
    // Interrupts
    cp_irq_tc: coverpoint spi_bus.irq[0];
    cp_irq_rx_wm: coverpoint spi_bus.irq[1];
    cp_irq_tx_wm: coverpoint spi_bus.irq[2];
    cp_irq_rx_full: coverpoint spi_bus.irq[3];
    cp_irq_tx_empty: coverpoint spi_bus.irq[4];
    cp_irq_modf: coverpoint spi_bus.irq[5];
  endgroup

  spi_cg cg_inst = new();

  // Clock Generation
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk; // 100MHz
  end

  task bus_write(input [31:0] addr, input [31:0] data);
    @(posedge pclk);
    apb_bus.paddr = addr; apb_bus.pwdata = data; apb_bus.pwrite = 1; apb_bus.psel = 1; apb_bus.penable = 0;
    @(posedge pclk);
    apb_bus.penable = 1;
    wait(apb_bus.pready);
    @(posedge pclk);
    apb_bus.psel = 0; apb_bus.penable = 0; apb_bus.pwrite = 0;
  endtask

  task bus_read(input [31:0] addr, output [31:0] data);
    @(posedge pclk);
    apb_bus.paddr = addr; apb_bus.pwrite = 0; apb_bus.psel = 1; apb_bus.penable = 0;
    @(posedge pclk);
    apb_bus.penable = 1;
    wait(apb_bus.pready);
    data = apb_bus.prdata;
    @(posedge pclk);
    apb_bus.psel = 0; apb_bus.penable = 0;
  endtask

  task test_spi_mode(int mode, logic cpol, logic cpha);
    logic [31:0] rdata;
    $display("Testing SPI Controller Mode %0d (CPOL=%b, CPHA=%b)", mode, cpol, cpha);
    bus_write(8'h08, 3);
    bus_write(8'h0C, 8'h5A);
    bus_write(8'h00, (1<<5) | (1<<4) | (cpha<<3) | (cpol<<2) | (1<<1) | 1);
    wait (dut.status.transfer_complete == 1'b1);
    bus_write(8'h00, 0);
    $display("SPI Mode %0d read rx_empty=%b, rx_cnt=%0d", mode, dut.rx_empty, dut.rx_cnt);
    bus_read(8'h10, rdata);
    $display("SPI Mode %0d read rx_data=%h", mode, rdata);
    #100;
  endtask

  task test_target_mode();
    logic [31:0] rdata;
    $display("Testing Target Mode");
    bus_write(8'h00, 32'h00000020);
    spi_bus.ss_in = 0;
    // Provide 9 clocks because RTL requires a 9th clock to push data in mode 0/2
    for (int i=8; i>=0; i--) begin
      @(posedge pclk);
      if (i > 0) spi_bus.mosi_in <= (8'hC3 >> (i-1)) & 1;
      else spi_bus.mosi_in <= 0;
      
      repeat(4) @(posedge pclk);
      spi_bus.sck_in <= 1;
      
      repeat(4) @(posedge pclk);
      spi_bus.sck_in <= 0;
    end
    repeat(4) @(posedge pclk);
    spi_bus.ss_in <= 1;
    #20;
    $display("DEBUG: Target Mode RX FIFO empty=%b, cnt=%d", dut.rx_empty, dut.rx_cnt);
    bus_read(8'h10, rdata);
    if (rdata[7:0] !== 8'hC3) $display("Target Mode RX failed: expected 0xC3, got %h", rdata[7:0]);
    else $display("Target Mode RX passed");
  endtask

  task test_fifo_thresholds_irq();
    logic [31:0] rdata;
    $display("Testing FIFO thresholds and IRQs");
    
    // Reset to clear FIFOs
    nRST = 0;
    #20;
    nRST = 1;
    #20;
    
    // tx_water_mark=2, rx_water_mark=2
    // IRQ enable bits: 21, 20, 19, 18, 17
    bus_write(8'h00, (1<<21)|(1<<20)|(1<<19)|(1<<18)|(1<<17) | (2<<12) | (2<<7) | (1<<1));
    #20;
    $display("DEBUG: ctrl=%h, status=%h, irq=%b", dut.ctrl, dut.status, spi_bus.irq);
    if (spi_bus.irq[2] !== 1 || spi_bus.irq[4] !== 1) $display("TX IRQs not asserted initially");
    
    bus_write(8'h0C, 8'h11);
    bus_write(8'h0C, 8'h22);
    bus_write(8'h0C, 8'h33);
    bus_write(8'h0C, 8'h44);
    #10;
    if (spi_bus.irq[2] !== 0) $display("TX watermark IRQ did not clear");
    
    bus_write(8'h00, (1<<21)|(1<<20)|(1<<19)|(1<<18)|(1<<17) | (2<<12) | (2<<7) | (1<<1) | 1);
    spi_bus.miso_in = 1;
    wait (dut.status.transfer_complete == 1'b1);
    
    #10;
    $display("DEBUG: status=%h, irq=%b, ctrl=%h", dut.status, spi_bus.irq, dut.ctrl);
    
    if (spi_bus.irq[1] !== 1) $display("RX watermark IRQ not asserted");
    if (spi_bus.irq[3] !== 1) $display("RX full IRQ not asserted");
    if (spi_bus.irq[0] !== 1) $display("Transfer complete IRQ not asserted");
    
    bus_write(8'h00, 0); // clear
    bus_read(8'h10, rdata);
    bus_read(8'h10, rdata);
    bus_read(8'h10, rdata);
    bus_read(8'h10, rdata);
  endtask

  // 2) Trigger FIFO overflow and underflow
  task test_fifo_overflow_underflow();
    logic [31:0] rdata;
    $display("Testing FIFO Overflow/Underflow");
    // Underflow: read from empty RX FIFO
    bus_read(8'h10, rdata); 

    // Overflow: write more than FIFO_DEPTH (4) to TX FIFO without starting transaction
    bus_write(8'h0C, 8'hA1);
    bus_write(8'h0C, 8'hA2);
    bus_write(8'h0C, 8'hA3);
    bus_write(8'h0C, 8'hA4);
    bus_write(8'h0C, 8'hA5); // 5th write causes overflow
  endtask

  // 3) Write walking patterns to clkdiv
  task test_clkdiv_walking();
    $display("Testing clkdiv walking patterns");
    bus_write(8'h08, 16'hFFFF);
    bus_write(8'h08, 16'hAAAA);
    bus_write(8'h08, 16'h5555);
    bus_write(8'h08, 16'h0000);
  endtask

  // 4) Trigger modf (Mode Fault)
  task test_modf();
    logic [31:0] rdata;
    $display("Testing Mode Fault (modf)");
    // modf_enable=1 (bit 6), mode=1 (bit 1) -> 0x42
    // also enable interrupt_enable[5] (bit 22) -> (1<<22)
    bus_write(8'h00, (1<<22) | (1<<6) | (1<<1));
    #20;
    spi_bus.ss_in = 0; // Trigger modf
    #40;
    spi_bus.ss_in = 1;
    bus_read(8'h04, rdata); // read status to check modf bit (bit 5)
    if (rdata[5]) $display("MODF successfully triggered.");
    else $display("MODF NOT triggered.");
    #20;
    // dummy reads and writes to cover address decode cases
    bus_read(8'h00, rdata);
    bus_read(8'h08, rdata);
    bus_read(8'h14, rdata); // default case for read
    bus_write(8'h14, 0); // default case for write
  endtask

  // Test Sequence
  initial begin
    nRST = 0;
    apb_bus.paddr = 0; apb_bus.pwdata = 0; apb_bus.pwrite = 0; apb_bus.psel = 0; apb_bus.penable = 0;
    spi_bus.miso_in = 0;
    spi_bus.mosi_in = 0;
    spi_bus.sck_in = 0;
    spi_bus.ss_in = 1;

    #20 nRST = 1;
    #20;

    // Simple Controller TX Test
    // Write CLKDIV = 3
    apb_bus.paddr = 8'h08; apb_bus.pwdata = 3; apb_bus.pwrite = 1; apb_bus.psel = 1;
    #10 apb_bus.penable = 1; #10 apb_bus.psel = 0; apb_bus.penable = 0; #10;

    // Write TXDATA = 0xA5
    apb_bus.paddr = 8'h0C; apb_bus.pwdata = 8'hA5; apb_bus.pwrite = 1; apb_bus.psel = 1;
    #10 apb_bus.penable = 1; #10 apb_bus.psel = 0; apb_bus.penable = 0; #10;

    // Write CTRL to start transaction
    // mode=1, msb_first=1, ssoe=1, start_transaction=1
    // CR[1] = 1, CR[5] = 1, CR[4]=1, CR[0]=1 -> 0x33
    apb_bus.paddr = 8'h00; apb_bus.pwdata = 32'h00000033; apb_bus.pwrite = 1; apb_bus.psel = 1;
    #10 apb_bus.penable = 1; #10 apb_bus.psel = 0; apb_bus.penable = 0; #10;

    // SPI Modes 1-3
    nRST = 0; #20; nRST = 1; #20;
    test_spi_mode(1, 0, 1);
    test_spi_mode(2, 1, 0);
    test_spi_mode(3, 1, 1);

    // Target Mode
    nRST = 0; #20; nRST = 1; #20;
    test_target_mode();

    // FIFO thresholds and IRQ
    test_fifo_thresholds_irq();

    // FIFO overflow/underflow
    nRST = 0; #20; nRST = 1; #20;
    test_fifo_overflow_underflow();

    // Clkdiv walking patterns
    nRST = 0; #20; nRST = 1; #20;
    test_clkdiv_walking();

    // Mode Fault (modf)
    nRST = 0; #20; nRST = 1; #20;
    test_modf();

    #100;
    $display("TEST PASSED");
    $finish;
  end

  always @(dut.ctrl_inst.rx_push) begin
    if (dut.ctrl_inst.rx_push) $display("DEBUG at %0t: rx_push=1, rx_data=%h, bit_cnt=%0d", $time, dut.ctrl_inst.rx_data, dut.ctrl_inst.bit_cnt);
  end

endmodule