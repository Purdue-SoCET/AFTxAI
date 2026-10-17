module apb_sva #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic PCLK,
    input logic PRESETn,
    input logic [ADDR_WIDTH-1:0]     PADDR,
    input logic [2:0]                PPROT,
    input logic                      PSEL,
    input logic                      PENABLE,
    input logic                      PWRITE,
    input logic [DATA_WIDTH-1:0]     PWDATA,
    input logic [(DATA_WIDTH/8)-1:0] PSTRB,
    input logic                      PREADY,
    input logic [DATA_WIDTH-1:0]     PRDATA,
    input logic                      PSLVERR
);

    // Protocol Assertions (SVA)
    
    // SETUP to ACCESS transition
    property p_setup_to_access;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PENABLE) |=> PENABLE;
    endproperty
    assert_setup_to_access: assert property(p_setup_to_access) else $error("SVA: PSEL && !PENABLE |=> PENABLE failed!");

    // ACCESS must have PSEL
    property p_access_psel;
        @(posedge PCLK) disable iff (!PRESETn)
        PENABLE |-> PSEL;
    endproperty
    assert_access_psel: assert property(p_access_psel) else $error("SVA: PENABLE |-> PSEL failed!");

    // Signal stability during wait states
    property p_stable_wait;
        @(posedge PCLK) disable iff (!PRESETn)
        (PENABLE && !PREADY) |=> $stable({PADDR, PWRITE, PWDATA, PSEL, PSTRB, PPROT});
    endproperty
    assert_stable_wait: assert property(p_stable_wait) else $error("SVA: Signal stability during wait state failed!");

    // Control signals not X/Z out of reset
    property p_no_xz;
        @(posedge PCLK) disable iff (!PRESETn)
        !$isunknown({PSEL, PENABLE, PWRITE});
    endproperty
    assert_no_xz: assert property(p_no_xz) else $error("SVA: Control signals X/Z out of reset!");

endmodule
