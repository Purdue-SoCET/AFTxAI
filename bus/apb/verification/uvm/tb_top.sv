`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import apb_pkg::*;
    
    `include "tests/base_test.sv"
    `include "tests/sanity_test.sv"
    `include "tests/unmapped_test.sv"
    `include "tests/extra_tests.sv"

    logic pclk = 0;
    logic presetn = 0;
    
    initial forever #5 pclk = ~pclk;
    
    apb_if m_if(pclk, presetn);
    apb_if s_if[2](pclk, presetn);
    
    // Connect Interconnect
    apb_interconnect #(
        .NCOMPLETERS(2),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .APB_MAP('{32'h8000_0000, 32'h8001_0000})
    ) dut (
        .requester(m_if.completer),
        .completers(s_if)
    );
    
    // SVA Bindings directly in tb_top instead of bind
    apb_sva sva_m (
        .PCLK(m_if.PCLK),
        .PRESETn(m_if.PRESETn),
        .PADDR(m_if.PADDR),
        .PPROT(m_if.PPROT),
        .PSEL(m_if.PSEL),
        .PENABLE(m_if.PENABLE),
        .PWRITE(m_if.PWRITE),
        .PWDATA(m_if.PWDATA),
        .PSTRB(m_if.PSTRB),
        .PREADY(m_if.PREADY),
        .PRDATA(m_if.PRDATA),
        .PSLVERR(m_if.PSLVERR)
    );
    
    apb_sva sva_s0 (
        .PCLK(s_if[0].PCLK),
        .PRESETn(s_if[0].PRESETn),
        .PADDR(s_if[0].PADDR),
        .PPROT(s_if[0].PPROT),
        .PSEL(s_if[0].PSEL),
        .PENABLE(s_if[0].PENABLE),
        .PWRITE(s_if[0].PWRITE),
        .PWDATA(s_if[0].PWDATA),
        .PSTRB(s_if[0].PSTRB),
        .PREADY(s_if[0].PREADY),
        .PRDATA(s_if[0].PRDATA),
        .PSLVERR(s_if[0].PSLVERR)
    );
    
    apb_sva sva_s1 (
        .PCLK(s_if[1].PCLK),
        .PRESETn(s_if[1].PRESETn),
        .PADDR(s_if[1].PADDR),
        .PPROT(s_if[1].PPROT),
        .PSEL(s_if[1].PSEL),
        .PENABLE(s_if[1].PENABLE),
        .PWRITE(s_if[1].PWRITE),
        .PWDATA(s_if[1].PWDATA),
        .PSTRB(s_if[1].PSTRB),
        .PREADY(s_if[1].PREADY),
        .PRDATA(s_if[1].PRDATA),
        .PSLVERR(s_if[1].PSLVERR)
    );

    initial begin
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif_m", m_if);
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif_s0", s_if[0]);
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif_s1", s_if[1]);
        
        run_test("sanity_test");
    end
    
    initial begin
        presetn = 0;
        #20 presetn = 1;
        forever begin
            @(posedge pclk);
            if ($test$plusargs("RESET_TEST") && $time > 200ns) begin
                presetn = 0;
                #50ns;
                presetn = 1;
                // Only trigger once
                break;
            end
        end
    end
endmodule
