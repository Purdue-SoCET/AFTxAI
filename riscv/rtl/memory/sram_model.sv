import riscv_pkg::*;

module sram_model #(
  parameter string HEX_FILE = "",
  parameter int DEPTH_BYTES = 256*1024*1024 // 256 MB
)(
  input  logic        clk,
  input  logic        rst_n,
  ahb_if.slave        ahb
);

  localparam int DEPTH_WORDS = DEPTH_BYTES / 4;
  
  // Behavioral SRAM array excluded from synthesis
`ifndef SYNTHESIS
  logic [31:0] mem [];
  
  initial begin
    mem = new[DEPTH_WORDS];
    for (int i = 0; i < DEPTH_WORDS; i++) begin
      mem[i] = 32'd0;
    end
    if (HEX_FILE != "") begin
      $readmemh(HEX_FILE, mem);
    end
  end
  
  // Backdoor task for final-state dump
  task dump_memory(string filename);
    int fd;
    fd = $fopen(filename, "w");
    if (fd) begin
      for (int i = 0; i < DEPTH_WORDS; i++) begin
        $fdisplay(fd, "%08x", mem[i]);
      end
      $fclose(fd);
    end
  endtask

  logic [31:0] addr_reg;
  logic        write_reg;
  logic        active_reg;
  logic [31:0] mem_rdata;

  // Address phase
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      addr_reg <= '0;
      write_reg <= 1'b0;
      active_reg <= 1'b0;
    end else begin
      if (ahb.hready && ahb.htrans[1]) begin
        addr_reg <= ahb.haddr;
        write_reg <= ahb.hwrite;
        active_reg <= 1'b1;
      end else if (ahb.hready) begin
        active_reg <= 1'b0;
      end
    end
  end

  // Data phase
  always_ff @(posedge clk) begin
    if (active_reg) begin
      automatic int word_idx;
      word_idx = addr_reg / 4;
      if (write_reg) begin
        mem[word_idx] <= ahb.hwdata;
      end else begin
        mem_rdata <= mem[word_idx];
        
        // Defense in depth: Check for X or Z on reads
        assert (!$isunknown(mem[word_idx])) else 
          $error("SRAM read at %08x returned X or Z", addr_reg);
      end
    end
  end

  assign ahb.hrdata = mem_rdata;
  assign ahb.hready = 1'b1; // Zero wait state SRAM
  assign ahb.hresp  = 1'b0; // OKAY
`else
  // Empty dummy module for synthesis to satisfy tools if inadvertently included
  assign ahb.hrdata = 32'd0;
  assign ahb.hready = 1'b1;
  assign ahb.hresp = 1'b0;
`endif

endmodule
