`default_nettype none

/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off UNDRIVEN */

module plic (
    input  logic clk,
    input  logic nrst,
    
    // Bus Interface
    bus_protocol_if.peripheral_vital bus,
    
    // PLIC Interface
    plic_if.plic irq_if
);

    // Register Map Parameters
    localparam logic [21:0] ADDR_PRIORITY_BASE = 22'h00_0000;
    localparam logic [21:0] ADDR_PRIORITY_END  = 22'h00_007C;
    localparam logic [21:0] ADDR_PENDING       = 22'h00_1000;
    localparam logic [21:0] ADDR_ENABLE        = 22'h00_2000;
    localparam logic [21:0] ADDR_THRESHOLD     = 22'h20_0000;
    localparam logic [21:0] ADDR_CLAIM_COMP    = 22'h20_0004;

    // Registers state
    logic [31:1][2:0] priority_q;       // PLIC-REQ-001: 31 priorities (3 bits for 0-7)
    logic [31:1]      pending_q;        // PLIC-REQ-002
    logic [31:1]      enable_q;         // PLIC-REQ-003
    logic [2:0]       threshold_q;
    logic [31:1]      claimed_q;        // Track if an interrupt is claimed (gateway status)

    // Registers next
    logic [31:1][2:0] priority_d;
    logic [31:1]      pending_d;
    logic [31:1]      enable_d;
    logic [2:0]       threshold_d;
    logic [31:1]      claimed_d;

    // Highest priority determination (PLIC-REQ-006)
    logic [2:0] max_prio;
    logic [4:0] max_id;

    always_comb begin
        max_prio = '0;
        max_id   = '0;
        // Search 1 to 31 (lowest ID wins on tie)
        for (int i = 31; i > 0; i--) begin
            if (pending_q[i] && enable_q[i] && priority_q[i] >= max_prio) begin
                max_prio = priority_q[i];
                max_id   = 5'(i);
            end
        end
    end

    // PLIC-REQ-003: Interrupted if highest pending & enabled > THRESHOLD
    logic irq_target_d;
    always_comb begin
        irq_target_d = (max_prio > threshold_q) && (max_id != 0);
    end

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) irq_if.irq_target <= 1'b0;
        else       irq_if.irq_target <= irq_target_d;
    end

    // Bus interface logic
    logic [21:0] bus_addr;
    assign bus_addr = bus.addr[21:0];
    
    logic is_priority_addr;
    assign is_priority_addr = (bus_addr <= ADDR_PRIORITY_END);
    
    logic [4:0] prio_idx;
    assign prio_idx = bus_addr[6:2];

    always_comb begin
        // Default to hold state
        priority_d  = priority_q;
        pending_d   = pending_q;
        enable_d    = enable_q;
        threshold_d = threshold_q;
        claimed_d   = claimed_q;
        
        bus.rdata   = '0;
        bus.error   = 1'b0;
        bus.request_stall = 1'b0;

        // Gateway logic (PLIC-REQ-002)
        for (int i = 1; i < 32; i++) begin
            // Trigger pending if source is high and not already claimed
            if (irq_if.irq_source[i] && !claimed_q[i]) begin
                pending_d[i] = 1'b1;
            end
        end

        // Bus Write
        if (bus.wen) begin
            if (is_priority_addr) begin
                if (prio_idx != 0) begin // PLIC-REQ-001 (0 ignored)
                    priority_d[prio_idx] = bus.wdata[2:0];
                end
            end else if (bus_addr == ADDR_ENABLE) begin
                enable_d = bus.wdata[31:1];
            end else if (bus_addr == ADDR_THRESHOLD) begin
                threshold_d = bus.wdata[2:0];
            end else if (bus_addr == ADDR_CLAIM_COMP) begin
                // Write completes the interrupt (PLIC-REQ-005)
                if (bus.wdata[4:0] != 0) begin
                    claimed_d[bus.wdata[4:0]] = 1'b0; // Release gateway
                end
            end else begin
                bus.error = 1'b1; // PLIC-REQ-007
            end
        end

        // Bus Read
        if (bus.ren) begin
            if (is_priority_addr) begin
                if (prio_idx != 0) bus.rdata = 32'(priority_q[prio_idx]);
                else               bus.rdata = '0; // PLIC-REQ-001
            end else if (bus_addr == ADDR_PENDING) begin
                bus.rdata = {pending_q, 1'b0};
            end else if (bus_addr == ADDR_ENABLE) begin
                bus.rdata = {enable_q, 1'b0};
            end else if (bus_addr == ADDR_THRESHOLD) begin
                bus.rdata = 32'(threshold_q);
            end else if (bus_addr == ADDR_CLAIM_COMP) begin
                bus.rdata = 32'(max_id);
                // Read claims the interrupt (PLIC-REQ-004)
                if (max_id != 0) begin
                    pending_d[max_id] = 1'b0;
                    claimed_d[max_id] = 1'b1;
                end
            end else begin
                bus.error = 1'b1; // PLIC-REQ-007
            end
        end
    end

    // Sequential update
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            priority_q  <= '0;
            pending_q   <= '0;
            enable_q    <= '0;
            threshold_q <= '0;
            claimed_q   <= '0;
        end else begin
            priority_q  <= priority_d;
            pending_q   <= pending_d;
            enable_q    <= enable_d;
            threshold_q <= threshold_d;
            claimed_q   <= claimed_d;
        end
    end

endmodule
/* verilator lint_on UNDRIVEN */
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on UNUSEDPARAM */
