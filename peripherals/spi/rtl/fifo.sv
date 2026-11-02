module fifo #(
  parameter int DEPTH = 4
)(
  input  logic clk,
  input  logic nRST,
  input  logic push,
  input  logic pop,
  input  logic [7:0] data_in,
  output logic [7:0] data_out,
  output logic full,
  output logic empty,
  output logic [$clog2(DEPTH+1)-1:0] count
);
  initial begin
    if (DEPTH != 2 && DEPTH != 4 && DEPTH != 8 && DEPTH != 16) $error("Invalid FIFO_DEPTH");
  end

  localparam ADDR_W = $clog2(DEPTH);
  logic [7:0] mem [DEPTH-1:0], mem_next [DEPTH-1:0];
  logic [ADDR_W-1:0] wptr, wptr_next;
  logic [ADDR_W-1:0] rptr, rptr_next;
  logic [$clog2(DEPTH+1)-1:0] cnt, cnt_next;

  always_comb begin
    wptr_next = wptr;
    rptr_next = rptr;
    cnt_next = cnt;
    mem_next = mem;

    if (push && !full && pop && !empty) begin
      mem_next[wptr] = data_in;
      wptr_next = wptr + 1'b1;
      rptr_next = rptr + 1'b1;
    end else if (push && !full) begin
      mem_next[wptr] = data_in;
      wptr_next = wptr + 1'b1;
      cnt_next = cnt + 1'b1;
    end else if (pop && !empty) begin
      rptr_next = rptr + 1'b1;
      cnt_next = cnt - 1'b1;
    end
  end

  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) begin
      wptr <= '0;
      rptr <= '0;
      cnt <= '0;
      for (int i=0; i<DEPTH; i++) mem[i] <= '0;
    end else begin
      wptr <= wptr_next;
      rptr <= rptr_next;
      cnt <= cnt_next;
      mem <= mem_next;
    end
  end

  assign data_out = mem[rptr];
  assign empty = (cnt == 0);
  assign full = (cnt == DEPTH);
  assign count = cnt;
endmodule
