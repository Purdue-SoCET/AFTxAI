module gpio_apb #(
    parameter int GPIO_WIDTH = 32
) (
    // APB4 completer interface
    input  logic        pclk,
    input  logic        presetn,
    input  logic [7:0]  paddr,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] pwdata,
    input  logic [3:0]  pstrb,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  pprot,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    // Physical pin interface (to I/O mux)
    input  logic [GPIO_WIDTH-1:0] gpio_in_i,
    output logic [GPIO_WIDTH-1:0] gpio_out_o,
    output logic [GPIO_WIDTH-1:0] gpio_oe_o,
    output logic [GPIO_WIDTH-1:0] gpio_pull_up_o,
    output logic [GPIO_WIDTH-1:0] gpio_pull_down_o,
    
    // Interrupt
    output logic        irq_o
);

    // Ensure valid parameter
    initial begin
        if (GPIO_WIDTH < 1 || GPIO_WIDTH > 32) begin
            $error("GPIO_WIDTH must be between 1 and 32");
            $fatal;
        end
    end

    // Active pin mask
    localparam logic [31:0] ACTIVE_MASK = (GPIO_WIDTH == 32) ? 32'hFFFF_FFFF : (1 << GPIO_WIDTH) - 1;

    // Registers
    logic [31:0] data_out;
    logic [31:0] dir;
    logic [31:0] pull_up;
    logic [31:0] pull_down;
    logic [31:0] open_drain;
    
    logic [31:0] irq_rise_en;
    logic [31:0] irq_fall_en;
    logic [31:0] irq_high_en;
    logic [31:0] irq_low_en;
    
    logic [31:0] irq_rise_pending;
    logic [31:0] irq_fall_pending;

    // Synchronized inputs
    logic [GPIO_WIDTH-1:0] sync_in;
    logic [31:0] data_in_reg;

    sync_2ff #(
        .WIDTH(GPIO_WIDTH)
    ) i_sync (
        .clk  (pclk),
        .rst_n(presetn),
        .d_in (gpio_in_i),
        .d_out(sync_in)
    );

    assign data_in_reg = {{(32-GPIO_WIDTH){1'b0}}, sync_in};

    // Edge detection
    logic [31:0] prev_sync_in;
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prev_sync_in <= '0;
        end else begin
            prev_sync_in <= data_in_reg;
        end
    end

    // Detect initialization state after reset to suppress false edges
    logic sync_valid;
    logic [1:0] reset_startup_cnt;
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            sync_valid <= 1'b0;
            reset_startup_cnt <= '0;
        end else begin
            if (reset_startup_cnt < 2'd2) begin
                reset_startup_cnt <= reset_startup_cnt + 1'b1;
            end else begin
                sync_valid <= 1'b1;
            end
        end
    end

    logic [31:0] rise_event;
    logic [31:0] fall_event;
    assign rise_event = sync_valid ? (data_in_reg & ~prev_sync_in) : '0;
    assign fall_event = sync_valid ? (~data_in_reg & prev_sync_in) : '0;

    // Level status
    logic [31:0] irq_level_status;
    assign irq_level_status = (data_in_reg & irq_high_en) | (~data_in_reg & irq_low_en);

    // Aggregate IRQ status
    logic [31:0] irq_status;
    assign irq_status = irq_level_status | (irq_rise_pending & irq_rise_en) | (irq_fall_pending & irq_fall_en);

    assign irq_o = |(irq_status & ACTIVE_MASK);

    // APB Write/Read Control
    logic apb_write_req;
    assign apb_write_req = psel && penable && pwrite;
    
    // Address Decoding
    logic [31:0] gpio_info;
    assign gpio_info = {21'd0, 1'b1, 1'b1, 1'b1, 8'(GPIO_WIDTH)};
    
    logic [31:0] prdata_nxt;
    logic pslverr_nxt;

    // APB Completer always ready
    assign pready = 1'b1;

    // Expand write strobes
    logic [31:0] wmask;
    assign wmask = {{8{pstrb[3]}}, {8{pstrb[2]}}, {8{pstrb[1]}}, {8{pstrb[0]}}};
    logic [31:0] masked_wdata;
    assign masked_wdata = pwdata & wmask & ACTIVE_MASK;

    always_comb begin
        prdata_nxt = '0;
        pslverr_nxt = 1'b0;

        if (psel && penable) begin
            if (paddr[1:0] != 2'b00) begin
                pslverr_nxt = 1'b1;
            end else if (pwrite) begin
                if (pstrb == 4'b0000) begin
                    // Valid no-op
                end else begin
                    case (paddr)
                        8'h04, 8'h08, 8'h0C, 8'h10, 8'h14, 8'h20,
                        8'h24, 8'h28, 8'h2C, 8'h30, 8'h34, 8'h38: pslverr_nxt = 1'b0;
                        8'h18: pslverr_nxt = ((((pull_up & ~wmask) | masked_wdata) & pull_down) != 0);
                        8'h1C: pslverr_nxt = ((((pull_down & ~wmask) | masked_wdata) & pull_up) != 0);
                        8'h00, 8'h3C, 8'h40, 8'h44: pslverr_nxt = 1'b1; // RO
                        default: pslverr_nxt = 1'b1;
                    endcase
                end
            end else begin // read
                if (pstrb != 4'b0000) begin
                    pslverr_nxt = 1'b1; // Requester must drive pstrb=0 on reads, but even if we don't strictly error on this, let's just ignore it or error. Spec: "The APB4 requester must drive pstrb=0 on reads; assertions must check this...". Wait, it says "Access to a read-only register as a write, or to a write-only register as a read, must error". Let's error on WO reads and unmapped.
                end
                
                case (paddr)
                    8'h00: prdata_nxt = data_in_reg;
                    8'h04: prdata_nxt = data_out;
                    8'h08: prdata_nxt = dir;
                    8'h18: prdata_nxt = pull_up;
                    8'h1C: prdata_nxt = pull_down;
                    8'h20: prdata_nxt = open_drain;
                    8'h24: prdata_nxt = irq_rise_en;
                    8'h28: prdata_nxt = irq_fall_en;
                    8'h2C: prdata_nxt = irq_high_en;
                    8'h30: prdata_nxt = irq_low_en;
                    8'h34: prdata_nxt = irq_rise_pending;
                    8'h38: prdata_nxt = irq_fall_pending;
                    8'h3C: prdata_nxt = irq_level_status;
                    8'h40: prdata_nxt = irq_status;
                    8'h44: prdata_nxt = gpio_info;
                    8'h0C, 8'h10, 8'h14: pslverr_nxt = 1'b1; // WO reads error
                    default: pslverr_nxt = 1'b1;
                endcase
            end
        end
    end

    assign prdata = (psel && penable && !pwrite && !pslverr_nxt) ? prdata_nxt : '0;
    assign pslverr = (psel && penable) ? pslverr_nxt : 1'b0;

    // Register writes and pending flag updates
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            data_out <= '0;
            dir <= '0;
            pull_up <= '0;
            pull_down <= '0;
            open_drain <= '0;
            irq_rise_en <= '0;
            irq_fall_en <= '0;
            irq_high_en <= '0;
            irq_low_en <= '0;
            irq_rise_pending <= '0;
            irq_fall_pending <= '0;
        end else begin
            // IRQ pending edge capture (independent of enables)
            irq_rise_pending <= (irq_rise_pending | rise_event) & ACTIVE_MASK;
            irq_fall_pending <= (irq_fall_pending | fall_event) & ACTIVE_MASK;

            if (apb_write_req && !pslverr_nxt) begin
                case (paddr)
                    8'h04: data_out <= (data_out & ~wmask) | masked_wdata;
                    8'h08: dir <= (dir & ~wmask) | masked_wdata;
                    8'h0C: data_out <= (data_out | masked_wdata); // OUT_SET
                    8'h10: data_out <= (data_out & ~masked_wdata); // OUT_CLEAR
                    8'h14: data_out <= (data_out ^ masked_wdata); // OUT_TOGGLE
                    8'h18: pull_up <= (pull_up & ~wmask) | masked_wdata;
                    8'h1C: pull_down <= (pull_down & ~wmask) | masked_wdata;
                    8'h20: open_drain <= (open_drain & ~wmask) | masked_wdata;
                    8'h24: irq_rise_en <= (irq_rise_en & ~wmask) | masked_wdata;
                    8'h28: irq_fall_en <= (irq_fall_en & ~wmask) | masked_wdata;
                    8'h2C: irq_high_en <= (irq_high_en & ~wmask) | masked_wdata;
                    8'h30: irq_low_en <= (irq_low_en & ~wmask) | masked_wdata;
                    8'h34: irq_rise_pending <= ((irq_rise_pending & ~masked_wdata) | rise_event) & ACTIVE_MASK; // RW1C, SET wins
                    8'h38: irq_fall_pending <= ((irq_fall_pending & ~masked_wdata) | fall_event) & ACTIVE_MASK; // RW1C, SET wins
                    default: ;
                endcase
            end
        end
    end

    // Output assignments
    for (genvar i = 0; i < GPIO_WIDTH; i++) begin : gen_outputs
        assign gpio_oe_o[i] = dir[i] & !(open_drain[i] & data_out[i]);
        assign gpio_out_o[i] = open_drain[i] ? 1'b0 : data_out[i];
    end

    assign gpio_pull_up_o = pull_up[GPIO_WIDTH-1:0];
    assign gpio_pull_down_o = pull_down[GPIO_WIDTH-1:0];

endmodule
