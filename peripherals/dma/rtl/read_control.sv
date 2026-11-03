/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */
/* verilator lint_off UNUSEDPARAM */
`timescale 1ns/1ps

module read_control #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32,
    parameter int COUNT_W = 8,
    parameter int FIFO_PKT_W = 66
)(
    input  logic clk,
    input  logic rst_n,
    
    // Register interface
    input  logic [ADDR_W-1:0]  sar,
    input  logic [ADDR_W-1:0]  dar,
    input  logic [COUNT_W-1:0] tsr,
    input  logic [31:0]        cr,
    
    // Trigger
    input  logic drq,
    output logic daq,
    
    // Counter
    output logic               cnt_clear,
    output logic               cnt_inc,
    input  logic [COUNT_W-1:0] count,
    
    // Arbiter / Bus Interface
    output logic               r_req,
    output logic [ADDR_W-1:0]  r_addr,
    output logic [2:0]         r_size,
    input  logic               r_gnt,
    input  logic               r_ready,
    input  logic [DATA_W-1:0]  r_rdata,
    input  logic               r_err,
    
    // FIFO Interface
    input  logic               fifo_full,
    output logic               fifo_push,
    output logic [FIFO_PKT_W-1:0] fifo_data,
    output logic               fifo_clear,
    
    // Status
    output logic               hw_finished,
    output logic               hw_error,
    input  logic               write_finished
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_READ_REQ,
        ST_READ_WAIT,
        ST_FIFO_WAIT,
        ST_FIFO_PUSH,
        ST_ERROR,
        ST_FINISH
    } state_t;
    
    state_t state, next_state;
    
    logic en;
    logic stop;
    logic [1:0] psize;
    logic trig_en;
    logic circ;
    logic inc_dest;
    logic inc_src;
    
    assign en        = cr[0];
    assign stop      = cr[1];
    assign psize     = cr[7:6];
    assign trig_en   = cr[8];
    assign circ      = cr[10];
    assign inc_dest  = cr[11];
    assign inc_src   = cr[12];
    
    logic [ADDR_W-1:0] curr_src_addr;
    logic [ADDR_W-1:0] curr_dest_addr;
    
    // Address calculation
    logic [ADDR_W-1:0] offset;
    assign offset = ADDR_W'(count) << psize;
    
    assign curr_src_addr  = inc_src  ? (sar + offset) : sar;
    assign curr_dest_addr = inc_dest ? (dar + offset) : dar;
    
    // Next state logic
    always_comb begin
        next_state = state;
        r_req      = 1'b0;
        fifo_push  = 1'b0;
        cnt_inc    = 1'b0;
        hw_finished = 1'b0;
        hw_error   = 1'b0;
        daq        = 1'b0;
        
        case (state)
            ST_IDLE: begin
                if (en && !stop) begin
                    if (count == tsr) begin
                        if (circ) begin
                            // Wait for write side to finish before wrap
                            if (write_finished) next_state = ST_READ_REQ;
                        end else begin
                            next_state = ST_FINISH;
                        end
                    end else if (!trig_en || drq) begin
                        next_state = ST_READ_REQ;
                    end
                end
            end
            
            ST_READ_REQ: begin
                r_req = 1'b1;
                if (psize == 2'b11 || sar[0] || dar[0]) begin // Basic alignment/illegal check
                    next_state = ST_ERROR;
                end else if (r_gnt) begin
                    if (trig_en) daq = 1'b1;
                    next_state = ST_READ_WAIT;
                end
            end
            
            ST_READ_WAIT: begin
                if (r_err) begin
                    next_state = ST_ERROR;
                end else if (r_ready) begin
                    next_state = ST_FIFO_WAIT;
                end
            end
            
            ST_FIFO_WAIT: begin
                if (!fifo_full) begin
                    next_state = ST_FIFO_PUSH;
                end
            end
            
            ST_FIFO_PUSH: begin
                fifo_push = 1'b1;
                cnt_inc   = 1'b1;
                next_state = ST_IDLE; // Loop back for next word
            end
            
            ST_ERROR: begin
                hw_error = 1'b1;
                if (!en) next_state = ST_IDLE; // wait for software clear
            end
            
            ST_FINISH: begin
                if (write_finished) begin
                    hw_finished = 1'b1;
                    next_state = ST_IDLE;
                end
            end
            
            default: next_state = ST_IDLE;
        endcase
        
        // Stop condition abort
        if (stop) begin
            if (state != ST_IDLE && state != ST_ERROR && state != ST_FINISH) begin
                next_state = ST_ERROR; 
            end
        end
    end
    
    // Outputs
    assign r_addr = curr_src_addr;
    assign r_size = {1'b0, psize};
    assign fifo_data = {psize, curr_dest_addr, r_rdata};
    
    assign cnt_clear  = (state == ST_IDLE && en && count == tsr && circ) || fifo_clear;
    assign fifo_clear = (state == ST_ERROR) || (!en && state == ST_IDLE); 
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule
