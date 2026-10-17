package spi_types_pkg;
  typedef struct packed {
    logic [8:0] reserved;
    logic [5:0] interrupt_enable;
    logic [4:0] tx_water_mark;
    logic [4:0] rx_water_mark;
    logic       modf_enable;
    logic       msb_first;
    logic       ssoe;
    logic       clock_phase;
    logic       clock_polarity;
    logic       mode;
    logic       start_transaction;
  } spi_cr_t;

  typedef struct packed {
    logic [15:0] reserved;
    logic [4:0]  tx_buffer_cnt;
    logic [4:0]  rx_buffer_cnt;
    logic        modf;
    logic        tx_buffer_empty;
    logic        rx_buffer_full;
    logic        tx_water_mark_hit;
    logic        rx_water_mark_hit;
    logic        transfer_complete;
  } spi_status_t;
endpackage
