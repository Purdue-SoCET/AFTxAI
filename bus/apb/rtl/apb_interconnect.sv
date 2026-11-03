module apb_interconnect #(
    parameter int NCOMPLETERS = 2,
    parameter int COMPLETER_ADDR_BITS = 16,
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    // verilator lint_off UNUSED
    parameter logic [31:0] BUS_REGION_BEGIN = 32'h8000_0000, 
    // verilator lint_on UNUSED
    parameter logic [31:0] APB_MAP [NCOMPLETERS] = '{default: '0}
) (
    apb_if.completer requester,      
    apb_if.requester completers [NCOMPLETERS] 
);

    logic [NCOMPLETERS-1:0] sel_completer;
    logic decode_error;
    
    always_comb begin
        sel_completer = '0;
        decode_error = requester.psel; 
        
        for (int i = 0; i < NCOMPLETERS; i++) begin
            if (requester.paddr[ADDR_WIDTH-1 : COMPLETER_ADDR_BITS] == APB_MAP[i][ADDR_WIDTH-1 : COMPLETER_ADDR_BITS]) begin
                sel_completer[i] = requester.psel;
                decode_error = 1'b0;
            end
        end
    end

    logic [DATA_WIDTH-1:0] mux_prdata;
    logic                  mux_pready;
    logic                  mux_pslverr;

    always_comb begin
        mux_prdata = '0;
        mux_pready = 1'b1;
        mux_pslverr = decode_error && requester.psel;
    end

    // Use generate for array of interfaces to avoid constant indexing issues
    // Assign from a single matched completer, or defaults if none matched
    // We do this by aggregating the selected signals into vectors or doing a combinational sum
    
    logic [NCOMPLETERS-1:0][DATA_WIDTH-1:0] agg_prdata;
    logic [NCOMPLETERS-1:0]                 agg_pready;
    logic [NCOMPLETERS-1:0]                 agg_pslverr;
    
    genvar i;
    generate
        for (i = 0; i < NCOMPLETERS; i++) begin : gen_completers
            assign completers[i].paddr   = requester.paddr;
            assign completers[i].pprot   = requester.pprot;
            assign completers[i].psel    = sel_completer[i];
            assign completers[i].penable = requester.penable && sel_completer[i];
            assign completers[i].pwrite  = requester.pwrite;
            assign completers[i].pwdata  = requester.pwdata;
            assign completers[i].pstrb   = requester.pstrb;
            
            assign agg_prdata[i]  = sel_completer[i] ? completers[i].prdata : '0;
            assign agg_pready[i]  = sel_completer[i] ? completers[i].pready : 1'b0;
            assign agg_pslverr[i] = sel_completer[i] ? completers[i].pslverr : 1'b0;
        end
    endgenerate

    // Aggregate outputs
    logic [DATA_WIDTH-1:0] final_prdata;
    logic                  final_pready;
    logic                  final_pslverr;
    
    always_comb begin
        final_prdata = mux_prdata;
        final_pready = mux_pready;
        final_pslverr = mux_pslverr;
        for (int j = 0; j < NCOMPLETERS; j++) begin
            if (sel_completer[j]) begin
                final_prdata = agg_prdata[j];
                final_pready = agg_pready[j];
                final_pslverr = agg_pslverr[j];
            end
        end
    end

    assign requester.prdata  = final_prdata;
    assign requester.pready  = final_pready;
    assign requester.pslverr = final_pslverr;

endmodule
