`include "bus_protocol_if.sv"
`include "clint_if.sv"

module clint #(
    parameter NUM_HARTS = 1
) (
    input logic CLK,
    input logic nRST,
    bus_protocol_if.peripheral_vital busif,
    clint_if.clint clif
);

    // Memory Map Constants
    localparam logic [31:0] MSWI_BASE_ADDR    = 32'h0,
                            MTIMER_BASE_ADDR  = 32'h4000,
                            MTIMER_TIME_ADDR  = 32'hBFF8,
                            MTIMER_TIMEH_ADDR = 32'hBFFC;
    
    // Per-hart address calculation functions or we can do it inline
    // MTIMER_TIME_ADDR is actually MTIMER_BASE_ADDR + 32'h7FF8 = 32'hBFF8
    
    logic [63:0] mtimefull, mtimefull_next;
    logic [31:0] mtime, mtimeh;
    
    assign mtime = mtimefull[31:0];
    assign mtimeh = mtimefull[63:32];
    
    assign clif.mtime = mtimefull;
    
    logic [NUM_HARTS-1:0] [63:0] mtimecmpfull, mtimecmpfull_next;
    logic [NUM_HARTS-1:0] [31:0] mtimecmp, mtimecmph;
    
    genvar g;
    generate
        for (g = 0; g < NUM_HARTS; g++) begin : gen_mtimecmp
            assign mtimecmp[g]  = mtimecmpfull[g][31:0];
            assign mtimecmph[g] = mtimecmpfull[g][63:32];
        end
    endgenerate
    
    logic [NUM_HARTS-1:0] msip, msip_next, msip_last;
    logic [NUM_HARTS-1:0] timer_int, prev_timer_int;
    
    // Update logic for mtimefull
    always_comb begin
        mtimefull_next = mtimefull + 1;
        if (busif.wen && busif.addr == MTIMER_TIME_ADDR) begin
            mtimefull_next = {mtimefull[63:32], busif.wdata};
        end else if (busif.wen && busif.addr == MTIMER_TIMEH_ADDR) begin
            mtimefull_next = {busif.wdata, mtimefull[31:0]};
        end
    end
    
    // Update logic for per-hart registers
    always_comb begin
        mtimecmpfull_next = mtimecmpfull;
        msip_next = msip;
        
        for (int i = 0; i < NUM_HARTS; i++) begin
            if (busif.wen && busif.addr == (MSWI_BASE_ADDR + 4*i)) begin
                msip_next[i] = busif.wdata[0];
            end
            if (busif.wen && busif.addr == (MTIMER_BASE_ADDR + 8*i)) begin
                mtimecmpfull_next[i] = {mtimecmpfull[i][63:32], busif.wdata};
            end
            if (busif.wen && busif.addr == (MTIMER_BASE_ADDR + 4 + 8*i)) begin
                mtimecmpfull_next[i] = {busif.wdata, mtimecmpfull[i][31:0]};
            end
        end
    end
    
    // Interrupt generation
    generate
        for (g = 0; g < NUM_HARTS; g++) begin : gen_int
            assign timer_int[g] = (mtimefull >= mtimecmpfull[g]);
            assign clif.timer_int[g] = timer_int[g];
            assign clif.clear_timer_int[g] = !timer_int[g] && prev_timer_int[g];
            
            assign clif.soft_int[g] = msip[g];
            assign clif.clear_soft_int[g] = ~msip[g] && msip_last[g];
        end
    endgenerate
    
    // Read behavior
    always_comb begin
        busif.error = 1'b1;
        busif.rdata = 32'hBAD1BAD1;
        
        if (busif.ren) begin
            if (busif.addr == MTIMER_TIME_ADDR) begin
                busif.error = 1'b0;
                busif.rdata = mtime;
            end else if (busif.addr == MTIMER_TIMEH_ADDR) begin
                busif.error = 1'b0;
                busif.rdata = mtimeh;
            end else begin
                for (int i = 0; i < NUM_HARTS; i++) begin
                    if (busif.addr == (MSWI_BASE_ADDR + 4*i)) begin
                        busif.error = 1'b0;
                        busif.rdata = {31'h0, msip[i]};
                    end else if (busif.addr == (MTIMER_BASE_ADDR + 8*i)) begin
                        busif.error = 1'b0;
                        busif.rdata = mtimecmp[i];
                    end else if (busif.addr == (MTIMER_BASE_ADDR + 4 + 8*i)) begin
                        busif.error = 1'b0;
                        busif.rdata = mtimecmph[i];
                    end
                end
            end
        end
    end
    
    assign busif.request_stall = 1'b0;
    
    // Reset and State Update
    always_ff @(posedge CLK, negedge nRST) begin
        if (!nRST) begin
            mtimefull <= '0;
            mtimecmpfull <= '0;
            msip <= '0;
            msip_last <= '0;
            prev_timer_int <= '0;
        end else begin
            mtimefull <= mtimefull_next;
            mtimecmpfull <= mtimecmpfull_next;
            msip <= msip_next;
            msip_last <= msip;
            prev_timer_int <= timer_int;
        end
    end

endmodule
