`ifndef MEMARB_IF_SV
`define MEMARB_IF_SV

interface memArb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    // Read controller side
    logic                r_hsel;
    logic [ADDR_WIDTH-1:0]   r_haddr;
    logic [2:0]          r_hsize;
    logic                r_hready;
    logic                r_hresp;
    logic [DATA_WIDTH-1:0]   r_hrdata;

    // Write controller side
    logic                w_hsel;
    logic [ADDR_WIDTH-1:0]   w_haddr;
    logic [2:0]          w_hsize;
    logic [DATA_WIDTH-1:0]   w_hwdata;
    logic                w_hready;
    logic                w_hresp;

    modport read_port (
        output r_hsel, r_haddr, r_hsize,
        input  r_hready, r_hresp, r_hrdata
    );

    modport write_port (
        output w_hsel, w_haddr, w_hsize, w_hwdata,
        input  w_hready, w_hresp
    );

    modport arbiter_port (
        input  r_hsel, r_haddr, r_hsize,
        output r_hready, r_hresp, r_hrdata,
        
        input  w_hsel, w_haddr, w_hsize, w_hwdata,
        output w_hready, w_hresp
    );

endinterface

`endif
