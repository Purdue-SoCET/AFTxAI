`default_nettype none

module pwm_core #(
    parameter int PWM_CHANNELS = 4,
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32
) (
    input  wire  pclk,
    input  wire  presetn,

    // APB4 interface
    input  wire  [ADDR_WIDTH-1:0]   paddr,
    input  wire                     psel,
    input  wire                     penable,
    input  wire                     pwrite,
    input  wire  [DATA_WIDTH-1:0]   pwdata,
    input  wire  [(DATA_WIDTH/8)-1:0] pstrb,
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire  [2:0]              pprot,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [DATA_WIDTH-1:0]   prdata,
    output logic                    pready,
    output logic                    pslverr,

    // PWM external outputs
    output logic [PWM_CHANNELS-1:0] pwm_out_o,
    output logic [PWM_CHANNELS-1:0] pwm_oe_o,
    output logic                    irq_o
);

    // Initial validation of parameters
    // synthesis translate_off
    initial begin
        if (PWM_CHANNELS < 1 || PWM_CHANNELS > 4) begin
            $error("PWM_CHANNELS must be between 1 and 4. Got %0d", PWM_CHANNELS);
            $fatal(1);
        end
    end
    // synthesis translate_on

    localparam int MAX_CHANNELS = 4;

    // Registers
    logic [MAX_CHANNELS-1:0] irq_enable;
    logic [MAX_CHANNELS-1:0] irq_pending;
    
    // Per-channel registers
    logic [MAX_CHANNELS-1:0] ch_en;
    logic [MAX_CHANNELS-1:0] ch_polarity;
    
    logic [31:0] ch_shadow_period [MAX_CHANNELS];
    logic [31:0] ch_shadow_duty [MAX_CHANNELS];
    logic [15:0] ch_shadow_prescale [MAX_CHANNELS];
    
    logic [31:0] ch_active_period [MAX_CHANNELS];
    logic [31:0] ch_active_duty [MAX_CHANNELS];
    logic [15:0] ch_active_prescale [MAX_CHANNELS];
    
    logic [MAX_CHANNELS-1:0] ch_update_pending;
    logic [31:0] ch_phase [MAX_CHANNELS];
    logic [15:0] ch_prescale_phase [MAX_CHANNELS];

    // Read/write logic
    logic access;
    logic valid_write;
    
    assign access = psel && penable;
    assign pready = 1'b1; // Zero wait states
    assign valid_write = access && pwrite && !pslverr;

    // Address decode
    logic [3:0] decoded_ch;
    logic is_channel_addr;
    logic is_global_addr;
    logic [11:0] offset;
    
    assign offset = paddr[11:0];
    assign is_channel_addr = (offset < 12'h100);
    assign decoded_ch = offset[8:5]; // stride 0x20 is 32 bytes (offset >> 5)
    assign is_global_addr = (offset >= 12'h100 && offset < 12'h10C);

    logic addr_aligned;
    assign addr_aligned = (paddr[1:0] == 2'b00);

    logic valid_channel;
    assign valid_channel = (decoded_ch < PWM_CHANNELS);

    // Read logic (combinational)
    always_comb begin
        prdata = '0;
        pslverr = '0;
        
        if (psel) begin
            if (!addr_aligned) begin
                pslverr = 1'b1;
            end else if (!pwrite && pstrb != '0) begin // PWM-APB-004
                pslverr = 1'b1;
            end else if (is_channel_addr) begin
                if (!valid_channel) begin
                    pslverr = 1'b1;
                end else begin
                    case (offset[4:0])
                        5'h00: if (!pwrite) prdata = {30'd0, ch_polarity[decoded_ch], ch_en[decoded_ch]};
                        5'h04: if (!pwrite) prdata = ch_shadow_period[decoded_ch];
                        5'h08: if (!pwrite) prdata = ch_shadow_duty[decoded_ch];
                        5'h0C: if (!pwrite) prdata = {16'd0, ch_shadow_prescale[decoded_ch]};
                        5'h10: if (!pwrite) pslverr = 1'b1; // WO
                        5'h14: if (!pwrite) prdata = {28'd0, pwm_out_o[decoded_ch], pwm_oe_o[decoded_ch], ch_en[decoded_ch], ch_update_pending[decoded_ch]};
                               else pslverr = 1'b1; // RO
                        5'h18: if (!pwrite) prdata = ch_phase[decoded_ch];
                               else pslverr = 1'b1; // RO
                        default: pslverr = 1'b1; // Invalid / reserved offset
                    endcase
                end
            end else if (offset == 12'h100) begin
                if (!pwrite) prdata = { {(32-MAX_CHANNELS){1'b0}}, irq_enable };
            end else if (offset == 12'h104) begin
                if (!pwrite) prdata = { {(32-MAX_CHANNELS){1'b0}}, irq_pending };
            end else if (offset == 12'h108) begin
                if (!pwrite) prdata = { 16'h5057, 8'h01, 8'(PWM_CHANNELS) };
                else pslverr = 1'b1; // RO
            end else begin
                pslverr = 1'b1; // Invalid global address
            end

            // Check for shadow write while pending
            if (pwrite && !pslverr && is_channel_addr && valid_channel && pstrb != '0) begin
                if (ch_update_pending[decoded_ch]) begin
                    if (offset[4:0] == 5'h04 || offset[4:0] == 5'h08 || offset[4:0] == 5'h0C) begin
                        pslverr = 1'b1; // PWM-UPD-001
                    end
                end
            end
            
            // Check for invalid polarity change while EN=1
            if (pwrite && !pslverr && is_channel_addr && valid_channel && offset[4:0] == 5'h00) begin
                if (ch_en[decoded_ch] && pstrb[0]) begin
                    if ((pwdata[1] ^ ch_polarity[decoded_ch]) != 0) begin
                        pslverr = 1'b1; // PWM-TIME-007
                    end
                end
                // check EN 0->1 validation
                if (!ch_en[decoded_ch] && pstrb[0] && pwdata[0]) begin
                    if (ch_shadow_period[decoded_ch] == 0 || ch_shadow_duty[decoded_ch] > ch_shadow_period[decoded_ch]) begin
                        pslverr = 1'b1; // PWM-UPD-007
                    end
                end
            end

            // Check for invalid ARM
            if (pwrite && !pslverr && is_channel_addr && valid_channel && offset[4:0] == 5'h10) begin
                if (pstrb[0] && pwdata[0]) begin
                    if (ch_update_pending[decoded_ch] || ch_shadow_period[decoded_ch] == 0 || ch_shadow_duty[decoded_ch] > ch_shadow_period[decoded_ch]) begin
                        pslverr = 1'b1; // PWM-UPD-002, PWM-UPD-007
                    end
                end
            end
            
            // Check for invalid enable or polarity change
            if (pwrite && !pslverr && is_channel_addr && valid_channel && offset[4:0] == 5'h00) begin
                if (pstrb[0]) begin
                    if (pwdata[0] && !ch_en[decoded_ch]) begin
                        if (ch_shadow_period[decoded_ch] == 0 || ch_shadow_duty[decoded_ch] > ch_shadow_period[decoded_ch]) begin
                            pslverr = 1'b1;
                        end
                    end else if (ch_en[decoded_ch] && pwdata[1] != ch_polarity[decoded_ch]) begin
                        pslverr = 1'b1;
                    end
                end
            end
        end
    end

    // Helper macro for byte strobes
    `define STROBE_UPDATE(reg_val, wr_data, strb)         begin             if (strb[0]) reg_val[7:0]   <= wr_data[7:0];             if (strb[1]) reg_val[15:8]  <= wr_data[15:8];             if (strb[2]) reg_val[23:16] <= wr_data[23:16];             if (strb[3]) reg_val[31:24] <= wr_data[31:24];         end

    // Combinational boundary events
    logic [MAX_CHANNELS-1:0] boundary_events;
    logic [MAX_CHANNELS-1:0] c_write_disable;
    always_comb begin
        for (int i = 0; i < MAX_CHANNELS; i++) begin
            boundary_events[i] = 1'b0;
            c_write_disable[i] = 1'b0;
            if (i < PWM_CHANNELS) begin
                c_write_disable[i] = valid_write && is_channel_addr && (decoded_ch == i) && (offset[4:0] == 5'h00) && pstrb[0] && !pwdata[0];
                if (ch_en[i] && !c_write_disable[i]) begin
                    if (ch_prescale_phase[i] == ch_active_prescale[i]) begin
                        if (ch_phase[i] == ch_active_period[i] - 1) begin
                            boundary_events[i] = 1'b1;
                        end
                    end
                end
            end
        end
    end

    // Sequential logic
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            irq_enable <= '0;
            irq_pending <= '0;
            irq_o <= 1'b0;
            pwm_out_o <= '0;
            pwm_oe_o <= '0;
            ch_en <= '0;
            ch_polarity <= '0;
            ch_update_pending <= '0;
            for (int i = 0; i < MAX_CHANNELS; i++) begin
                ch_shadow_period[i] <= 32'd1;
                ch_shadow_duty[i] <= 32'd0;
                ch_shadow_prescale[i] <= 16'd0;
                ch_active_period[i] <= 32'd1;
                ch_active_duty[i] <= 32'd0;
                ch_active_prescale[i] <= 16'd0;
                ch_phase[i] <= 32'd0;
                ch_prescale_phase[i] <= 16'd0;
            end
        end else begin
            // IRQ Aggregation
            logic [MAX_CHANNELS-1:0] active_irqs;
            for (int i = 0; i < MAX_CHANNELS; i++) begin
                if (i < PWM_CHANNELS)
                    active_irqs[i] = irq_pending[i] & irq_enable[i];
                else
                    active_irqs[i] = 1'b0;
            end
            irq_o <= |active_irqs;

            // Channel processing
            for (int i = 0; i < MAX_CHANNELS; i++) begin
                if (i < PWM_CHANNELS) begin
                    // Evaluate if channel is being explicitly disabled on this cycle
                    logic write_enable;
                    write_enable  = valid_write && is_channel_addr && (decoded_ch == i) && (offset[4:0] == 5'h00) && pstrb[0] && pwdata[0] && !ch_en[i];

                    if (c_write_disable[i] && ch_en[i]) begin
                        // PWM-TIME-006: disable suppresses tick, output=0, oe=0, phase=0, pending=0
                        pwm_out_o[i] <= 1'b0;
                        pwm_oe_o[i] <= 1'b0;
                        ch_phase[i] <= 32'd0;
                        ch_prescale_phase[i] <= 16'd0;
                        ch_en[i] <= 1'b0;
                        ch_update_pending[i] <= 1'b0;
                        if (pstrb[0]) ch_polarity[i] <= pwdata[1];
                    end else if (ch_en[i]) begin
                        // Active ticking
                        if (ch_prescale_phase[i] == ch_active_prescale[i]) begin
                            ch_prescale_phase[i] <= 16'd0;
                            if (ch_phase[i] == ch_active_period[i] - 1) begin
                                // Boundary tick
                                ch_phase[i] <= 32'd0;
                                if (ch_update_pending[i]) begin
                                    ch_active_period[i] <= ch_shadow_period[i];
                                    ch_active_duty[i] <= ch_shadow_duty[i];
                                    ch_active_prescale[i] <= ch_shadow_prescale[i];
                                    ch_update_pending[i] <= 1'b0;
                                    pwm_out_o[i] <= (0 < ch_shadow_duty[i]) ^ ch_polarity[i];
                                end else begin
                                    pwm_out_o[i] <= (0 < ch_active_duty[i]) ^ ch_polarity[i];
                                end
                            end else begin
                                // Normal tick
                                ch_phase[i] <= ch_phase[i] + 1'b1;
                                pwm_out_o[i] <= ((ch_phase[i] + 1'b1) < ch_active_duty[i]) ^ ch_polarity[i];
                            end
                        end else begin
                            ch_prescale_phase[i] <= ch_prescale_phase[i] + 1'b1;
                        end
                        
                        // Handle other writes that occur while enabled
                        if (valid_write && is_channel_addr && (decoded_ch == i)) begin
                            case (offset[4:0])
                                5'h00: if (pstrb[0]) ch_polarity[i] <= pwdata[1]; // Should be prevented by combinational pslverr if changed
                                5'h04: `STROBE_UPDATE(ch_shadow_period[i], pwdata, pstrb)
                                5'h08: `STROBE_UPDATE(ch_shadow_duty[i], pwdata, pstrb)
                                5'h0C: begin
                                    if (pstrb[0]) ch_shadow_prescale[i][7:0] <= pwdata[7:0];
                                    if (pstrb[1]) ch_shadow_prescale[i][15:8] <= pwdata[15:8];
                                end
                                5'h10: if (pstrb[0] && pwdata[0]) ch_update_pending[i] <= 1'b1;
                                default: ;
                            endcase
                        end
                    end else if (write_enable) begin
                        // Enable
                        ch_en[i] <= 1'b1;
                        ch_polarity[i] <= pwdata[1];
                        ch_active_period[i] <= ch_shadow_period[i];
                        ch_active_duty[i] <= ch_shadow_duty[i];
                        ch_active_prescale[i] <= ch_shadow_prescale[i];
                        ch_update_pending[i] <= 1'b0;
                        ch_phase[i] <= 32'd0;
                        ch_prescale_phase[i] <= 16'd0;
                        pwm_oe_o[i] <= 1'b1;
                        pwm_out_o[i] <= (0 < ch_shadow_duty[i]) ^ pwdata[1];
                    end else begin
                        // Disabled and not being enabled
                        pwm_out_o[i] <= 1'b0;
                        pwm_oe_o[i] <= 1'b0;
                        ch_phase[i] <= 32'd0;
                        ch_prescale_phase[i] <= 16'd0;
                        
                        if (valid_write && is_channel_addr && (decoded_ch == i)) begin
                            case (offset[4:0])
                                5'h00: if (pstrb[0]) ch_polarity[i] <= pwdata[1];
                                5'h04: `STROBE_UPDATE(ch_shadow_period[i], pwdata, pstrb)
                                5'h08: `STROBE_UPDATE(ch_shadow_duty[i], pwdata, pstrb)
                                5'h0C: begin
                                    if (pstrb[0]) ch_shadow_prescale[i][7:0] <= pwdata[7:0];
                                    if (pstrb[1]) ch_shadow_prescale[i][15:8] <= pwdata[15:8];
                                end
                                5'h10: begin
                                    if (pstrb[0] && pwdata[0]) begin
                                        ch_active_period[i] <= ch_shadow_period[i];
                                        ch_active_duty[i] <= ch_shadow_duty[i];
                                        ch_active_prescale[i] <= ch_shadow_prescale[i];
                                        ch_update_pending[i] <= 1'b0;
                                    end
                                end
                                default: ;
                            endcase
                        end
                    end
                end
            end

            // Global register writes
            if (valid_write && is_global_addr) begin
                if (offset == 12'h100) begin
                    if (pstrb[0]) irq_enable <= pwdata[MAX_CHANNELS-1:0];
                end
            end

            // IRQ Pending update (HW set overrides W1C)
            for (int i = 0; i < MAX_CHANNELS; i++) begin
                if (i < PWM_CHANNELS) begin
                    logic w1c;
                    w1c = valid_write && is_global_addr && (offset == 12'h104) && pstrb[0] && pwdata[i];
                    
                    if (boundary_events[i]) begin
                        irq_pending[i] <= 1'b1;
                    end else if (w1c) begin
                        irq_pending[i] <= 1'b0;
                    end
                end
            end
            
            // Mask unused bits of global registers
            for (int i = PWM_CHANNELS; i < MAX_CHANNELS; i++) begin
                irq_enable[i] <= 1'b0;
                irq_pending[i] <= 1'b0;
                ch_en[i] <= 1'b0;
            end
        end
    end

endmodule
`default_nettype wire
