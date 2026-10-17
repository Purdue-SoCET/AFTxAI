import spi_types_pkg::*;
module controller (
  input  logic clk,
  input  logic nRST,
  input  spi_cr_t ctrl,
  input  logic [15:0] clkdiv,
  
  // FIFO interfaces
  output logic tx_pop,
  input  logic [7:0] tx_data,
  input  logic tx_empty,
  output logic rx_push,
  output logic [7:0] rx_data,
  input  logic rx_full,
  
  // SPI PHY controls
  output logic phy_sck_en,
  input  logic sck_rise,
  input  logic sck_fall,
  input  logic sck_in_rise,
  input  logic sck_in_fall,
  
  output logic sr_load,
  output logic sr_shift,
  input  logic [7:0] sr_par_out,
  
  output logic sck_out,
  output logic ss_out,
  output logic mode_out,
  
  input  logic ss_in,
  
  output logic transfer_complete
);

  typedef enum logic [2:0] {IDLE, LOAD, TRANS, DONE} state_t;
  state_t state, state_next;
  
  logic [3:0] bit_cnt, bit_cnt_next;
  logic ss_reg, ss_next;
  logic tc_reg, tc_next;
  
  logic tx_pop_next;
  logic rx_push_next;
  logic sr_load_next;
  logic sr_shift_next;
  
  always_comb begin
    logic shift_edge;
    logic sample_edge;

    state_next = state;
    bit_cnt_next = bit_cnt;
    ss_next = ss_reg;
    tc_next = tc_reg;
    
    tx_pop = 1'b0;
    rx_push = 1'b0;
    sr_load = 1'b0;
    sr_shift = 1'b0;
    phy_sck_en = 1'b0;
    
    mode_out = ctrl.mode;
    
    if (ctrl.mode == 1'b1) begin // Controller
      case (state)
        IDLE: begin
          ss_next = 1'b1;
          tc_next = 1'b0;
          if (ctrl.start_transaction && !tx_empty) begin
            state_next = LOAD;
            ss_next = 1'b0;
          end
        end
        LOAD: begin
          tx_pop = 1'b1;
          sr_load = 1'b1;
          bit_cnt_next = '0;
          state_next = TRANS;
        end
        TRANS: begin
          phy_sck_en = 1'b1;
          
          shift_edge = (ctrl.clock_phase == 1'b0) ? (ctrl.clock_polarity ? sck_rise : sck_fall) : (ctrl.clock_polarity ? sck_fall : sck_rise);
          sample_edge = (ctrl.clock_phase == 1'b0) ? (ctrl.clock_polarity ? sck_fall : sck_rise) : (ctrl.clock_polarity ? sck_rise : sck_fall);
          
          if (shift_edge) begin
            sr_shift = 1'b1;
            bit_cnt_next = bit_cnt + 1'b1;
          end
          
          if (sample_edge && bit_cnt == 8) begin
            if (!rx_full) rx_push = 1'b1;
            if (!tx_empty) begin
              state_next = LOAD;
            end else begin
              state_next = DONE;
            end
          end
        end
        DONE: begin
          ss_next = 1'b1;
          tc_next = 1'b1;
          if (!ctrl.start_transaction) state_next = IDLE;
        end
      endcase
      
    end else begin // Target
      // Simplified target mode FSM
      ss_next = 1'b1;
      if (!ss_in) begin
        tc_next = 1'b0;
        shift_edge = (ctrl.clock_phase == 1'b0) ? (ctrl.clock_polarity ? sck_in_rise : sck_in_fall) : (ctrl.clock_polarity ? sck_in_fall : sck_in_rise);
        sample_edge = (ctrl.clock_phase == 1'b0) ? (ctrl.clock_polarity ? sck_in_fall : sck_in_rise) : (ctrl.clock_polarity ? sck_in_rise : sck_in_fall);
        
        if (shift_edge) begin
          sr_shift = 1'b1;
          bit_cnt_next = bit_cnt + 1'b1;
        end
        
        if (sample_edge && bit_cnt == 8) begin
          if (!rx_full) rx_push = 1'b1;
          bit_cnt_next = '0;
          if (!tx_empty) begin
            tx_pop = 1'b1;
            sr_load = 1'b1;
          end
        end
      end else begin
        if (state == TRANS) tc_next = 1'b1;
        bit_cnt_next = '0;
      end
    end
  end
  
  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) begin
      state <= IDLE;
      bit_cnt <= '0;
      ss_reg <= 1'b1;
      tc_reg <= 1'b0;
    end else begin
      state <= state_next;
      bit_cnt <= bit_cnt_next;
      ss_reg <= ss_next;
      tc_reg <= tc_next;
    end
  end

  assign transfer_complete = tc_reg;
  assign ss_out = ss_reg;
  assign rx_data = sr_par_out;
endmodule
