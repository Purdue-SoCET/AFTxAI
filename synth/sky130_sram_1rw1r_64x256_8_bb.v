// Blackbox stub for SkyWater SKY130 OpenRAM 2 KiB macro (64x256_8)
// Used during ASIC synthesis to treat SRAM macros as physical hard blocks.
(* blackbox *)
module sky130_sram_1rw1r_64x256_8 (
    input  wire        clk0,
    input  wire        csb0,
    input  wire        web0,
    input  wire [7:0]  wmask0,
    input  wire [7:0]  addr0,
    input  wire [63:0] din0,
    output wire [63:0] dout0,
    input  wire        clk1,
    input  wire        csb1,
    input  wire [7:0]  addr1,
    output wire [63:0] dout1
);
endmodule
