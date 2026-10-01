`timescale 1ns/1ps

module csr_unit (
  input  logic        clk,
  input  logic        rst_n,
  
  input  logic [11:0] csr_addr_i,
  input  logic [31:0] csr_wdata_i,
  input  logic        csr_we_i,
  output logic [31:0] csr_rdata_o,
  
  // Exception handling
  input  logic        exception_i,
  input  logic [31:0] epc_i,
  input  logic [31:0] ecause_i,
  output logic [31:0] trap_vector_o
);

  logic [31:0] mstatus, mepc, mcause, mtvec;

  assign trap_vector_o = mtvec;

  always_comb begin
    case (csr_addr_i)
      12'h300: csr_rdata_o = mstatus;
      12'h305: csr_rdata_o = mtvec;
      12'h341: csr_rdata_o = mepc;
      12'h342: csr_rdata_o = mcause;
      default: csr_rdata_o = 32'b0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mstatus <= 32'b0;
      mtvec   <= 32'b0;
      mepc    <= 32'b0;
      mcause  <= 32'b0;
    end else begin
      if (exception_i) begin
        mepc   <= epc_i;
        mcause <= ecause_i;
      end else if (csr_we_i) begin
        case (csr_addr_i)
          12'h300: mstatus <= csr_wdata_i;
          12'h305: mtvec   <= csr_wdata_i;
          12'h341: mepc    <= csr_wdata_i;
          12'h342: mcause  <= csr_wdata_i;
        endcase
      end
    end
  end

endmodule