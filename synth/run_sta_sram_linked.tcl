# OpenROAD Static Timing Analysis for AFTxAI aft_synth_top with SRAM Macros
set lib_file "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set tech_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef"
set cell_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef"
set sram_lib "/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8_TT_1p8V_25C.lib"
set sram_lef "/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.lef"
set netlist_file "/work/synth/out_sram/netlist_sta_linked.v"
set sdc_file "/work/synth/aft_top.sdc"

puts "==> Reading Standard Cell Liberty library: $lib_file"
read_liberty $lib_file

puts "==> Reading SRAM Macro Liberty library: $sram_lib"
read_liberty $sram_lib

puts "==> Reading Tech LEF: $tech_lef"
read_lef $tech_lef

puts "==> Reading Standard Cell LEF: $cell_lef"
read_lef $cell_lef

puts "==> Reading SRAM Macro LEF: $sram_lef"
read_lef $sram_lef

puts "==> Reading mapped netlist: $netlist_file"
read_verilog $netlist_file

puts "==> Linking design: aft_synth_top"
link_design aft_synth_top

puts "==> Reading SDC constraints: $sdc_file"
read_sdc $sdc_file

puts "==> Checking unconstrained paths"
check_setup -unconstrained_endpoints

puts "==> Checking SRAM Macro instance connections and pins"
report_checks -through [get_pins -hierarchical *u_sram*/*] -endpoint_count 5

puts "==> Reporting design metrics"
report_checks -fields {capacitance slew input_pins nets} -format full_clock_expanded -path_delay max -digits 4

puts "==> Reporting top 10 critical paths"
report_checks -path_delay max -endpoint_count 10 -digits 4

puts "==> Reporting worst slack summary"
report_worst_slack -max
report_worst_slack -min

puts "==> Reporting clock skew"
report_clock_skew

puts "==> Reporting unconstrained endpoints list"
report_checks -unconstrained -endpoint_count 20

puts "==> Timing analysis completed."
exit
