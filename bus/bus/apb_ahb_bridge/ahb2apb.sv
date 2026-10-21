module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH = 16
)(
    input  logic wclk,
    input  logic wrst_n,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic winc,
    output logic wfull,

    input  logic rclk,
    input  logic rrst_n,
    output logic [DATA_WIDTH-1:0] rdata,
    input  logic rinc,
    output logic rempty
);
    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    logic [ADDR_WIDTH:0] wptr_bin, wptr_gray, wptr_gray_next, wptr_bin_next;
    logic [ADDR_WIDTH:0] rptr_bin, rptr_gray, rptr_gray_next, rptr_bin_next;
    
    logic [ADDR_WIDTH:0] wq1_rptr, wq2_rptr;
    logic [ADDR_WIDTH:0] rq1_wptr, rq2_wptr;

    always_comb begin
        wptr_bin_next = wptr_bin + (winc & ~wfull);
        wptr_gray_next = (wptr_bin_next >> 1) ^ wptr_bin_next;
    end

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wptr_bin  <= '0;
            wptr_gray <= '0;
        end else begin
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= wptr_gray_next;
        end
    end

    always_ff @(posedge wclk) begin
        if (winc && !wfull)
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
    end

    always_comb begin
        rptr_bin_next = rptr_bin + (rinc & ~rempty);
        rptr_gray_next = (rptr_bin_next >> 1) ^ rptr_bin_next;
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rptr_bin  <= '0;
            rptr_gray <= '0;
        end else begin
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= rptr_gray_next;
        end
    end

    assign rdata = mem[rptr_bin[ADDR_WIDTH-1:0]];

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wq1_rptr <= '0;
            wq2_rptr <= '0;
        end else begin
            wq1_rptr <= rptr_gray;
            wq2_rptr <= wq1_rptr;
        end
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr <= '0;
            rq2_wptr <= '0;
        end else begin
            rq1_wptr <= wptr_gray;
            rq2_wptr <= rq1_wptr;
        end
    end

    assign wfull  = (wptr_gray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});
    assign rempty = (rptr_gray == rq2_wptr);

endmodule


