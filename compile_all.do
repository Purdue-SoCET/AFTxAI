vlib work
vlog -f riscv/verification/tb/filelist.f
vlog -sv riscv/verification/tb/tb_alu.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_regfile.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_decoder.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_hazard_unit.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_forwarding_unit.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_branch_predictor.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_csr_regfile.sv +incdir+riscv/include
vlog -sv riscv/verification/tb/tb_l1_cache.sv +incdir+riscv/include
quit -f
