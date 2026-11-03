`ifndef MEMARB_IF_SV
`define MEMARB_IF_SV

interface memArb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    // Read channel
    logic                  r_req;
    logic [ADDR_WIDTH-1:0] r_addr;
    logic [2:0]            r_size;
    logic                  r_gnt;
    logic                  r_ready;
    logic [DATA_WIDTH-1:0] r_rdata;
    logic                  r_err;

    // Write channel
    logic                  w_req;
    logic [ADDR_WIDTH-1:0] w_addr;
    logic [2:0]            w_size;
    logic [DATA_WIDTH-1:0] w_data;
    logic                  w_gnt;
    logic                  w_ready;
    logic                  w_err;

    modport read_fsm (
        input  clk, rst_n, r_gnt, r_ready, r_rdata, r_err,
        output r_req, r_addr, r_size
    );

    modport write_fsm (
        input  clk, rst_n, w_gnt, w_ready, w_err,
        output w_req, w_addr, w_size, w_data
    );

    modport arbiter (
        input  clk, rst_n, r_req, r_addr, r_size, w_req, w_addr, w_size, w_data,
        output r_gnt, r_ready, r_rdata, r_err, w_gnt, w_ready, w_err
    );
endinterface

`endif
