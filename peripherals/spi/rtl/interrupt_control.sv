import spi_types_pkg::*;
module interrupt_control (
  input  spi_cr_t     ctrl,
  input  spi_status_t status,
  output logic [5:0]  irq
);
  always_comb begin
    irq[0] = ctrl.interrupt_enable[0] & status.transfer_complete;
    irq[1] = ctrl.interrupt_enable[1] & status.rx_water_mark_hit;
    irq[2] = ctrl.interrupt_enable[2] & status.tx_water_mark_hit;
    irq[3] = ctrl.interrupt_enable[3] & status.rx_buffer_full;
    irq[4] = ctrl.interrupt_enable[4] & status.tx_buffer_empty;
    irq[5] = ctrl.interrupt_enable[5] & status.modf;
  end
endmodule
