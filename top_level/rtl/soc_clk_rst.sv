module soc_clk_rst (
    input  logic ext_clk_i,
    input  logic ext_rst_n_i,
    output logic hclk_o,
    output logic hresetn_o,
    output logic pclk_o,
    output logic presetn_o
);

    // HCLK is directly the external clock
    assign hclk_o = ext_clk_i;

    // PCLK = HCLK / 8
    logic [2:0] clk_div;
    logic pclk_reg;
    
    always_ff @(posedge ext_clk_i or negedge ext_rst_n_i) begin
        if (!ext_rst_n_i) begin
            clk_div <= 3'd0;
            pclk_reg <= 1'b0;
        end else begin
            if (clk_div == 3'd3) begin
                clk_div <= 3'd0;
                pclk_reg <= ~pclk_reg;
            end else begin
                clk_div <= clk_div + 1'b1;
            end
        end
    end
    assign pclk_o = pclk_reg;

    // Reset synchronization
    // Deassertion is synchronized separately to each domain (TOP-RST-001)
    
    // HCLK domain reset sync
    logic hreset_q1, hreset_q2;
    always_ff @(posedge ext_clk_i or negedge ext_rst_n_i) begin
        if (!ext_rst_n_i) begin
            hreset_q1 <= 1'b0;
            hreset_q2 <= 1'b0;
        end else begin
            hreset_q1 <= 1'b1;
            hreset_q2 <= hreset_q1;
        end
    end
    assign hresetn_o = hreset_q2;

    // PCLK domain reset sync
    logic preset_q1, preset_q2;
    always_ff @(posedge pclk_reg or negedge ext_rst_n_i) begin
        if (!ext_rst_n_i) begin
            preset_q1 <= 1'b0;
            preset_q2 <= 1'b0;
        end else begin
            preset_q1 <= 1'b1;
            preset_q2 <= preset_q1;
        end
    end
    assign presetn_o = preset_q2;

endmodule