module ahb2apb #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 'h8000_0000,
    parameter int FIFO_DEPTH = 16,
    parameter int NWORDS = 4096
)(
    ahb_if.subordinate ahbif,
    apb_if.requester   apbif
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam logic [ADDR_WIDTH-1:0] TOP_ADDR = BASE_ADDR + NWORDS * STRB_WIDTH;

    typedef struct packed {
        logic [ADDR_WIDTH-1:0] addr;
        logic [DATA_WIDTH-1:0] wdata;
        logic                  write;
        logic [STRB_WIDTH-1:0] strobe;
    } fwd_pkt_t;

    typedef struct packed {
        logic                  hresp;
        logic [DATA_WIDTH-1:0] rdata;
    } ret_pkt_t;

    logic fwd_push, fwd_pop, fwd_empty, fwd_full;
    fwd_pkt_t fwd_wdata, fwd_rdata;

    logic ret_push, ret_pop, ret_empty, ret_full;
    ret_pkt_t ret_wdata, ret_rdata;

    async_fifo #(
        .DATA_WIDTH($bits(fwd_pkt_t)),
        .DEPTH(FIFO_DEPTH)
    ) fwd_fifo (
        .wclk(ahbif.HCLK), .wrst_n(ahbif.HRESETn), .wdata(fwd_wdata), .winc(fwd_push), .wfull(fwd_full),
        .rclk(apbif.PCLK), .rrst_n(apbif.PRESETn), .rdata(fwd_rdata), .rinc(fwd_pop), .rempty(fwd_empty)
    );

    async_fifo #(
        .DATA_WIDTH($bits(ret_pkt_t)),
        .DEPTH(FIFO_DEPTH)
    ) ret_fifo (
        .wclk(apbif.PCLK), .wrst_n(apbif.PRESETn), .wdata(ret_wdata), .winc(ret_push), .wfull(ret_full),
        .rclk(ahbif.HCLK), .rrst_n(ahbif.HRESETn), .rdata(ret_rdata), .rinc(ret_pop), .rempty(ret_empty)
    );

    // ==========================================
    // AHB Side
    // ==========================================
    typedef enum logic [1:0] {
        AHB_IDLE,
        AHB_WAIT,
        AHB_ERROR_1,
        AHB_ERROR_2
    } ahb_state_t;

    ahb_state_t ahb_state, ahb_next;

    logic addr_in_range;
    logic addr_aligned;
    logic addr_valid;
    logic ahb_req_valid;

    assign addr_in_range = (ahbif.HADDR >= BASE_ADDR) && (ahbif.HADDR < TOP_ADDR);
    assign addr_aligned = ((ahbif.HADDR & (STRB_WIDTH - 1)) == '0);
    assign addr_valid = addr_in_range && addr_aligned;
    assign ahb_req_valid = ahbif.HSEL && ahbif.HTRANS[1] && ahbif.HREADY;

    logic [ADDR_WIDTH-1:0] latched_addr;
    logic                  latched_write;
    logic [STRB_WIDTH-1:0] latched_strobe;

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            latched_addr   <= '0;
            latched_write  <= '0;
            latched_strobe <= '0;
        end else if (ahb_state == AHB_IDLE && ahb_req_valid && addr_valid) begin
            latched_addr   <= ahbif.HADDR - BASE_ADDR;
            latched_write  <= ahbif.HWRITE;
            latched_strobe <= ahbif.HWSTRB;
        end
    end

    logic req_pushed;
    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            req_pushed <= 1'b0;
        end else begin
            if (ahb_state == AHB_IDLE) begin
                req_pushed <= 1'b0;
            end else if (ahb_state == AHB_WAIT && !req_pushed && !fwd_full) begin
                req_pushed <= 1'b1;
            end
        end
    end

    assign fwd_push = (ahb_state == AHB_WAIT && !req_pushed && !fwd_full);
    assign fwd_wdata.addr   = latched_addr;
    assign fwd_wdata.write  = latched_write;
    assign fwd_wdata.strobe = latched_strobe;
    assign fwd_wdata.wdata  = ahbif.HWDATA;

    logic apb_done;
    logic apb_err;
    logic [DATA_WIDTH-1:0] apb_rdata;

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            apb_done  <= 1'b0;
            apb_err   <= 1'b0;
            apb_rdata <= '0;
        end else begin
            if (ahb_state == AHB_WAIT && req_pushed && !ret_empty && !apb_done) begin
                apb_done  <= 1'b1;
                apb_err   <= ret_rdata.hresp;
                apb_rdata <= ret_rdata.rdata;
            end else if (ahb_state == AHB_IDLE) begin
                apb_done  <= 1'b0;
            end
        end
    end

    assign ret_pop = (ahb_state == AHB_WAIT && req_pushed && !ret_empty && !apb_done);

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn)
            ahb_state <= AHB_IDLE;
        else
            ahb_state <= ahb_next;
    end

    always_comb begin
        ahb_next = ahb_state;
        case (ahb_state)
            AHB_IDLE: begin
                if (ahb_req_valid) begin
                    if (addr_valid)
                        ahb_next = AHB_WAIT;
                    else
                        ahb_next = AHB_ERROR_1;
                end
            end
            AHB_WAIT: begin
                if (apb_done) begin
                    if (apb_err)
                        ahb_next = AHB_ERROR_1;
                    else
                        ahb_next = AHB_IDLE;
                end
            end
            AHB_ERROR_1: begin
                ahb_next = AHB_ERROR_2;
            end
            AHB_ERROR_2: begin
                ahb_next = AHB_IDLE;
            end
        endcase
    end

    assign ahbif.HREADYOUT = (ahb_state == AHB_IDLE) ? 1'b1 :
                             (ahb_state == AHB_WAIT && apb_done && !apb_err) ? 1'b1 :
                             (ahb_state == AHB_ERROR_2) ? 1'b1 : 1'b0;

    assign ahbif.HRESP     = (ahb_state == AHB_ERROR_1 || ahb_state == AHB_ERROR_2) ? 1'b1 : 1'b0;
    assign ahbif.HRDATA    = apb_rdata;

    // ==========================================
    // APB Side
    // ==========================================
    typedef enum logic [1:0] {
        APB_IDLE,
        APB_SETUP,
        APB_ACCESS
    } apb_state_t;

    apb_state_t apb_state, apb_next;
    fwd_pkt_t apb_req;
    logic apb_req_valid;

    always_ff @(posedge apbif.PCLK or negedge apbif.PRESETn) begin
        if (!apbif.PRESETn) begin
            apb_state <= APB_IDLE;
            apb_req_valid <= 1'b0;
            apb_req <= '0;
        end else begin
            apb_state <= apb_next;
            
            if (apb_state == APB_IDLE && !fwd_empty && !apb_req_valid) begin
                apb_req_valid <= 1'b1;
                apb_req <= fwd_rdata;
            end else if (apb_state == APB_ACCESS && apbif.PREADY) begin
                apb_req_valid <= 1'b0;
            end
        end
    end

    assign fwd_pop = (apb_state == APB_IDLE && !fwd_empty && !apb_req_valid);

    logic ret_pushed;
    always_ff @(posedge apbif.PCLK or negedge apbif.PRESETn) begin
        if (!apbif.PRESETn) begin
            ret_pushed <= 1'b0;
        end else begin
            if (apb_state == APB_ACCESS && apbif.PREADY && !ret_pushed) begin
                ret_pushed <= 1'b1;
            end else if (apb_state == APB_IDLE) begin
                ret_pushed <= 1'b0;
            end
        end
    end

    assign ret_push = (apb_state == APB_ACCESS && apbif.PREADY && !ret_pushed);
    assign ret_wdata.hresp = apbif.PSLVERR;
    assign ret_wdata.rdata = apbif.PRDATA;

    always_comb begin
        apb_next = apb_state;
        case (apb_state)
            APB_IDLE: begin
                if (apb_req_valid) begin
                    apb_next = APB_SETUP;
                end
            end
            APB_SETUP: begin
                apb_next = APB_ACCESS;
            end
            APB_ACCESS: begin
                if (apbif.PREADY) begin
                    apb_next = APB_IDLE;
                end
            end
            default: apb_next = APB_IDLE;
        endcase
    end

    assign apbif.PSEL    = (apb_state == APB_SETUP || apb_state == APB_ACCESS);
    assign apbif.PENABLE = (apb_state == APB_ACCESS);
    assign apbif.PADDR   = apb_req.addr;
    assign apbif.PWRITE  = apb_req.write;
    assign apbif.PWDATA  = apb_req.wdata;
    assign apbif.PSTRB   = apb_req.strobe;
    assign apbif.PPROT   = '0;

endmodule