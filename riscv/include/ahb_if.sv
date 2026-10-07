interface ahb_if;
  logic [31:0] haddr;
  logic [2:0]  hburst;
  logic        hmastlock;
  logic [3:0]  hprot;
  logic [2:0]  hsize;
  logic [1:0]  htrans;
  logic [31:0] hwdata;
  logic        hwrite;
  logic [31:0] hrdata;
  logic        hready;
  logic        hresp;

  modport master (
    output haddr, hburst, hmastlock, hprot, hsize, htrans, hwdata, hwrite,
    input  hrdata, hready, hresp
  );

  modport slave (
    input  haddr, hburst, hmastlock, hprot, hsize, htrans, hwdata, hwrite,
    output hrdata, hready, hresp
  );
endinterface
