module read_control #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter COUNT_W = 8
)(
    input  logic clk,
    input  logic rst_n,

    // Register interface inputs
    input  logic [ADDR_WIDTH-1:0] sar,
    input  logic [ADDR_WIDTH-1:0] dar,
    input  logic [COUNT_W-1:0]    tsr,
    input  logic [31:0]           cr,

    // Control inputs/outputs
    input  logic                  fifo_full,
    output logic                  fifo_push,
    output logic [1:0]            fifo_psize,
    output logic [ADDR_WIDTH-1:0] fifo_dest,
    output logic [DATA_WIDTH-1:0] fifo_data,

    output logic                  fsm_error,
    
    // Arbiter interface
    memArb_if.read_port           arb_if
);

    typedef enum logic [1:0] {
        IDLE,
        READ,
        FIFO_WAIT,
        ERROR
    } state_t;

    state_t state, next_state;

    logic [COUNT_W-1:0] count;
    logic               count_clear;
    logic               count_inc;
    logic               count_done;

    // Decode CR bits
    logic cr_en       = cr[0];
    logic cr_stop     = cr[1];
    logic [1:0] cr_psize = cr[7:6];
    logic cr_inc_src  = cr[12];
    logic cr_inc_dest = cr[11];

    // Current source address logic
    logic [ADDR_WIDTH-1:0] current_src_addr;

    // Address Alignment check
    logic addr_misaligned;
    always_comb begin
        case (cr_psize)
            2'b01: addr_misaligned = current_src_addr[0];     // 16-bit needs aligned on 2
            2'b10: addr_misaligned = (current_src_addr[1:0] != 2'b00); // 32-bit needs aligned on 4
            default: addr_misaligned = 1'b0; // 8-bit is always aligned
        endcase
    end

    // Extend count to 32 bits for shift operation
    logic [31:0] count_ext;
    assign count_ext = { {(32-COUNT_W){1'b0}}, count };

    always_comb begin
        if (cr_inc_src) begin
            current_src_addr = sar + (count_ext << cr_psize);
        end else begin
            current_src_addr = sar;
        end
    end

    // Counter instance
    counter #(COUNT_W) read_cnt (
        .clk(clk),
        .rst_n(rst_n),
        .clear(count_clear),
        .inc(count_inc),
        .limit(tsr),
        .count(count),
        .done(count_done)
    );

    always_comb begin
        next_state = state;
        
        arb_if.r_hsel  = 1'b0;
        arb_if.r_haddr = current_src_addr;
        arb_if.r_hsize = {1'b0, cr_psize};
        
        fifo_push  = 1'b0;
        fifo_psize = cr_psize;
        fifo_data  = arb_if.r_hrdata;
        // Pre-calculate dest address to store in FIFO packet
        if (cr_inc_dest) begin
            fifo_dest = dar + (count_ext << cr_psize);
        end else begin
            fifo_dest = dar;
        end

        count_clear = 1'b0;
        count_inc   = 1'b0;
        fsm_error   = 1'b0;

        case (state)
            IDLE: begin
                count_clear = 1'b1;
                if (cr_en && !cr_stop) begin
                    if (tsr == '0) begin
                        // No transfers requested
                        next_state = IDLE;
                    end else begin
                        next_state = READ;
                    end
                end
            end

            READ: begin
                if (cr_stop || !cr_en) begin
                    next_state = IDLE;
                end else if (addr_misaligned) begin
                    fsm_error = 1'b1;
                    next_state = ERROR;
                end else begin
                    arb_if.r_hsel = 1'b1;
                    if (arb_if.r_hready) begin
                        if (arb_if.r_hresp != 1'b0) begin // ERROR
                            fsm_error = 1'b1;
                            next_state = ERROR;
                        end else begin
                            next_state = FIFO_WAIT;
                        end
                    end
                end
            end

            FIFO_WAIT: begin
                if (cr_stop || !cr_en) begin
                    next_state = IDLE;
                end else if (!fifo_full) begin
                    fifo_push = 1'b1;
                    count_inc = 1'b1;
                    
                    if (count_done || (count + 1'b1 == tsr)) begin
                        next_state = IDLE; // Transfer complete
                    end else begin
                        next_state = READ;
                    end
                end
            end

            ERROR: begin
                fsm_error = 1'b1;
                if (!cr_en) begin
                    next_state = IDLE; // Wait for software to clear EN
                end
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
