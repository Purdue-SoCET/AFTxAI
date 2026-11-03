interface spi_if;
  logic miso_in;
  logic mosi_in;
  logic sck_in;
  logic ss_in;
  
  logic miso_out;
  logic mosi_out;
  logic sck_out;
  logic ss_out;
  logic mode;
  logic [5:0] irq;
endinterface
