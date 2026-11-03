`ifndef TB_UVM_TOP_SV
`define TB_UVM_TOP_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import ahb_pkg::*;
import ahb_uvm_pkg::*;

module tb_uvm_top;

    parameter int NMANAGERS = 4;
    parameter int NSUBORDINATES = 4;
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;

    logic HCLK;
    logic HRESETn;

    // Clock generation
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    // Reset generation
    initial begin
        HRESETn = 0;
        #20 HRESETn = 1;
    end

    // Interfaces
    ahb_if #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) mgr_if[NMANAGERS](HCLK, HRESETn);
    ahb_if #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) sub_if[NSUBORDINATES](HCLK, HRESETn);

    // DUT: AHB Interconnect
    localparam logic [31:0] ahb_map [4] = '{32'h0000_0000, 32'h1000_0000, 32'h2000_0000, 32'h3000_0000};
    ahb_interconnect #(
        .NMANAGERS(NMANAGERS),
        .NSUBORDINATES(NSUBORDINATES),
        .AHB_MAP(ahb_map),
        .HDATA_WIDTH(DATA_WIDTH)
    ) dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .manager_ports(mgr_if),
        .subordinate_ports(sub_if)
    );

    // Pass virtual interfaces to UVM config db
    generate
        for (genvar i = 0; i < NMANAGERS; i++) begin : gen_mgr_vif
            initial begin
                uvm_config_db#(virtual ahb_if)::set(null, $sformatf("uvm_test_top.env.mgr_agent_%0d", i), "vif", mgr_if[i]);
            end
        end
        
        for (genvar i = 0; i < NSUBORDINATES; i++) begin : gen_sub_vif
            initial begin
                uvm_config_db#(virtual ahb_if)::set(null, $sformatf("uvm_test_top.env.sub_agent_%0d", i), "vif", sub_if[i]);
            end
        end
    endgenerate

    // UVM initial block
    initial begin
        run_test();
    end

    // Optional: Dump waveforms
    initial begin
        $dumpfile("ahb_uvm.vcd");
        $dumpvars(0, tb_uvm_top);
    end

endmodule

`endif
