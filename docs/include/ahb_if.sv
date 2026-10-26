`ifndef AHB_IF_SV
`define AHB_IF_SV
interface ahb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input HCLK,
    input HRESETn
);

    logic HSEL;
    logic HREADY;
    logic HREADYOUT;
    logic HWRITE;
    logic HMASTLOCK;
    logic HRESP;
    logic [1:0] HTRANS;
    logic [2:0] HBURST;
    logic [2:0] HSIZE;
    logic [ADDR_WIDTH - 1:0] HADDR;
    logic [DATA_WIDTH - 1:0] HWDATA;
    logic [DATA_WIDTH - 1:0] HRDATA;
    logic [(DATA_WIDTH/8) - 1:0] HWSTRB;

    // In a multi-target interconnect, HREADY input to the target is the global HREADY.
    // HREADYOUT is the target's readiness output.
    // For single-target systems without an interconnect, they can be tied together, 
    // but the interconnect must break this loop. We remove the hardwired assign here 
    // and let the interconnect (or top level) drive HREADY.

    modport manager(
        input HCLK, HRESETn,
        input HREADY, HRESP, HRDATA,
        output HWRITE, HMASTLOCK, HTRANS,
        HBURST, HSIZE, HADDR, HWDATA, HWSTRB, HSEL
    );

    modport subordinate(
        input HCLK, HRESETn,
        input HSEL, HWRITE, HMASTLOCK, HTRANS,
        HBURST, HSIZE, HADDR, HWDATA, HWSTRB, HREADY,
        output HREADYOUT, HRDATA, HRESP
    );

endinterface
`endif
