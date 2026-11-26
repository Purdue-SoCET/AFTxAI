// Blackbox stub for UC Berkeley Substrate SRAM22 2 KiB macro (256x64m4w8)
// Used during ASIC synthesis to treat SRAM macros as physical hard blocks.
(* blackbox *)
module sram22_256x64m4w8 (
    input  wire        clk,
    input  wire        rstb,
    input  wire        ce,
    input  wire        we,
    input  wire [7:0]  wmask,
    input  wire [7:0]  addr,
    input  wire [63:0] din,
    output wire [63:0] dout
);
endmodule
