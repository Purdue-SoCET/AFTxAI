module edge_detect_spi (
  input  logic clk,
  input  logic nRST,
  input  logic sig_in,
  output logic rise,
  output logic fall
);
  logic sig_d, sig_d_next;

  always_comb begin
    sig_d_next = sig_in;
    rise = sig_in & ~sig_d;
    fall = ~sig_in & sig_d;
  end

  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) sig_d <= 1'b0;
    else sig_d <= sig_d_next;
  end
endmodule
