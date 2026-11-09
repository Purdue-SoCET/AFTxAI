`timescale 1ns/1ps
module csr_unit (
    input logic HCLK,
    input logic nRST,
    csr_unit_if.mp port
);
    // CSR Registers
    logic [31:0] mstatus;
    logic [31:0] mie;
    logic [31:0] mip;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mcause;

    // mstatus fields
    logic mstatus_mie;
    logic mstatus_mpie;
    assign mstatus = {24'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};

    // mie fields
    logic mie_meie, mie_mtie, mie_msie;
    assign mie = {20'b0, mie_meie, 3'b0, mie_mtie, 3'b0, mie_msie, 3'b0};

    // mip fields (read-only from external pins)
    assign mip = {20'b0, port.meip, 3'b0, port.mtip, 3'b0, port.msip, 3'b0};

    // CSR Read
    always_comb begin
        case (port.csr_read_addr)
            12'h300: port.csr_read_data = mstatus;
            12'h304: port.csr_read_data = mie;
            12'h305: port.csr_read_data = mtvec;
            12'h341: port.csr_read_data = mepc;
            12'h342: port.csr_read_data = mcause;
            12'h344: port.csr_read_data = mip;
            default: port.csr_read_data = 32'b0;
        endcase
    end

    // Interrupt priority and pending calculation
    // Priority: MEI (11) > MSI (3) > MTI (7)
    always_comb begin
        port.interrupt_pending = 1'b0;
        port.interrupt_cause = 32'b0;
        if (mstatus_mie) begin
            if (mie_meie && port.meip) begin
                port.interrupt_pending = 1'b1;
                port.interrupt_cause = {1'b1, 31'd11};
            end else if (mie_msie && port.msip) begin
                port.interrupt_pending = 1'b1;
                port.interrupt_cause = {1'b1, 31'd3};
            end else if (mie_mtie && port.mtip) begin
                port.interrupt_pending = 1'b1;
                port.interrupt_cause = {1'b1, 31'd7};
            end
        end
    end

    assign port.mtvec_val = mtvec;
    assign port.mepc_val = mepc;

    // CSR Write and Trap Handling
    always_ff @(posedge HCLK or negedge nRST) begin
        if (!nRST) begin
            mstatus_mie <= 1'b0;
            mstatus_mpie <= 1'b0;
            mie_meie <= 1'b0;
            mie_mtie <= 1'b0;
            mie_msie <= 1'b0;
            mtvec <= 32'b0;
            mepc <= 32'b0;
            mcause <= 32'b0;
        end else begin
            if (port.trap_req) begin
                // Enter trap
                mstatus_mpie <= mstatus_mie;
                mstatus_mie <= 1'b0;
                mepc <= port.trap_pc;
                mcause <= port.trap_cause;
            end else if (port.mret_req) begin
                // Return from trap
                mstatus_mie <= mstatus_mpie;
                mstatus_mpie <= 1'b1;
            end else if (port.csr_write_en) begin
                // Normal CSR Write
                case (port.csr_write_addr)
                    12'h300: begin
                        mstatus_mie <= port.csr_write_data[3];
                        mstatus_mpie <= port.csr_write_data[7];
                    end
                    12'h304: begin
                        mie_meie <= port.csr_write_data[11];
                        mie_mtie <= port.csr_write_data[7];
                        mie_msie <= port.csr_write_data[3];
                    end
                    12'h305: mtvec <= {port.csr_write_data[31:2], 2'b00}; // Only direct mode supported
                    12'h341: mepc <= {port.csr_write_data[31:2], 2'b00};
                    12'h342: mcause <= port.csr_write_data;
                endcase
            end
        end
    end
endmodule
