module hazard_unit (
  // IF/ID inputs
  input  logic [4:0] id_rs1,
  input  logic [4:0] id_rs2,
  input  logic       id_uses_rs1,
  input  logic       id_uses_rs2,
  
  // ID/EX inputs
  input  logic       ex_is_load,
  input  logic       ex_is_amo,
  input  logic [4:0] ex_rd,
  
  // MEM/WB inputs
  input  logic       mem_is_amo, // Multi-cycle amo in progress
  input  logic       icache_stall,
  input  logic       dcache_stall,
  
  // Flush signals
  input  logic       branch_mispredict,
  input  logic       trap_flush,
  
  // Pipeline controls
  output logic       stall_if,
  output logic       stall_id,
  output logic       stall_ex,
  output logic       stall_mem,
  output logic       flush_if,
  output logic       flush_id,
  output logic       flush_ex
);

  logic load_use_stall;

  always_comb begin
    // 1-cycle stall if EX stage is a load and ID stage uses the load's destination register
    load_use_stall = ex_is_load && (ex_rd != 5'd0) &&
                     ((id_uses_rs1 && id_rs1 == ex_rd) || 
                      (id_uses_rs2 && id_rs2 == ex_rd));
                      
    // AMO sequencer stall (waits for cache AMO response)
    // Pipeline freeze on any cache stall
    stall_mem = dcache_stall;
    stall_ex  = stall_mem || mem_is_amo;
    stall_id  = stall_ex || load_use_stall || icache_stall;
    stall_if  = stall_id || icache_stall;

    // Flushes (Trap has highest priority, then branch mispredict)
    flush_ex = trap_flush || branch_mispredict;
    flush_id = trap_flush || branch_mispredict || (load_use_stall && !stall_ex);
    flush_if = trap_flush || branch_mispredict;
  end

endmodule
