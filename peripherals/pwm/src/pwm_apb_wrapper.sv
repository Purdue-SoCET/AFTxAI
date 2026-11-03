`default_nettype none

module pwm_apb_wrapper #(
    parameter int PWM_CHANNELS = 4,
    // Absolute base address for PWM
    parameter logic [31:0] BASE_ADDR = 32'h8000_1000
) (
    apb_if.completer apb,
    output logic [PWM_CHANNELS-1:0] pwm_out_o,
    output logic [PWM_CHANNELS-1:0] pwm_oe_o,
    output wire irq_o
);

    // Validate that the request address falls within the PWM 4KB window (12-bit offset)
    logic valid_addr;
    // We check if the address (with the lower 12 bits masked out) matches the BASE_ADDR (also masked)
    assign valid_addr = ((apb.PADDR & ~32'hFFF) == (BASE_ADDR & ~32'hFFF));

    // Internal signals matching the core's scalar ports
    logic [11:0] paddr_local;
    logic        psel_local;
    logic        pslverr_core;

    assign paddr_local = apb.PADDR[11:0];
    // Only forward PSEL if the address matches our expected 4KB window base
    assign psel_local  = apb.PSEL && valid_addr;

    // For accesses outside our 4KB window but where PSEL is still asserted (due to interconnect decode granularity),
    // we should respond with PSLVERR.
    assign apb.PSLVERR = (apb.PSEL && apb.PENABLE && !valid_addr) ? 1'b1 : pslverr_core;
    // If not valid_addr, we just tie PRDATA to 0 and PREADY to 1. 
    // Wait, the core already handles accesses nicely, but we shouldn't even trigger the core if not valid_addr.
    
    // Core instantiation
    pwm_core #(
        .PWM_CHANNELS(PWM_CHANNELS),
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) core (
        .pclk      (apb.PCLK),
        .presetn   (apb.PRESETn),
        
        .paddr     (paddr_local),
        .psel      (psel_local),
        .penable   (apb.PENABLE),
        .pwrite    (apb.PWRITE),
        .pwdata    (apb.PWDATA),
        .pstrb     (apb.PSTRB),
        .pprot     (apb.PPROT),
        
        .prdata    (apb.PRDATA),
        .pready    (apb.PREADY),
        .pslverr   (pslverr_core),
        
        .pwm_out_o (pwm_out_o),
        .pwm_oe_o  (pwm_oe_o),
        .irq_o     (irq_o)
    );

endmodule
`default_nettype wire
