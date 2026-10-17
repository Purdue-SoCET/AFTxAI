module apb_completer #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [31:0] BASE_ADDR = 32'h8000_0000,
    parameter int NWORDS = 4
) (
    apb_if.completer apb,
    bus_protocol_if.protocol bus
);

    logic range_error;
    logic align_error;
    logic request_error;
    
    localparam int BYTES_PER_WORD = DATA_WIDTH / 8;
    localparam int REGION_SIZE = NWORDS * BYTES_PER_WORD;

    assign range_error = (apb.PADDR < BASE_ADDR) || (apb.PADDR >= (BASE_ADDR + REGION_SIZE));
    assign align_error = (apb.PADDR % BYTES_PER_WORD) != 0;
    assign request_error = apb.PSEL && (range_error || align_error);

    typedef enum logic [1:0] {
        IDLE,
        ACCESS,
        ERROR
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
        apb.PREADY = 1'b0;
        bus.wen = 1'b0;
        bus.ren = 1'b0;

        case (state)
            IDLE: begin
                if (apb.PSEL && !apb.PENABLE) begin
                    if (request_error) begin
                        next_state = ERROR;
                    end else begin
                        next_state = ACCESS;
                    end
                end
            end
            ACCESS: begin
                if (apb.PSEL && apb.PENABLE) begin
                    bus.wen = apb.PWRITE;
                    bus.ren = ~apb.PWRITE;
                    apb.PREADY = ~bus.request_stall;
                    if (!bus.request_stall) begin
                        next_state = IDLE;
                    end
                end else if (!apb.PSEL) begin
                    next_state = IDLE;
                end
            end
            ERROR: begin
                if (apb.PSEL && apb.PENABLE) begin
                    apb.PREADY = 1'b1;
                    next_state = IDLE;
                end else if (!apb.PSEL) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    assign apb.PSLVERR = (state == ERROR) || request_error;
    assign apb.PRDATA = bus.rdata;
    
    // Convert absolute PADDR to offset
    assign bus.addr = apb.PADDR - BASE_ADDR;
    assign bus.wdata = apb.PWDATA;
    assign bus.strobe = apb.PSTRB;
    assign bus.is_burst = '0;
    assign bus.burst_type = '0;
    assign bus.burst_length = '0;
    assign bus.secure_transfer = '0;

endmodule
