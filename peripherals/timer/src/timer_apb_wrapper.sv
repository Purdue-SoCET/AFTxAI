module timer_apb_wrapper #(
    parameter logic [31:0] BASE_ADDR = 32'h0000_2000
) (
    input logic pclk,
    input logic presetn,
    apb_if.completer apb,
    input  logic         capture_i,
    output logic         irq_o
);

    logic [12:0] paddr_local;
    logic        alias_err;
    logic        timer_pslverr;
    logic [31:0] timer_prdata;
    logic        timer_pready;

    // Calculate local offset
    logic [31:0] offset;
    assign offset = apb.paddr - BASE_ADDR;
    
    // Timer0 expects a 13-bit address space. Reject accesses outside this.
    assign alias_err = (offset[31:13] != '0);
    assign paddr_local = offset[12:0];

    // Instantiate the standalone timer APB core
    timer_apb u_timer (
        .pclk      (pclk),
        .presetn   (presetn),
        .paddr     (paddr_local),
        .psel      (apb.psel && !alias_err), // Don't select the core on an alias
        .penable   (apb.penable),
        .pwrite    (apb.pwrite),
        .pwdata    (apb.pwdata),
        .pstrb     (apb.pstrb),
        .pprot     (apb.pprot),
        .prdata    (timer_prdata),
        .pready    (timer_pready),
        .pslverr   (timer_pslverr),
        .capture_i (capture_i),
        .irq_o     (irq_o)
    );

    // If there's an alias error, respond with PSLVERR when selected and enabled.
    // Otherwise pass through the timer's response.
    always_comb begin
        if (alias_err && apb.psel) begin
            apb.prdata  = '0;
            apb.pready  = 1'b1;
            apb.pslverr = apb.penable; // Assert error during access phase
        end else begin
            apb.prdata  = timer_prdata;
            apb.pready  = timer_pready;
            apb.pslverr = timer_pslverr;
        end
    end

endmodule
