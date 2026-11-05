`timescale 1ns/1ps

module async_fifo #(
    parameter int WIDTH = 32,
    parameter int DEPTH = 16
)(
    input  logic             wclk,
    input  logic             wrst_n,
    input  logic             winc,
    input  logic [WIDTH-1:0] wdata,
    output logic             wfull,

    input  logic             rclk,
    input  logic             rrst_n,
    input  logic             rinc,
    output logic [WIDTH-1:0] rdata,
    output logic             rempty
);
    localparam int ADDR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0] wptr, rptr;
    logic [ADDR_W:0] wq1_rptr, wq2_rptr;
    logic [ADDR_W:0] rq1_wptr, rq2_wptr;

    logic [ADDR_W:0] wbin, wbin_next, wgray_next;
    logic [ADDR_W:0] rbin, rbin_next, rgray_next;

    // Write domain
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= '0;
            wptr <= '0;
        end else begin
            wbin <= wbin_next;
            wptr <= wgray_next;
        end
    end

    assign wbin_next = wbin + (winc & ~wfull);
    assign wgray_next = (wbin_next >> 1) ^ wbin_next;

    always_ff @(posedge wclk) begin
        if (winc && !wfull)
            mem[wbin[ADDR_W-1:0]] <= wdata;
    end

    // Read domain
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= '0;
            rptr <= '0;
        end else begin
            rbin <= rbin_next;
            rptr <= rgray_next;
        end
    end

    assign rbin_next = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;
    assign rdata = mem[rbin[ADDR_W-1:0]];

    // Synchronizers
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= '0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
    end

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= '0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
    end

    // Status
    assign rempty = (rptr == rq2_wptr);
    assign wfull  = (wptr == {~wq2_rptr[ADDR_W:ADDR_W-1], wq2_rptr[ADDR_W-2:0]});

endmodule

module ahb2apb #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter logic [ADDR_WIDTH-1:0] BASE_ADDR = 'h8000_0000,
    parameter int FIFO_DEPTH = 16,
    parameter int NWORDS = 4096
)(
    ahb_if.subordinate ahbif,
    apb_if             apbif
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam logic [ADDR_WIDTH-1:0] TOP_ADDR = BASE_ADDR + NWORDS * STRB_WIDTH;

    // ---------------------------------------------------------
    // FIFOs
    // ---------------------------------------------------------
    localparam int FWD_WIDTH = ADDR_WIDTH + DATA_WIDTH + 1 + STRB_WIDTH;
    localparam int RET_WIDTH = 1 + DATA_WIDTH;

    logic fwd_winc, fwd_wfull;
    logic fwd_rinc, fwd_rempty;
    logic [FWD_WIDTH-1:0] fwd_wdata, fwd_rdata;

    logic ret_winc, ret_wfull;
    logic ret_rinc, ret_rempty;
    logic [RET_WIDTH-1:0] ret_wdata, ret_rdata;

    async_fifo #(
        .WIDTH(FWD_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) fwd_fifo (
        .wclk(ahbif.HCLK), .wrst_n(ahbif.HRESETn),
        .winc(fwd_winc), .wdata(fwd_wdata), .wfull(fwd_wfull),
        .rclk(apbif.PCLK), .rrst_n(apbif.PRESETn),
        .rinc(fwd_rinc), .rdata(fwd_rdata), .rempty(fwd_rempty)
    );

    async_fifo #(
        .WIDTH(RET_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) ret_fifo (
        .wclk(apbif.PCLK), .wrst_n(apbif.PRESETn),
        .winc(ret_winc), .wdata(ret_wdata), .wfull(ret_wfull),
        .rclk(ahbif.HCLK), .rrst_n(ahbif.HRESETn),
        .rinc(ret_rinc), .rdata(ret_rdata), .rempty(ret_rempty)
    );

    // ---------------------------------------------------------
    // AHB Side
    // ---------------------------------------------------------
    typedef enum logic [1:0] {
        AHB_IDLE,
        AHB_WAIT,
        AHB_ERROR1,
        AHB_ERROR2
    } ahb_state_t;

    ahb_state_t ahb_state, ahb_next;

    logic ahb_req_valid;
    logic ahb_addr_in_range;
    logic ahb_addr_aligned;
    logic ahb_addr_ok;

    assign ahb_addr_in_range = (ahbif.HADDR >= BASE_ADDR) && (ahbif.HADDR < TOP_ADDR);
    assign ahb_addr_aligned  = ((ahbif.HADDR & (STRB_WIDTH - 1)) == '0);
    assign ahb_addr_ok       = ahb_addr_in_range && ahb_addr_aligned;

    assign ahb_req_valid = ahbif.HSEL && ahbif.HTRANS[1] && ahbif.HREADY;

    // Latched AHB request signals
    logic [ADDR_WIDTH-1:0] latched_addr;
    logic                  latched_write;
    logic                  latched_addr_ok;

    logic fwd_pushed;

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            latched_addr    <= '0;
            latched_write   <= '0;
            latched_addr_ok <= '0;
        end else begin
            if ((ahb_state == AHB_IDLE && ahb_req_valid) ||
                (ahb_state == AHB_WAIT && fwd_pushed && !ret_rempty && ret_rdata[DATA_WIDTH] == 1'b0 && ahbif.HSEL && ahbif.HTRANS[1])) begin
                latched_addr    <= ahbif.HADDR;
                latched_write   <= ahbif.HWRITE;
                latched_addr_ok <= ahb_addr_ok;
            end
        end
    end

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn) begin
            fwd_pushed <= 1'b0;
        end else begin
            if ((ahb_state == AHB_IDLE && ahb_req_valid && ahb_addr_ok) ||
                (ahb_state == AHB_WAIT && fwd_pushed && !ret_rempty && ret_rdata[DATA_WIDTH] == 1'b0 && ahbif.HSEL && ahbif.HTRANS[1] && ahb_addr_ok)) begin
                fwd_pushed <= 1'b0;
            end else if (ahb_state == AHB_WAIT && fwd_winc) begin
                fwd_pushed <= 1'b1;
            end
        end
    end

    assign fwd_wdata = {latched_addr, ahbif.HWDATA, latched_write, ahbif.HWSTRB};

    always_ff @(posedge ahbif.HCLK or negedge ahbif.HRESETn) begin
        if (!ahbif.HRESETn)
            ahb_state <= AHB_IDLE;
        else
            ahb_state <= ahb_next;
    end

    always_comb begin
        ahb_next     = ahb_state;
        fwd_winc     = 1'b0;
        ret_rinc     = 1'b0;
        ahbif.HREADYOUT = 1'b1;
        ahbif.HRESP  = 1'b0;
        ahbif.HRDATA = ret_rdata[DATA_WIDTH-1:0];

        case (ahb_state)
            AHB_IDLE: begin
                if (ahb_req_valid) begin
                    if (!ahb_addr_ok) begin
                        ahb_next = AHB_ERROR1;
                    end else begin
                        ahb_next = AHB_WAIT;
                    end
                end
            end
            
            AHB_WAIT: begin
                ahbif.HREADYOUT = 1'b0;
                
                if (!fwd_pushed && !fwd_wfull) begin
                    fwd_winc = 1'b1;
                end
                
                if (fwd_pushed && !ret_rempty) begin
                    if (ret_rdata[DATA_WIDTH] == 1'b1) begin
                        // APB Error
                        ahbif.HREADYOUT = 1'b0;
                        ahbif.HRESP = 1'b1;
                        ret_rinc = 1'b1;
                        ahb_next = AHB_ERROR2;
                    end else begin
                        // Success
                        ahbif.HREADYOUT = 1'b1;
                        ahbif.HRESP = 1'b0;
                        ret_rinc = 1'b1;
                        
                        if (ahbif.HSEL && ahbif.HTRANS[1]) begin
                            if (!ahb_addr_ok) begin
                                ahb_next = AHB_ERROR1;
                            end else begin
                                ahb_next = AHB_WAIT;
                            end
                        end else begin
                            ahb_next = AHB_IDLE;
                        end
                    end
                end
            end
            
            AHB_ERROR1: begin
                ahbif.HREADYOUT = 1'b0;
                ahbif.HRESP = 1'b1;
                ahb_next = AHB_ERROR2;
            end
            
            AHB_ERROR2: begin
                ahbif.HREADYOUT = 1'b1;
                ahbif.HRESP = 1'b1;
                ahb_next = AHB_IDLE;
            end
        endcase
    end

    // ---------------------------------------------------------
    // APB Side
    // ---------------------------------------------------------
    typedef enum logic [1:0] {
        APB_IDLE,
        APB_SETUP,
        APB_ACCESS
    } apb_state_t;

    apb_state_t apb_state, apb_next;

    always_ff @(posedge apbif.PCLK or negedge apbif.PRESETn) begin
        if (!apbif.PRESETn)
            apb_state <= APB_IDLE;
        else
            apb_state <= apb_next;
    end

    logic [ADDR_WIDTH-1:0] apb_req_addr;
    logic [DATA_WIDTH-1:0] apb_req_wdata;
    logic                  apb_req_write;
    logic [STRB_WIDTH-1:0] apb_req_strb;

    assign {apb_req_addr, apb_req_wdata, apb_req_write, apb_req_strb} = fwd_rdata;

    always_comb begin
        apb_next = apb_state;
        fwd_rinc = 1'b0;
        ret_winc = 1'b0;
        
        apbif.PSEL    = 1'b0;
        apbif.PENABLE = 1'b0;
        apbif.PADDR   = '0;
        apbif.PWDATA  = '0;
        apbif.PWRITE  = 1'b0;
        apbif.PSTRB   = '0;
        apbif.PPROT   = '0;
        
        ret_wdata = {apbif.PSLVERR, apbif.PRDATA};

        case (apb_state)
            APB_IDLE: begin
                if (!fwd_rempty) begin
                    apbif.PSEL    = 1'b1;
                    apbif.PADDR   = apb_req_addr;
                    apbif.PWDATA  = apb_req_wdata;
                    apbif.PWRITE  = apb_req_write;
                    apbif.PSTRB   = apb_req_strb;
                    apb_next      = APB_SETUP;
                end
            end
            
            APB_SETUP: begin
                apbif.PSEL    = 1'b1;
                apbif.PENABLE = 1'b0;
                apbif.PADDR   = apb_req_addr;
                apbif.PWDATA  = apb_req_wdata;
                apbif.PWRITE  = apb_req_write;
                apbif.PSTRB   = apb_req_strb;
                apb_next      = APB_ACCESS;
            end
            
            APB_ACCESS: begin
                apbif.PSEL    = 1'b1;
                apbif.PENABLE = 1'b1;
                apbif.PADDR   = apb_req_addr;
                apbif.PWDATA  = apb_req_wdata;
                apbif.PWRITE  = apb_req_write;
                apbif.PSTRB   = apb_req_strb;
                
                if (apbif.PREADY) begin
                    ret_winc = 1'b1;
                    fwd_rinc = 1'b1;
                    apb_next = APB_IDLE;
                end
            end
        endcase
    end

endmodule
