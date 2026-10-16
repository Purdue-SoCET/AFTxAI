module timer_apb (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [12:0] paddr,
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
    input  logic        capture_i,
    output logic        irq_o
);

    // Register state
    logic [31:0] control_reg;
    logic [31:0] count_reg;
    logic [31:0] period_reg;
    logic [15:0] prescale_reg;
    logic [3:0]  irq_enable_reg;
    logic [3:0]  irq_pending_reg;
    logic [31:0] capture_value_reg;

    // Control fields
    logic control_en;
    logic [1:0] control_mode;
    logic control_cap_en;
    logic [1:0] control_cap_edge;

    assign control_en = control_reg[0];
    assign control_mode = control_reg[2:1];
    assign control_cap_en = control_reg[3];
    assign control_cap_edge = control_reg[5:4];

    // Prescale phase
    logic [15:0] prescale_phase;

    // Capture synchronizer and edge detection
    logic capture_sync;
    logic capture_sync_d1;
    logic [1:0] capture_reset_count;
    logic capture_baseline_valid;

    sync_2ff #(.WIDTH(1)) u_sync_capture (
        .clk(pclk),
        .rst_n(presetn),
        .d_in(capture_i),
        .d_out(capture_sync)
    );

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            capture_reset_count <= 2'd0;
            capture_sync_d1 <= 1'b0;
        end else begin
            if (capture_reset_count != 2'd3) begin
                capture_reset_count <= capture_reset_count + 1'b1;
            end
            capture_sync_d1 <= capture_sync;
        end
    end
    assign capture_baseline_valid = (capture_reset_count == 2'd3);

    logic cap_event;
    always_comb begin
        cap_event = 1'b0;
        if (capture_baseline_valid && control_en && control_cap_en) begin
            if (control_cap_edge == 2'b00 && capture_sync && !capture_sync_d1) cap_event = 1'b1;
            if (control_cap_edge == 2'b01 && !capture_sync && capture_sync_d1) cap_event = 1'b1;
            if (control_cap_edge == 2'b10 && (capture_sync != capture_sync_d1)) cap_event = 1'b1;
        end
    end

    // APB Decoding
    logic access;
    assign access = psel && penable;

    logic addr_valid;
    assign addr_valid = (paddr[12:5] == 8'h00) && (
        paddr[4:0] == 5'h00 || paddr[4:0] == 5'h04 || paddr[4:0] == 5'h08 ||
        paddr[4:0] == 5'h0c || paddr[4:0] == 5'h10 || paddr[4:0] == 5'h14 ||
        paddr[4:0] == 5'h18 || paddr[4:0] == 5'h1c
    );

    logic is_read, is_write;
    assign is_read  = psel && !pwrite;
    assign is_write = psel && pwrite;

    logic [31:0] wmask;
    assign wmask = {{8{pstrb[3]}}, {8{pstrb[2]}}, {8{pstrb[1]}}, {8{pstrb[0]}}};

    logic read_error, write_error;
    assign read_error = is_read && (!addr_valid || (|paddr[1:0]) || (pstrb != 4'h0));

    logic invalid_write_data;
    
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] new_control;
    /* verilator lint_on UNUSEDSIGNAL */
    assign new_control = (control_reg & ~wmask) | (pwdata & wmask);
    
    always_comb begin
        write_error = 1'b0;
        invalid_write_data = 1'b0;

        if (is_write) begin
            if (!addr_valid || (|paddr[1:0])) begin
                write_error = 1'b1;
            end else if (paddr[4:0] == 5'h18 || paddr[4:0] == 5'h1c) begin // RO registers
                write_error = 1'b1;
            end else if (paddr[4:0] == 5'h00) begin
                // CONTROL write
                if (new_control[2:1] == 2'b11 || new_control[5:4] == 2'b11) begin
                    invalid_write_data = 1'b1;
                end
                if (control_en) begin
                    if ((new_control[5:1] != control_reg[5:1])) begin
                        invalid_write_data = 1'b1;
                    end
                end
                if (!control_en && new_control[0]) begin
                    if (new_control[2:1] != 2'b10 && (count_reg > period_reg)) begin
                        invalid_write_data = 1'b1;
                    end
                end
                if (invalid_write_data) write_error = 1'b1;
            end else if (paddr[4:0] == 5'h04 || paddr[4:0] == 5'h08 || paddr[4:0] == 5'h0c) begin
                if (control_en && pstrb != 4'h0) begin
                    write_error = 1'b1;
                end
            end
        end
    end

    logic valid_write_commit;
    assign valid_write_commit = access && is_write && !write_error;

    // Timer Disable Req
    logic timer_disable_req;
    assign timer_disable_req = valid_write_commit && (paddr[4:0] == 5'h00) && (!new_control[0]) && control_en;

    // Tick Logic
    logic tick;
    assign tick = control_en && (prescale_phase == prescale_reg) && !timer_disable_req;

    // Next State Logic
    logic [31:0] count_next;
    logic match_event, wrap_event;
    logic auto_clear_en;

    always_comb begin
        count_next = count_reg;
        match_event = 1'b0;
        wrap_event = 1'b0;
        auto_clear_en = 1'b0;

        if (tick) begin
            if (control_mode == 2'b00) begin // Periodic
                if (count_reg == period_reg) begin
                    match_event = 1'b1;
                    count_next = 32'd0;
                end else begin
                    count_next = count_reg + 1'b1;
                end
            end else if (control_mode == 2'b01) begin // One-shot
                if (count_reg == period_reg) begin
                    match_event = 1'b1;
                    count_next = period_reg;
                    auto_clear_en = 1'b1;
                end else begin
                    count_next = count_reg + 1'b1;
                end
            end else if (control_mode == 2'b10) begin // Free-running
                if (count_reg == period_reg) match_event = 1'b1;
                if (count_reg == 32'hFFFF_FFFF) begin
                    wrap_event = 1'b1;
                    count_next = 32'd0;
                end else begin
                    count_next = count_reg + 1'b1;
                end
            end
        end
    end

    // Pending events (Hardware sets beat W1C)
    logic [3:0] hw_set_events;
    logic cap_overrun_event;
    
    assign cap_overrun_event = cap_event && irq_pending_reg[2];
    assign hw_set_events[0] = match_event;
    assign hw_set_events[1] = wrap_event;
    assign hw_set_events[2] = cap_event; 
    assign hw_set_events[3] = cap_overrun_event;

    logic [3:0] valid_w1c_mask;
    assign valid_w1c_mask = (valid_write_commit && paddr[4:0] == 5'h14) ? (pwdata[3:0] & wmask[3:0]) : 4'd0;

    // Registers FF
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            control_reg       <= 32'd0;
            count_reg         <= 32'd0;
            period_reg        <= 32'hFFFF_FFFF;
            prescale_reg      <= 16'd0;
            irq_enable_reg    <= 4'd0;
            irq_pending_reg   <= 4'd0;
            capture_value_reg <= 32'd0;
            prescale_phase    <= 16'd0;
        end else begin
            // IRQ Pending update
            irq_pending_reg <= (irq_pending_reg & ~valid_w1c_mask) | hw_set_events;

            // Capture logic
            if (cap_event && !irq_pending_reg[2]) begin
                capture_value_reg <= count_reg;
            end

            // Phase and Count logic
            if (control_en) begin
                if (timer_disable_req) begin
                    prescale_phase <= 16'd0;
                end else if (auto_clear_en) begin
                    prescale_phase <= 16'd0; 
                end else if (tick) begin
                    prescale_phase <= 16'd0;
                end else begin
                    prescale_phase <= prescale_phase + 1'b1;
                end
            end else if (valid_write_commit && paddr[4:0] == 5'h00 && new_control[0]) begin
                prescale_phase <= 16'd0;
            end

            // Counter Update
            count_reg <= count_next;

            // APB Writes
            if (valid_write_commit) begin
                if (paddr[4:0] == 5'h00) begin
                    control_reg <= (control_reg & ~wmask) | (pwdata & {26'd0, 6'h3F} & wmask);
                end
                if (paddr[4:0] == 5'h04) begin
                    count_reg <= (count_reg & ~wmask) | (pwdata & wmask);
                end
                if (paddr[4:0] == 5'h08) begin
                    period_reg <= (period_reg & ~wmask) | (pwdata & wmask);
                end
                if (paddr[4:0] == 5'h0c) begin
                    prescale_reg <= (prescale_reg & ~wmask[15:0]) | (pwdata[15:0] & wmask[15:0]);
                end
                if (paddr[4:0] == 5'h10) begin
                    irq_enable_reg <= (irq_enable_reg & ~wmask[3:0]) | (pwdata[3:0] & wmask[3:0]);
                end
            end

            // Auto-clear EN logic override
            if (auto_clear_en) begin
                control_reg[0] <= 1'b0;
            end
        end
    end

    // Outputs
    assign pready = 1'b1;
    assign pslverr = access && (read_error || write_error);
    
    always_comb begin
        prdata = 32'd0;
        if (is_read && !read_error) begin
            case (paddr[4:0])
                5'h00: prdata = control_reg;
                5'h04: prdata = count_reg;
                5'h08: prdata = period_reg;
                5'h0c: prdata = {16'd0, prescale_reg};
                5'h10: prdata = {28'd0, irq_enable_reg};
                5'h14: prdata = {28'd0, irq_pending_reg};
                5'h18: prdata = capture_value_reg;
                5'h1c: prdata = 32'h544D_0101;
                default: prdata = 32'd0;
            endcase
        end
    end

    assign irq_o = |(irq_pending_reg & irq_enable_reg);

endmodule
