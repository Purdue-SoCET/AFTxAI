onerror {quit -f -code 1}
onbreak {quit -f -code 1}

vlib work
vlog -sv -f filelist.f \
    ../../../riscv/rtl/core/datapath.sv \
    ../../../riscv/rtl/memory/memory_controller.sv \
    ../../../riscv/rtl/memory/sram_model.sv \
    ../../../riscv/rtl/soc/riscv_cluster.sv \
    tb_soc.sv

vsim -c -voptargs=+acc -L work tb_soc
run -all
quit -f
