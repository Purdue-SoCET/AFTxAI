module memArbiter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // Interface to read/write controllers
    memArb_if.arbiter_port req_if,

    // AHB Master out
    ahb_if.manager ahb_m
);

    typedef enum logic [1:0] {
        IDLE,
        GRANT_READ,
        GRANT_WRITE
    } state_t;

    state_t state, next_state;

    // Simple priority: Read over Write if both request
    always_comb begin
        next_state = state;
        
        // Default Master signals
        ahb_m.HSEL      = 1'b0;
        ahb_m.HTRANS    = 2'b00; // IDLE
        ahb_m.HADDR     = '0;
        ahb_m.HWRITE    = 1'b0;
        ahb_m.HSIZE     = 3'b010; // default 32-bit
        ahb_m.HBURST    = 3'b000;
        ahb_m.HWDATA    = '0;
        ahb_m.HWSTRB    = '1;
        ahb_m.HMASTLOCK = 1'b0;

        req_if.r_hready = 1'b0;
        req_if.w_hready = 1'b0;
        req_if.r_hresp  = ahb_m.HRESP;
        req_if.w_hresp  = ahb_m.HRESP;
        req_if.r_hrdata = ahb_m.HRDATA;

        case (state)
            IDLE: begin
                if (req_if.r_hsel) begin
                    next_state = GRANT_READ;
                    ahb_m.HSEL   = 1'b1;
                    ahb_m.HTRANS = 2'b10; // NONSEQ
                    ahb_m.HADDR  = req_if.r_haddr;
                    ahb_m.HWRITE = 1'b0;
                    ahb_m.HSIZE  = req_if.r_hsize;
                end else if (req_if.w_hsel) begin
                    next_state = GRANT_WRITE;
                    ahb_m.HSEL   = 1'b1;
                    ahb_m.HTRANS = 2'b10; // NONSEQ
                    ahb_m.HADDR  = req_if.w_haddr;
                    ahb_m.HWRITE = 1'b1;
                    ahb_m.HSIZE  = req_if.w_hsize;
                    ahb_m.HWDATA = req_if.w_hwdata;
                end
            end
            
            GRANT_READ: begin
                ahb_m.HSEL   = 1'b1;
                ahb_m.HTRANS = 2'b10;
                ahb_m.HADDR  = req_if.r_haddr;
                ahb_m.HWRITE = 1'b0;
                ahb_m.HSIZE  = req_if.r_hsize;
                
                req_if.r_hready = ahb_m.HREADY;
                if (ahb_m.HREADY) begin
                    if (req_if.w_hsel) begin
                        next_state = GRANT_WRITE;
                    end else if (!req_if.r_hsel) begin
                        next_state = IDLE;
                    end
                end
            end

            GRANT_WRITE: begin
                ahb_m.HSEL   = 1'b1;
                ahb_m.HTRANS = 2'b10;
                ahb_m.HADDR  = req_if.w_haddr;
                ahb_m.HWRITE = 1'b1;
                ahb_m.HSIZE  = req_if.w_hsize;
                ahb_m.HWDATA = req_if.w_hwdata;

                req_if.w_hready = ahb_m.HREADY;
                if (ahb_m.HREADY) begin
                    if (req_if.r_hsel) begin
                        next_state = GRANT_READ;
                    end else if (!req_if.w_hsel) begin
                        next_state = IDLE;
                    end
                end
            end
            default: next_state = IDLE;
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
