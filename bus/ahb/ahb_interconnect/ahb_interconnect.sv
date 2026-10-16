`include "ahb_pkg.sv"

module ahb_interconnect #(
    parameter int NMANAGERS = 2,
    parameter int NSUBORDINATES = 2,
    parameter logic [31:0] AHB_MAP [NSUBORDINATES] = '{default: 32'h0},
    parameter logic [31:0] AHB_MASK [NSUBORDINATES] = '{default: 32'hF000_0000},
    parameter int HDATA_WIDTH = 32
) (
    input logic HCLK,
    input logic HRESETn,
    ahb_if manager_ports [NMANAGERS],
    ahb_if subordinate_ports [NSUBORDINATES]
);

    import ahb_pkg::*;

    // Intermediate arrays to avoid dynamic interface indexing
    logic mgr_HSEL [NMANAGERS];
    logic mgr_HWRITE [NMANAGERS];
    logic mgr_HMASTLOCK [NMANAGERS];
    logic [1:0] mgr_HTRANS [NMANAGERS];
    logic [2:0] mgr_HBURST [NMANAGERS];
    logic [2:0] mgr_HSIZE [NMANAGERS];
    logic [31:0] mgr_HADDR [NMANAGERS];
    logic [HDATA_WIDTH-1:0] mgr_HWDATA [NMANAGERS];
    logic [(HDATA_WIDTH/8)-1:0] mgr_HWSTRB [NMANAGERS];
    logic mgr_HREADYOUT [NMANAGERS];
    logic [HDATA_WIDTH-1:0] mgr_HRDATA [NMANAGERS];
    logic mgr_HRESP [NMANAGERS];

    logic sub_HSEL [NSUBORDINATES];
    logic sub_HWRITE [NSUBORDINATES];
    logic sub_HMASTLOCK [NSUBORDINATES];
    logic [1:0] sub_HTRANS [NSUBORDINATES];
    logic [2:0] sub_HBURST [NSUBORDINATES];
    logic [2:0] sub_HSIZE [NSUBORDINATES];
    logic [31:0] sub_HADDR [NSUBORDINATES];
    logic [HDATA_WIDTH-1:0] sub_HWDATA [NSUBORDINATES];
    logic [(HDATA_WIDTH/8)-1:0] sub_HWSTRB [NSUBORDINATES];
    logic sub_HREADY [NSUBORDINATES];
    logic [HDATA_WIDTH-1:0] sub_HRDATA [NSUBORDINATES];
    logic sub_HRESP [NSUBORDINATES];

    logic current_hready;

    generate
        for (genvar i = 0; i < NMANAGERS; i++) begin : gen_mgr
            assign mgr_HSEL[i]      = manager_ports[i].HSEL;
            assign mgr_HWRITE[i]    = manager_ports[i].HWRITE;
            assign mgr_HMASTLOCK[i] = manager_ports[i].HMASTLOCK;
            assign mgr_HTRANS[i]    = manager_ports[i].HTRANS;
            assign mgr_HBURST[i]    = manager_ports[i].HBURST;
            assign mgr_HSIZE[i]     = manager_ports[i].HSIZE;
            assign mgr_HADDR[i]     = manager_ports[i].HADDR;
            assign mgr_HWDATA[i]    = manager_ports[i].HWDATA;
            assign mgr_HWSTRB[i]    = manager_ports[i].HWSTRB;

            assign manager_ports[i].HREADY = mgr_HREADYOUT[i];
            assign manager_ports[i].HREADYOUT = mgr_HREADYOUT[i]; // for completeness
            assign manager_ports[i].HRDATA    = mgr_HRDATA[i];
            assign manager_ports[i].HRESP     = mgr_HRESP[i];
        end

        for (genvar i = 0; i < NSUBORDINATES; i++) begin : gen_sub
            assign subordinate_ports[i].HSEL      = sub_HSEL[i];
            assign subordinate_ports[i].HWRITE    = sub_HWRITE[i];
            assign subordinate_ports[i].HMASTLOCK = sub_HMASTLOCK[i];
            assign subordinate_ports[i].HTRANS    = sub_HTRANS[i];
            assign subordinate_ports[i].HBURST    = sub_HBURST[i];
            assign subordinate_ports[i].HSIZE     = sub_HSIZE[i];
            assign subordinate_ports[i].HADDR     = sub_HADDR[i];
            assign subordinate_ports[i].HWDATA    = sub_HWDATA[i];
            assign subordinate_ports[i].HWSTRB    = sub_HWSTRB[i];
            assign subordinate_ports[i].HREADY    = current_hready; // Global HREADY

            assign sub_HREADY[i] = subordinate_ports[i].HREADYOUT;
            assign sub_HRDATA[i] = subordinate_ports[i].HRDATA;
            assign sub_HRESP[i]  = subordinate_ports[i].HRESP;
        end
    endgenerate

    // Request logic
    logic [NMANAGERS-1:0] request;
    always_comb begin
        for (int i = 0; i < NMANAGERS; i++) begin
            request[i] = (mgr_HTRANS[i] == NONSEQ) || (mgr_HTRANS[i] == SEQ);
        end
    end

    // Arbitration: Round-robin with lock on requesting manager
    int unsigned granted_manager;
    int unsigned active_manager_addr_phase;
    
    // Data phase tracking
    int unsigned active_manager_data_phase;
    int unsigned active_sub_data_phase;
    logic data_phase_active;

    logic def_sub_hready;
    logic def_sub_hresp;
    logic def_sub_active;


    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            granted_manager <= 0;
        end else if (current_hready) begin
            granted_manager <= active_manager_addr_phase;
        end
    end

    always_comb begin
        active_manager_addr_phase = granted_manager;
        if (current_hready && !request[granted_manager]) begin
            for (int i = 1; i <= NMANAGERS; i++) begin
                int static_idx;
                static_idx = (granted_manager + i) % NMANAGERS;
                if (request[static_idx]) begin
                    active_manager_addr_phase = static_idx;
                    break;
                end
            end
        end
    end

    // Address decoding
    int unsigned active_sub_addr_phase;
    logic [31:0] current_haddr;
    always_comb begin
        current_haddr = mgr_HADDR[active_manager_addr_phase];
        active_sub_addr_phase = NSUBORDINATES; // Default to unmapped (default subordinate)
        for (int i = 0; i < NSUBORDINATES; i++) begin
            if ((current_haddr & AHB_MASK[i]) == (AHB_MAP[i] & AHB_MASK[i])) begin
                active_sub_addr_phase = i;
                break;
            end
        end
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            active_manager_data_phase <= 0;
            active_sub_data_phase <= 0;
            data_phase_active <= 1'b0;
            def_sub_active <= 1'b0;
        end else begin
            if (current_hready) begin
                active_manager_data_phase <= active_manager_addr_phase;
                active_sub_data_phase <= active_sub_addr_phase;
                data_phase_active <= request[active_manager_addr_phase];
                def_sub_active <= (active_sub_addr_phase == NSUBORDINATES) && request[active_manager_addr_phase];
            end else if (def_sub_active) begin
                def_sub_active <= 1'b0;
            end
        end
    end

    assign def_sub_hready = !def_sub_active;
    assign def_sub_hresp  = 1'b1;

    // If no data phase is active, default to ready.
    assign current_hready = data_phase_active ? 
                            ((active_sub_data_phase == NSUBORDINATES) ? def_sub_hready : sub_HREADY[active_sub_data_phase]) 
                            : 1'b1;

    // Multiplexer - Manager to Subordinate
    always_comb begin
        for (int i = 0; i < NSUBORDINATES; i++) begin
            // Address phase signals
            if (i == active_sub_addr_phase) begin
                sub_HSEL[i]      = request[active_manager_addr_phase];
                sub_HADDR[i]     = mgr_HADDR[active_manager_addr_phase];
                sub_HWRITE[i]    = mgr_HWRITE[active_manager_addr_phase];
                sub_HTRANS[i]    = mgr_HTRANS[active_manager_addr_phase];
                sub_HSIZE[i]     = mgr_HSIZE[active_manager_addr_phase];
                sub_HBURST[i]    = mgr_HBURST[active_manager_addr_phase];
                sub_HMASTLOCK[i] = mgr_HMASTLOCK[active_manager_addr_phase];
            end else begin
                sub_HSEL[i]      = 1'b0;
                sub_HADDR[i]     = '0;
                sub_HWRITE[i]    = 1'b0;
                sub_HTRANS[i]    = IDLE;
                sub_HSIZE[i]     = '0;
                sub_HBURST[i]    = '0;
                sub_HMASTLOCK[i] = 1'b0;
            end

            // Data phase signals
            if (i == active_sub_data_phase) begin
                sub_HWDATA[i] = mgr_HWDATA[active_manager_data_phase];
                sub_HWSTRB[i] = mgr_HWSTRB[active_manager_data_phase];
            end else begin
                sub_HWDATA[i] = '0;
                sub_HWSTRB[i] = '0;
            end
        end
    end

    // Multiplexer - Subordinate to Manager
    always_comb begin
        for (int i = 0; i < NMANAGERS; i++) begin
            if (i == active_manager_data_phase) begin
                if (active_sub_data_phase == NSUBORDINATES) begin
                    // Default Subordinate (Unmapped) provides 0 data and ERROR response
                    mgr_HRDATA[i] = '0;
                    mgr_HRESP[i]  = def_sub_hresp;
                end else begin
                    mgr_HRDATA[i] = sub_HRDATA[active_sub_data_phase];
                    mgr_HRESP[i]  = sub_HRESP[active_sub_data_phase];
                end
            end else begin
                mgr_HRDATA[i] = '0;
                mgr_HRESP[i]  = 1'b0;
            end
            
            // Wait state routing
            if (i == active_manager_data_phase) begin
                // The manager currently in data phase gets HREADY
                mgr_HREADYOUT[i] = current_hready;
            end else if (i == active_manager_addr_phase && request[i]) begin
                // The manager granted for address phase also must see current_hready
                // to know when its address phase is accepted.
                mgr_HREADYOUT[i] = current_hready;
            end else if (request[i]) begin
                // Un-granted requesting managers are stalled
                mgr_HREADYOUT[i] = 1'b0;
            end else begin
                // Idle managers
                mgr_HREADYOUT[i] = 1'b1;
            end
        end
    end

endmodule
