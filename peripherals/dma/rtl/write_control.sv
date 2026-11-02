/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module write_control #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int FIFO_PKT_W = 66
)(
    input  logic clk,
    input  logic rst_n,
    
    // FIFO Interface
    input  logic               fifo_empty,
    output logic               fifo_pop,
    input  logic [FIFO_PKT_W-1:0] fifo_data,
    
    // Arbiter / Bus Interface
    output logic               w_req,
    output logic [ADDR_W-1:0]  w_addr,
    output logic [2:0]         w_size,
    output logic [DATA_W-1:0]  w_data,
    input  logic               w_gnt,
    input  logic               w_ready,
    input  logic               w_err,
    
    // Status
    output logic               hw_error,
    output logic               write_finished,
    input  logic               en
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_FIFO_READ,
        ST_WRITE_REQ,
        ST_WRITE_WAIT
    } state_t;
    
    state_t state, next_state;
    
    logic [1:0]        latched_psize;
    logic [ADDR_W-1:0] latched_dest;
    logic [DATA_W-1:0] latched_data;
    
    always_comb begin
        next_state = state;
        fifo_pop = 1'b0;
        w_req    = 1'b0;
        hw_error = 1'b0;
        
        case (state)
            ST_IDLE: begin
                if (!fifo_empty) begin
                    next_state = ST_FIFO_READ;
                end
            end
            
            ST_FIFO_READ: begin
                fifo_pop = 1'b1;
                next_state = ST_WRITE_REQ;
            end
            
            ST_WRITE_REQ: begin
                w_req = 1'b1;
                if (w_gnt) begin
                    next_state = ST_WRITE_WAIT;
                end
            end
            
            ST_WRITE_WAIT: begin
                if (w_err) begin
                    hw_error = 1'b1;
                    if (!en) next_state = ST_IDLE;
                end else if (w_ready) begin
                    next_state = ST_IDLE;
                end
            end
            default: next_state = ST_IDLE;
        endcase
        
        if (!en) begin
            if (state == ST_WRITE_REQ || state == ST_WRITE_WAIT) hw_error = 1'b1;
            next_state = ST_IDLE;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            latched_psize <= '0;
            latched_dest  <= '0;
            latched_data  <= '0;
        end else begin
            state <= next_state;
            if (state == ST_FIFO_READ) begin
                latched_psize <= fifo_data[FIFO_PKT_W-1 : FIFO_PKT_W-2];
                latched_dest  <= fifo_data[FIFO_PKT_W-3 : DATA_W];
                latched_data  <= fifo_data[DATA_W-1:0];
            end
        end
    end
    
    assign w_addr = latched_dest;
    assign w_size = {1'b0, latched_psize};
    assign w_data = latched_data;
    
    assign write_finished = (state == ST_IDLE && fifo_empty);

endmodule
