vlib work
vlog -sv -f filelist.f
vlog -sv +incdir+../../include tb_alu.sv tb_regfile.sv tb_decoder.sv tb_hazard_unit.sv tb_forwarding_unit.sv tb_branch_predictor.sv tb_csr_regfile.sv tb_l1_cache.sv
quit -f

