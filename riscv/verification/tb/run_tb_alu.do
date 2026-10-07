vlib work
vlog -sv -f filelist.f tb_alu.sv
vsim -c -voptargs=+acc -L work tb_alu
run -all
quit -f
