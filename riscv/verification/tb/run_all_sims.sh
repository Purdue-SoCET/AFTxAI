#!/bin/bash
vsim -c -voptargs=+acc -L work tb_alu -do "run -all; quit -f" > tb_alu.log 2>&1
vsim -c -voptargs=+acc -L work tb_regfile -do "run -all; quit -f" > tb_regfile.log 2>&1
vsim -c -voptargs=+acc -L work tb_decoder -do "run -all; quit -f" > tb_decoder.log 2>&1
vsim -c -voptargs=+acc -L work tb_hazard_unit -do "run -all; quit -f" > tb_hazard_unit.log 2>&1
vsim -c -voptargs=+acc -L work tb_forwarding_unit -do "run -all; quit -f" > tb_forwarding_unit.log 2>&1
vsim -c -voptargs=+acc -L work tb_branch_predictor -do "run -all; quit -f" > tb_branch_predictor.log 2>&1
vsim -c -voptargs=+acc -L work tb_csr_regfile -do "run -all; quit -f" > tb_csr_regfile.log 2>&1
vsim -c -voptargs=+acc -L work tb_l1_cache -do "run -all; quit -f" > tb_l1_cache.log 2>&1

grep -i "pass" tb_*.log
grep -i "fail" tb_*.log
grep -i "error" tb_*.log
