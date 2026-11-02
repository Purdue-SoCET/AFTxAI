`ifndef AHB_SVA_SV
`define AHB_SVA_SV

module ahb_sva #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input HCLK,
    input HRESETn,
    input HSEL,
    input HREADY,
    input HREADYOUT,
    input HWRITE,
    input HMASTLOCK,
    input HRESP,
    input [1:0] HTRANS,
    input [2:0] HBURST,
    input [2:0] HSIZE,
    input [ADDR_WIDTH - 1:0] HADDR
);

    import ahb_pkg::*;

    default clocking cb @(posedge HCLK);
        default input #1step output #0;
    endclocking

    // Stable address/control during low HREADY (for the same transfer)
    // Actually, AHB spec says if HREADY is low, the address and control signals must remain stable.
    // Exception: HTRANS can change to IDLE if an ERROR response (HRESP=1) is returned.
    property p_stable_ctrl_addr_during_wait;
        @(posedge HCLK) disable iff (!HRESETn)
        (!HREADY && !HRESP) |=> ($stable(HADDR) && $stable(HWRITE) && $stable(HSIZE) && $stable(HBURST) && $stable(HTRANS));
    endproperty
    a_stable_ctrl_addr_during_wait: assert property (p_stable_ctrl_addr_during_wait) else $error("AHB_SVA: Control/Addr must be stable when HREADY is low and OKAY response");

    // ERROR response is two cycles (HREADYOUT low -> high, HRESP=ERROR)
    // First cycle of ERROR: HRESP=1, HREADYOUT=0
    // Second cycle of ERROR: HRESP=1, HREADYOUT=1
    property p_error_response_two_cycles;
        @(posedge HCLK) disable iff (!HRESETn)
        (HRESP == 1'b1 && !HREADYOUT) |=> (HRESP == 1'b1 && HREADYOUT);
    endproperty
    a_error_response_two_cycles: assert property (p_error_response_two_cycles) else $error("AHB_SVA: ERROR response must take exactly two cycles");

    // Manager must cancel pending transfer upon ERROR response
    // If an ERROR response starts, the manager must drive HTRANS=IDLE on the second cycle.
    property p_manager_cancel_on_error;
        @(posedge HCLK) disable iff (!HRESETn)
        (HRESP == 1'b1 && !HREADY) |=> (HTRANS == IDLE);
    endproperty
    a_manager_cancel_on_error: assert property (p_manager_cancel_on_error) else $error("AHB_SVA: Manager must drive HTRANS=IDLE on second cycle of ERROR response");

    // IDLE/BUSY -> zero-wait OKAY
    // If HSEL && (HTRANS == IDLE || HTRANS == BUSY) then the subordinate must give zero-wait OKAY?
    // Actually, AHB-Lite states that IDLE/BUSY must receive a zero-wait OKAY response, 
    // unless a previous transfer is completing.
    // So if HREADY is high, and HTRANS is IDLE/BUSY, the *next* cycle must have HREADYOUT=1 and HRESP=0.
    property p_idle_busy_zero_wait_okay;
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HREADY && (HTRANS == IDLE || HTRANS == BUSY)) |=> (HREADYOUT == 1'b1 && HRESP == 1'b0);
    endproperty
    a_idle_busy_zero_wait_okay: assert property (p_idle_busy_zero_wait_okay) else $error("AHB_SVA: IDLE/BUSY must have zero-wait OKAY response");

    // Legal HTRANS transitions (no SEQ after IDLE)
    // After IDLE or BUSY (when HREADY is high), the next valid transfer must be NONSEQ. It cannot be SEQ.
    property p_no_seq_after_idle_busy;
        @(posedge HCLK) disable iff (!HRESETn)
        (HREADY && (HTRANS == IDLE || HTRANS == BUSY)) |=> (HTRANS != SEQ);
    endproperty
    // Note: HTRANS can be IDLE again, so just assert it's not SEQ.
    a_no_seq_after_idle_busy: assert property (p_no_seq_after_idle_busy) else $error("AHB_SVA: SEQ cannot follow IDLE or BUSY");

    // No 1KB boundary crossings
    // The address cannot cross a 1KB boundary within a burst.
    // For simplicity, we just check that if HTRANS is SEQ or BUSY, the 1KB chunk matches the previous NONSEQ/SEQ.
    property p_no_1kb_boundary_crossing;
        @(posedge HCLK) disable iff (!HRESETn)
        (HREADY && (HTRANS == SEQ || HTRANS == BUSY)) |-> ($past(HADDR[ADDR_WIDTH-1:10]) == HADDR[ADDR_WIDTH-1:10]);
    endproperty
    a_no_1kb_boundary_crossing: assert property (p_no_1kb_boundary_crossing) else $error("AHB_SVA: 1KB boundary crossing detected during burst");

endmodule

// Bind to the interface
bind ahb_if ahb_sva #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) ahb_sva_inst (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HSEL(HSEL),
    .HREADY(HREADY),
    .HREADYOUT(HREADYOUT),
    .HWRITE(HWRITE),
    .HMASTLOCK(HMASTLOCK),
    .HRESP(HRESP),
    .HTRANS(HTRANS),
    .HBURST(HBURST),
    .HSIZE(HSIZE),
    .HADDR(HADDR)
);

`endif
