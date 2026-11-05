module timer_apb_wrapper #(
    parameter logic [31:0] BASE_ADDR = 32'h8000_2000
) (
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
    assign offset = apb.PADDR - BASE_ADDR;
    
    // Timer0 expects a 13-bit address space. Reject accesses outside this.
    assign alias_err = (offset[31:13] != '0);
    assign paddr_local = offset[12:0];

    // Instantiate the standalone timer APB core
    timer_apb u_timer (
        .pclk      (apb.PCLK),
        .presetn   (apb.PRESETn),
        .paddr     (paddr_local),
        .psel      (apb.PSEL && !alias_err), // Don't select the core on an alias
        .penable   (apb.PENABLE),
        .pwrite    (apb.PWRITE),
        .pwdata    (apb.PWDATA),
        .pstrb     (apb.PSTRB),
        .pprot     (apb.PPROT),
        .prdata    (timer_prdata),
        .pready    (timer_pready),
        .pslverr   (timer_pslverr),
        .capture_i (capture_i),
        .irq_o     (irq_o)
    );

    // If there's an alias error, respond with PSLVERR when selected and enabled.
    // Otherwise pass through the timer's response.
    always_comb begin
        if (alias_err && apb.PSEL) begin
            apb.PRDATA  = '0;
            apb.PREADY  = 1'b1;
            apb.PSLVERR = apb.PENABLE; // Assert error during access phase
        end else begin
            apb.PRDATA  = timer_prdata;
            apb.PREADY  = timer_pready;
            apb.PSLVERR = timer_pslverr;
        end
    end

endmodule
