module flex_sr_spi (
  input  logic clk,
  input  logic nRST,
  input  logic load,
  input  logic shift_en,
  input  logic [7:0] par_in,
  input  logic ser_in,
  input  logic msb_first,
  output logic [7:0] par_out,
  output logic ser_out
);
  logic [7:0] sr, sr_next;

  always_comb begin
    sr_next = sr;
    if (load) begin
      sr_next = par_in;
    end else if (shift_en) begin
      if (msb_first) begin
        sr_next = {sr[6:0], ser_in};
      end else begin
        sr_next = {ser_in, sr[7:1]};
      end
    end
    par_out = sr;
    ser_out = msb_first ? sr[7] : sr[0];
  end

  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) sr <= '0;
    else sr <= sr_next;
  end
endmodule
