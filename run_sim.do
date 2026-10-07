onerror {quit -f -code 1}
onbreak {quit -f -code 1}

vlib work
vmap work work

# Compile package and interfaces
vlog -sv riscv/include/riscv_pkg.sv
vlog -sv riscv/include/ahb_if.sv
vlog -sv riscv/include/cache_if.sv
vlog -sv riscv/include/coherence_if.sv

# Compile RTL
vlog -sv riscv/rtl/cache/l1_cache.sv
vlog -sv riscv/rtl/memory/memory_controller.sv
vlog -sv riscv/rtl/memory/sram_model.sv
vlog -sv riscv/rtl/core/alu.sv
vlog -sv riscv/rtl/core/base_decoder.sv
vlog -sv riscv/rtl/core/decoder.sv
vlog -sv riscv/rtl/core/ext_a_decoder.sv
vlog -sv riscv/rtl/core/hazard_unit.sv
vlog -sv riscv/rtl/core/regfile.sv
vlog -sv riscv/rtl/core/forwarding_unit.sv
vlog -sv riscv/rtl/core/branch_predictor.sv
vlog -sv riscv/rtl/core/csr_regfile.sv
vlog -sv riscv/rtl/core/datapath.sv
vlog -sv riscv/rtl/soc/riscv_cluster.sv

# Compile TB
vlog -sv riscv/verification/tb/tb_soc.sv

# Run simulation
vsim -c -do "run -all; quit" tb_soc
