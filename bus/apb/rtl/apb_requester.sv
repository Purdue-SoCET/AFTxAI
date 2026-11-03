module apb_requester (
    apb_if.requester apb,
    bus_protocol_if.peripheral_vital bus
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;
    
    state_t state, next_state;

    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
        if (!apb.PRESETn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        apb.PSEL = 1'b0;
        apb.PENABLE = 1'b0;
        bus.request_stall = 1'b0;
        
        case (state)
            IDLE: begin
                if (bus.wen || bus.ren) begin
                    next_state = SETUP;
                    bus.request_stall = 1'b1;
                end
            end
            SETUP: begin
                apb.PSEL = 1'b1;
                bus.request_stall = 1'b1;
                next_state = ACCESS;
            end
            ACCESS: begin
                apb.PSEL = 1'b1;
                apb.PENABLE = 1'b1;
                if (apb.PREADY) begin
                    bus.request_stall = 1'b0; // Completion cycle
                    next_state = IDLE;
                end else begin
                    bus.request_stall = 1'b1;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    assign apb.PADDR = bus.addr;
    assign apb.PWRITE = bus.wen;
    assign apb.PWDATA = bus.wdata;
    assign apb.PSTRB = bus.strobe;
    assign apb.PPROT = 3'b000;

    assign bus.rdata = apb.PRDATA;
    assign bus.error = apb.PSLVERR;

endmodule
