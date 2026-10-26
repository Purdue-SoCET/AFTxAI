// registers.sv
// Register block for DMA
module registers #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter COUNT_W = 8
)(
    input  logic clk,
    input  logic rst_n,

    // CPU slave interface (abstracted as a simple valid/ready style memory interface here, or we can use generic ahb_subordinate logic)
    input  logic        wen,
    input  logic        ren,
    input  logic [31:0] addr, // Assumed word-aligned offset
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        ready,

    // Control signals to FSMs
    output logic [ADDR_WIDTH-1:0] sar,
    output logic [ADDR_WIDTH-1:0] dar,
    output logic [COUNT_W-1:0]    tsr,
    output logic [31:0]           cr,

    // Status inputs from FSMs
    input  logic        fsm_finished,
    input  logic        fsm_error,
    input  logic        fsm_clear_en,
    output logic        irq
);

    logic [ADDR_WIDTH-1:0] reg_sar;
    logic [ADDR_WIDTH-1:0] reg_dar;
    logic [COUNT_W-1:0]    reg_tsr;
    logic [31:0]           reg_cr;
    logic [31:0]           reg_sr; // [1] = ERROR, [0] = FINISHED

    assign sar = reg_sar;
    assign dar = reg_dar;
    assign tsr = reg_tsr;
    assign cr  = reg_cr;

    assign irq = (reg_sr[0] | reg_sr[1]) & reg_cr[14];

    assign ready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_sar <= '0;
            reg_dar <= '0;
            reg_tsr <= '0;
            reg_cr  <= '0;
            reg_sr  <= '0;
            rdata   <= '0;
        end else begin
            // FSM updates
            if (fsm_finished) reg_sr[0] <= 1'b1;
            if (fsm_error)    reg_sr[1] <= 1'b1;
            
            // Auto-clear EN if FSM finishes
            if (fsm_clear_en) reg_cr[0] <= 1'b0;

            // CPU Read
            if (ren) begin
                case (addr[7:0])
                    8'h04: rdata <= reg_sar;
                    8'h08: rdata <= reg_dar;
                    8'h0C: rdata <= {{(32-COUNT_W){1'b0}}, reg_tsr};
                    8'h10: rdata <= reg_cr;
                    8'h14: begin
                        rdata <= reg_sr;
                        reg_sr <= '0; // Read-to-clear status
                    end
                    default: rdata <= '0;
                endcase
            end

            // CPU Write
            if (wen) begin
                case (addr[7:0])
                    8'h04: reg_sar <= wdata[ADDR_WIDTH-1:0];
                    8'h08: reg_dar <= wdata[ADDR_WIDTH-1:0];
                    8'h0C: reg_tsr <= wdata[COUNT_W-1:0];
                    8'h10: begin
                        // Enforce reserved bit constraints
                        reg_cr <= wdata;
                        if (wdata[7:6] == 2'b11) begin
                            // Reserved PSIZE, ignore or default to 00
                            reg_cr[7:6] <= 2'b00;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
