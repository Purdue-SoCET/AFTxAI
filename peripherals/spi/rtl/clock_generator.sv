module clock_generator (
  input  logic clk,
  input  logic nRST,
  input  logic en,
  input  logic [15:0] clkdiv,
  output logic sclk_out,
  output logic sclk_rise,
  output logic sclk_fall
);
  logic [15:0] cnt, cnt_next;
  logic sclk_reg, sclk_next;
  logic rise, fall;

  always_comb begin
    cnt_next = cnt;
    sclk_next = sclk_reg;
    rise = 1'b0;
    fall = 1'b0;

    if (en) begin
      if (cnt == clkdiv) begin
        cnt_next = '0;
        sclk_next = ~sclk_reg;
        if (sclk_reg) fall = 1'b1;
        else rise = 1'b1;
      end else begin
        cnt_next = cnt + 1'b1;
      end
    end else begin
      cnt_next = '0;
      sclk_next = 1'b0; 
    end
  end

  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) begin
      cnt <= '0;
      sclk_reg <= 1'b0;
    end else begin
      cnt <= cnt_next;
      sclk_reg <= sclk_next;
    end
  end

  assign sclk_out = sclk_reg;
  assign sclk_rise = rise;
  assign sclk_fall = fall;
endmodule
