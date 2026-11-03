module i2c_regs (
    input  logic PCLK,
    input  logic PRESETn,
    bus_protocol_if.peripheral_vital bus,
    
    // Engine interface
    output logic        cmd_valid,
    output logic        cmd_start,
    output logic        cmd_stop,
    output logic        cmd_write,
    output logic        cmd_read,
    output logic        cmd_nack,
    output logic [7:0]  tx_data,
    output logic [15:0] prescale,
    output logic        enable,
    
    input  logic        tip,
    input  logic        bus_busy,
    input  logic        rx_nack,
    input  logic [7:0]  rx_data,
    
    output logic        irq
);

    logic [31:0] ctrl_reg, ctrl_reg_next;
    logic [31:0] prescale_reg, prescale_reg_next;
    logic [31:0] txdata_reg, txdata_reg_next;
    logic        done, done_next;

    logic irq_en;
    logic tip_q, tip_q_next;
    logic tip_fell;

    // verilator lint_off UNUSED
    logic [31:0] unused_addr;
    assign unused_addr = bus.addr;
    // verilator lint_on UNUSED

    assign enable   = ctrl_reg[0];
    assign irq_en   = ctrl_reg[1];
    assign prescale = prescale_reg[15:0];
    assign tx_data  = txdata_reg[7:0];

    always_comb begin
        tip_q_next = tip;
    end

    assign tip_fell = tip_q & ~tip;

    logic err;
    always_comb begin
        err = 1'b0;
        if (bus.ren) begin
            if (bus.addr[4:2] == 3'b100) err = 1'b1; // read of CMD
        end else if (bus.wen) begin
            if (bus.addr[4:2] == 3'b011) err = 1'b1; // write to RXDATA
            else if (bus.addr[4:2] == 3'b100) begin  // write to CMD
                if (tip || !enable) err = 1'b1;
                if (bus.strobe[0]) begin
                    if (bus.wdata[2] && bus.wdata[3]) err = 1'b1; // WRITE and READ
                    if (!(bus.wdata[0] || bus.wdata[1] || bus.wdata[2] || bus.wdata[3])) err = 1'b1; // None set
                end
            end else if (bus.addr[4:2] == 3'b000 || bus.addr[4:2] == 3'b001 || bus.addr[4:2] == 3'b010) begin
                if (tip) err = 1'b1; // write while TIP
                if (bus.addr[4:2] == 3'b001) begin
                    logic [15:0] nxt_pre;
                    nxt_pre[7:0]  = bus.strobe[0] ? bus.wdata[7:0]  : prescale_reg[7:0];
                    nxt_pre[15:8] = bus.strobe[1] ? bus.wdata[15:8] : prescale_reg[15:8];
                    if (nxt_pre < 16'd3) err = 1'b1;
                end
            end
        end
    end

    assign bus.error = err & (bus.wen | bus.ren);
    assign bus.request_stall = 1'b0;

    always_comb begin
        ctrl_reg_next     = ctrl_reg;
        prescale_reg_next = prescale_reg;
        txdata_reg_next   = txdata_reg;
        done_next         = done;

        // Clear DONE if requested
        if (bus.wen && (bus.addr[4:2] == 3'b101) && bus.strobe[0] && bus.wdata[3] && !bus.error) begin
            done_next = 1'b0;
        end
        
        // Set DONE on TIP falling
        if (tip_fell) begin
            done_next = 1'b1;
        end

        if (bus.wen && !bus.error) begin
            case (bus.addr[4:2])
                3'b000: begin // CTRL
                    if (bus.strobe[0]) ctrl_reg_next[1:0] = bus.wdata[1:0];
                end
                3'b001: begin // PRESCALE
                    if (bus.strobe[0]) prescale_reg_next[7:0]  = bus.wdata[7:0];
                    if (bus.strobe[1]) prescale_reg_next[15:8] = bus.wdata[15:8];
                end
                3'b010: begin // TXDATA
                    if (bus.strobe[0]) txdata_reg_next[7:0] = bus.wdata[7:0];
                end
                default: ;
            endcase
        end
    end

    // Registers
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ctrl_reg     <= 32'h0;
            prescale_reg <= 32'h3;
            txdata_reg   <= 32'h0;
            done         <= 1'b0;
            tip_q        <= 1'b0;
        end else begin
            ctrl_reg     <= ctrl_reg_next;
            prescale_reg <= prescale_reg_next;
            txdata_reg   <= txdata_reg_next;
            done         <= done_next;
            tip_q        <= tip_q_next;
        end
    end

    // Read Data
    logic [31:0] rdata;
    always_comb begin
        rdata = 32'h0;
        if (bus.ren && !bus.error) begin
            case (bus.addr[4:2])
                3'b000: rdata = ctrl_reg;
                3'b001: rdata = prescale_reg;
                3'b010: rdata = txdata_reg;
                3'b011: rdata = {24'h0, rx_data};
                3'b101: rdata = {28'h0, done, rx_nack, bus_busy, tip};
                default: rdata = 32'h0;
            endcase
        end
    end
    assign bus.rdata = rdata;

    // CMD output
    assign cmd_valid = (bus.wen && bus.addr[4:2] == 3'b100 && bus.strobe[0] && !bus.error);
    assign cmd_start = cmd_valid ? bus.wdata[0] : 1'b0;
    assign cmd_stop  = cmd_valid ? bus.wdata[1] : 1'b0;
    assign cmd_write = cmd_valid ? bus.wdata[2] : 1'b0;
    assign cmd_read  = cmd_valid ? bus.wdata[3] : 1'b0;
    assign cmd_nack  = cmd_valid ? bus.wdata[4] : 1'b0;

    assign irq = done & irq_en;

endmodule
