import spi_types_pkg::*;

module spi_wrapper #(
  parameter int FIFO_DEPTH = 4
)(
  apb_if.completer apb,
  spi_if phy
);
  logic clk;
  logic nRST;
  assign clk = apb.PCLK;
  assign nRST = apb.PRESETn;
  
  spi_cr_t ctrl, ctrl_next;
  spi_status_t status, status_next;
  logic [15:0] clkdiv, clkdiv_next;
  
  logic tx_push, tx_pop;
  logic [7:0] tx_data_in;
  logic [7:0] tx_data_out;
  logic tx_full, tx_empty;
  logic [$clog2(FIFO_DEPTH+1)-1:0] tx_cnt;
  
  logic rx_push, rx_pop;
  logic [7:0] rx_data_in;
  logic [7:0] rx_data_out;
  logic rx_full, rx_empty;
  logic [$clog2(FIFO_DEPTH+1)-1:0] rx_cnt;

  fifo #(FIFO_DEPTH) tx_fifo (.clk(clk), .nRST(nRST), .push(tx_push), .pop(tx_pop), .data_in(tx_data_in), .data_out(tx_data_out), .full(tx_full), .empty(tx_empty), .count(tx_cnt));
  fifo #(FIFO_DEPTH) rx_fifo (.clk(clk), .nRST(nRST), .push(rx_push), .pop(rx_pop), .data_in(rx_data_in), .data_out(rx_data_out), .full(rx_full), .empty(rx_empty), .count(rx_cnt));

  logic sr_load, sr_shift, ser_out;
  logic [7:0] sr_par_out;
  flex_sr_spi shift_reg (
    .clk(clk), .nRST(nRST), .load(sr_load), .shift_en(sr_shift),
    .par_in(tx_data_out), .ser_in(ctrl.mode ? phy.miso_in : phy.mosi_in),
    .msb_first(ctrl.msb_first), .par_out(sr_par_out), .ser_out(ser_out)
  );

  logic sclk_gen_out, sclk_rise, sclk_fall;
  logic phy_sck_en;
  clock_generator clk_gen (.clk(clk), .nRST(nRST), .en(phy_sck_en), .clkdiv(clkdiv), .sclk_out(sclk_gen_out), .sclk_rise(sclk_rise), .sclk_fall(sclk_fall));

  logic sck_in_rise, sck_in_fall;
  edge_detect_spi sck_in_det (.clk(clk), .nRST(nRST), .sig_in(phy.sck_in), .rise(sck_in_rise), .fall(sck_in_fall));

  logic sck_out_reg, sck_out_next;
  logic mosi_out_reg, mosi_out_next;
  
  always_comb begin
    sck_out_next = sck_out_reg;
    mosi_out_next = mosi_out_reg;
    if (ctrl.mode == 1'b1) begin // Controller
      if (!phy_sck_en) sck_out_next = ctrl.clock_polarity;
      else sck_out_next = ctrl.clock_polarity ? ~sclk_gen_out : sclk_gen_out;
      
      mosi_out_next = ser_out;
    end else begin
      phy.miso_out = ser_out;
    end
  end
  
  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) begin
      sck_out_reg <= 1'b0;
      mosi_out_reg <= 1'b0;
    end else begin
      sck_out_reg <= sck_out_next;
      mosi_out_reg <= mosi_out_next;
    end
  end
  
  assign phy.sck_out = sck_out_reg;
  assign phy.mosi_out = mosi_out_reg;
  assign phy.miso_out = ser_out;

  logic tc;
  controller ctrl_inst (
    .clk(clk), .nRST(nRST), .ctrl(ctrl), .clkdiv(clkdiv),
    .tx_pop(tx_pop), .tx_data(tx_data_out), .tx_empty(tx_empty),
    .rx_push(rx_push), .rx_data(rx_data_in), .rx_full(rx_full),
    .phy_sck_en(phy_sck_en), .sck_rise(sclk_rise), .sck_fall(sclk_fall),
    .sck_in_rise(sck_in_rise), .sck_in_fall(sck_in_fall),
    .sr_load(sr_load), .sr_shift(sr_shift), .sr_par_out(sr_par_out),
    .sck_out(), .ss_out(phy.ss_out), .mode_out(phy.mode), .ss_in(phy.ss_in),
    .transfer_complete(tc)
  );
  
  assign rx_data_in = sr_par_out;

  interrupt_control irq_ctrl (.ctrl(ctrl), .status(status), .irq(phy.irq));
  
  always_comb begin
    status_next = status;
    status_next.tx_buffer_cnt = tx_cnt;
    status_next.rx_buffer_cnt = rx_cnt;
    status_next.tx_buffer_empty = tx_empty;
    status_next.rx_buffer_full = rx_full;
    status_next.tx_water_mark_hit = (tx_cnt <= ctrl.tx_water_mark);
    status_next.rx_water_mark_hit = (rx_cnt >= ctrl.rx_water_mark);
    status_next.transfer_complete = tc;
  end
  
  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) status <= '0;
    else status <= status_next;
  end

  // APB Completer Access Logic
  assign apb.PREADY = 1'b1; // Zero wait-state

  always_comb begin
    ctrl_next = ctrl;
    clkdiv_next = clkdiv;
    tx_push = 1'b0;
    rx_pop = 1'b0;
    tx_data_in = '0;
    apb.PRDATA = '0;
    apb.PSLVERR = 1'b0;
    
    // Read operations
    if (apb.PSEL && !apb.PWRITE) begin
        case (apb.PADDR[7:0])
          8'h00: apb.PRDATA = ctrl;
          8'h04: apb.PRDATA = status;
          8'h08: apb.PRDATA = {16'h0, clkdiv};
          8'h10: apb.PRDATA = {24'h0, rx_data_out};
          default: apb.PRDATA = '0;
        endcase
        if (apb.PENABLE) begin
          if (apb.PADDR[7:0] == 8'h10 && !rx_empty) rx_pop = 1'b1;
        end
    end
    
    // Write operations
    if (apb.PSEL && apb.PENABLE && apb.PWRITE) begin
        case (apb.PADDR[7:0])
          8'h00: ctrl_next = apb.PWDATA;
          8'h08: clkdiv_next = apb.PWDATA[15:0];
          8'h0C: begin
            if (!tx_full) begin
                tx_push = 1'b1;
                tx_data_in = apb.PWDATA[7:0];
            end
          end
          default: apb.PSLVERR = 1'b1; // Unmapped address
        endcase
    end
  end

  always_ff @(posedge clk or negedge nRST) begin
    if (!nRST) begin
      ctrl <= '0;
      clkdiv <= 16'h0003;
    end else begin
      ctrl <= ctrl_next;
      clkdiv <= clkdiv_next;
    end
  end

endmodule
