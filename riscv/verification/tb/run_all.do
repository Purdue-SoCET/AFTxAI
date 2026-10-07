vlib work
vlog -sv -f filelist.f tb_alu.sv tb_regfile.sv tb_decoder.sv tb_hazard_unit.sv tb_forwarding_unit.sv tb_branch_predictor.sv tb_csr_regfile.sv tb_l1_cache.sv

set testbenches {tb_alu tb_regfile tb_decoder tb_hazard_unit tb_forwarding_unit tb_branch_predictor tb_csr_regfile tb_l1_cache}

foreach tb $testbenches {
    echo "Running $tb..."
    vsim -c -voptargs=+acc -L work $tb
    run -all
}
quit -f
