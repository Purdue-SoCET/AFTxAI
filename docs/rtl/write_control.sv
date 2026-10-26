module write_control #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    input  logic [31:0] cr,

    // FIFO interface
    input  logic                  fifo_empty,
    output logic                  fifo_pop,
    input  logic [1:0]            fifo_psize,
    input  logic [ADDR_WIDTH-1:0] fifo_dest,
    input  logic [DATA_WIDTH-1:0] fifo_data,

    // Status outputs
    output logic                  fsm_error,
    output logic                  fsm_finished,

    // Arbiter interface
    memArb_if.write_port          arb_if
);

    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        ERROR
    } state_t;

    state_t state, next_state;

    logic cr_en   = cr[0];
    logic cr_stop = cr[1];

    // Latch FIFO data to hold it stable during AHB address/data phases
    logic [1:0]            latched_psize;
    logic [ADDR_WIDTH-1:0] latched_dest;
    logic [DATA_WIDTH-1:0] latched_data;

    logic latch_en;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_psize <= '0;
            latched_dest  <= '0;
            latched_data  <= '0;
        end else if (latch_en) begin
            latched_psize <= fifo_psize;
            latched_dest  <= fifo_dest;
            latched_data  <= fifo_data;
        end
    end

    // Address Alignment check
    logic addr_misaligned;
    always_comb begin
        case (latched_psize)
            2'b01: addr_misaligned = latched_dest[0];
            2'b10: addr_misaligned = (latched_dest[1:0] != 2'b00);
            default: addr_misaligned = 1'b0;
        endcase
    end

    always_comb begin
        next_state = state;
        
        fifo_pop  = 1'b0;
        latch_en  = 1'b0;
        fsm_error = 1'b0;
        fsm_finished = 1'b0;

        arb_if.w_hsel   = 1'b0;
        arb_if.w_haddr  = latched_dest;
        arb_if.w_hsize  = {1'b0, latched_psize};
        arb_if.w_hwdata = latched_data;

        case (state)
            IDLE: begin
                if (cr_stop || !cr_en) begin
                    next_state = IDLE;
                end else if (!fifo_empty) begin
                    fifo_pop = 1'b1;
                    latch_en = 1'b1;
                    next_state = WRITE;
                end else if (cr_en && fifo_empty /* Need to know if read side is done... will handle via dma top logic */) begin
                    // Actually, the write side just drains the FIFO. 
                    // Finished state is handled in the top level based on the counter.
                    next_state = IDLE;
                end
            end

            WRITE: begin
                if (cr_stop || !cr_en) begin
                    next_state = IDLE;
                end else if (addr_misaligned) begin
                    fsm_error = 1'b1;
                    next_state = ERROR;
                end else begin
                    arb_if.w_hsel = 1'b1;
                    if (arb_if.w_hready) begin
                        if (arb_if.w_hresp != 1'b0) begin
                            fsm_error = 1'b1;
                            next_state = ERROR;
                        end else begin
                            fsm_finished = 1'b1; // Completed a write transfer unit
                            // Go back to IDLE to check FIFO for more
                            next_state = IDLE;
                        end
                    end
                end
            end

            ERROR: begin
                fsm_error = 1'b1;
                if (!cr_en) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule
