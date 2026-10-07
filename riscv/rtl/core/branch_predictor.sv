module branch_predictor #(
  parameter int BTB_ENTRIES = 16
)(
  input  logic        clk,
  input  logic        rst_n,
  
  // IF Predict Interface
  input  logic [31:0] fetch_pc,
  output logic        pred_taken,
  output logic [31:0] pred_target,
  
  // ID/EX Update Interface
  input  logic        ex_valid,
  input  logic [31:0] ex_pc,
  input  logic        ex_is_branch,
  input  logic        ex_is_jump,
  input  logic        ex_actually_taken,
  input  logic [31:0] ex_target
);

  localparam int IDX_BITS = $clog2(BTB_ENTRIES);
  
  // BTB and Predictor Arrays
  logic [31:0] btb_target [BTB_ENTRIES-1:0];
  logic [31-IDX_BITS-2:0] btb_tag [BTB_ENTRIES-1:0];
  logic        btb_valid [BTB_ENTRIES-1:0];
  
  // 2-bit saturating counters
  // 00: Strongly Not Taken, 01: Weakly Not Taken
  // 10: Weakly Taken,       11: Strongly Taken
  logic [1:0] bht [BTB_ENTRIES-1:0];

  // Fetch Logic
  logic [IDX_BITS-1:0] fetch_idx;
  logic [31-IDX_BITS-2:0] fetch_tag;
  
  assign fetch_idx = fetch_pc[IDX_BITS+1:2];
  assign fetch_tag = fetch_pc[31:IDX_BITS+2];
  
  always_comb begin
    pred_taken = 1'b0;
    pred_target = 32'd0;
    
    if (btb_valid[fetch_idx] && (btb_tag[fetch_idx] == fetch_tag)) begin
      pred_target = btb_target[fetch_idx];
      // Branch is taken if MSB of saturating counter is 1
      pred_taken = bht[fetch_idx][1];
    end
  end
  
  // Update Logic
  logic [IDX_BITS-1:0] ex_idx;
  logic [31-IDX_BITS-2:0] ex_tag;
  logic [1:0] current_bht;
  
  assign ex_idx = ex_pc[IDX_BITS+1:2];
  assign ex_tag = ex_pc[31:IDX_BITS+2];
  assign current_bht = bht[ex_idx];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < BTB_ENTRIES; i++) begin
        btb_valid[i] <= 1'b0;
        btb_tag[i]   <= '0;
        btb_target[i]<= '0;
        bht[i]       <= 2'b01; // Initialize to Weakly Not Taken
      end
    end else if (ex_valid && (ex_is_branch || ex_is_jump)) begin
      // Update BTB
      btb_valid[ex_idx] <= 1'b1;
      btb_tag[ex_idx]   <= ex_tag;
      btb_target[ex_idx]<= ex_target;
      
      // Update BHT only for conditional branches (jumps are always strongly taken)
      if (ex_is_branch) begin
        case (current_bht)
          2'b00: bht[ex_idx] <= ex_actually_taken ? 2'b01 : 2'b00;
          2'b01: bht[ex_idx] <= ex_actually_taken ? 2'b10 : 2'b00;
          2'b10: bht[ex_idx] <= ex_actually_taken ? 2'b11 : 2'b01;
          2'b11: bht[ex_idx] <= ex_actually_taken ? 2'b11 : 2'b10;
        endcase
      end else begin
        bht[ex_idx] <= 2'b11; // Jumps are Strongly Taken
      end
    end
  end

endmodule
