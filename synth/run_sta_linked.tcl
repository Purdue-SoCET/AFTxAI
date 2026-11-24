# OpenROAD Static Timing Analysis for AFTxAI aft_synth_top
set lib_file "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set tech_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef"
set cell_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef"
set netlist_file "/work/netlist_sta_linked.v"
set sdc_file "/synth/aft_top.sdc"

puts "==> Reading Liberty library: $lib_file"
read_liberty $lib_file

puts "==> Reading Tech LEF: $tech_lef"
read_lef $tech_lef

puts "==> Reading Cell LEF: $cell_lef"
read_lef $cell_lef

puts "==> Reading mapped netlist: $netlist_file"
read_verilog $netlist_file

puts "==> Linking design: aft_synth_top"
link_design aft_synth_top

puts "==> Reading SDC constraints: $sdc_file"
read_sdc $sdc_file

puts "==> Checking unconstrained paths"
check_setup -unconstrained_endpoints

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
