import riscv_pkg::*;

interface cache_if;
  logic        req;
  logic [31:0] addr;
  logic [31:0] wdata;
  logic [3:0]  wmask;
  logic        we; // 0: read, 1: write
  logic        is_amo;
  exec_op_t    amo_op;

  logic        gnt;
  logic        valid;
  logic [31:0] rdata;
  logic        err;

  modport cpu (
    output req, addr, wdata, wmask, we, is_amo, amo_op,
    input  gnt, valid, rdata, err
  );

  modport cache (
    input  req, addr, wdata, wmask, we, is_amo, amo_op,
    output gnt, valid, rdata, err
  );
endinterface
