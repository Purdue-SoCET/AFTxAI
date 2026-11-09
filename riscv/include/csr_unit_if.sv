`ifndef CSR_UNIT_IF_SV
`define CSR_UNIT_IF_SV
interface csr_unit_if;
    // Interrupt lines
    logic mtip, msip, meip;
    
    // EX stage CSR read
    logic [11:0] csr_read_addr;
    logic [31:0] csr_read_data;
    
    // WB stage CSR write
    logic csr_write_en;
    logic [11:0] csr_write_addr;
    logic [31:0] csr_write_data;
    
    // Trap/Exception handling (from WB stage)
    logic trap_req;
    logic [31:0] trap_cause; // bit 31: interrupt, bits 30:0: exception code
    logic [31:0] trap_pc;    // PC of the instruction that caused the trap, or interrupted instruction
    logic mret_req;
    
    // Trap/Exception outputs (to WB stage)
    logic [31:0] mtvec_val;
    logic [31:0] mepc_val;
    logic interrupt_pending;
    logic [31:0] interrupt_cause; // Cause code of the highest priority pending interrupt
    
    modport mp (
        input mtip, msip, meip,
              csr_read_addr, csr_write_en, csr_write_addr, csr_write_data,
              trap_req, trap_cause, trap_pc, mret_req,
        output csr_read_data, mtvec_val, mepc_val, interrupt_pending, interrupt_cause
    );
endinterface
`endif
