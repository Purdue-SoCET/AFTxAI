# synth/scripts/physical_design.tcl
# OpenROAD Macro-Aware Physical Placement and High-Fanout Repair
# Selectable SRAM backend:
#   SRAM_BACKEND=0 : OpenRAM (sky130_sram_1rw1r_64x256_8) -> /work/synth/out_physical
#   SRAM_BACKEND=1 : SRAM22  (sram22_256x64m4w8)          -> /work/synth/out_physical_sram22

if {[info exists ::env(SRAM_BACKEND)]} {
    set sram_backend $::env(SRAM_BACKEND)
} else {
    set sram_backend 1
}

if {$sram_backend == 1} {
    puts "=== Physical Flow: SRAM22 Backend Selected ==="
    set out_dir "/work/synth/out_physical_sram22"
    set sram_lef "/work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8.lef"
    set sram_lib "/work/synth/sram22/sram22_256x64m4w8/sram22_256x64m4w8_tt_025C_1v80.lib"
    set netlist  "/work/synth/out_sram22/netlist_sta_linked.v"
    set macro_prefix "dut.gen_sram_ram.gen_sram22.u_sram_banked.gen_sram_banks"
    # SRAM22 macro: 690.120 um (X) x 291.640 um (Y)
    set macro_w 690.12
    set macro_h 291.64
} else {
    puts "=== Physical Flow: OpenRAM Backend Selected ==="
    set out_dir "/work/synth/out_physical"
    set sram_lef "/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.lef"
    set sram_lib "/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8_TT_1p8V_25C.lib"
    set netlist  "/work/synth/out_sram/netlist_sta_linked.v"
    set macro_prefix "dut.gen_sram_ram.u_sram_banked.gen_sram_banks"
    # OpenRAM macro: 1040.760 um (X) x 403.035 um (Y)
    set macro_w 1040.76
    set macro_h 403.035
}

file mkdir $out_dir

set tech_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd.tlef"
set cell_lef "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lef/sky130_fd_sc_hd_merged.lef"
set std_lib  "/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set sdc      "/work/synth/aft_top.sdc"
set top_module "aft_synth_top"

puts "============================================================"
puts " Stage 0: Reading Libraries and Structural Netlist"
puts "============================================================"
read_liberty $std_lib
read_liberty $sram_lib

read_lef $tech_lef
read_lef $cell_lef
read_lef $sram_lef

read_verilog $netlist
link_design $top_module
read_sdc $sdc

puts "\n============================================================"
puts " CHECKPOINT 1: Unplaced, Untouched Netlist STA Baseline"
puts "============================================================"
report_worst_slack -max
report_worst_slack -min
report_tns
report_checks -path_delay max -fields {capacitance slew input_pins nets} -format full_clock_expanded -endpoint_path_count 1 > "$out_dir/01_unplaced_worst_path.rpt"
report_checks -path_delay max -endpoint_path_count 10 > "$out_dir/01_unplaced_top10.rpt"
report_check_types -max_slew -max_capacitance -max_fanout -violators > "$out_dir/01_unplaced_drc_violators.rpt"

puts "\n============================================================"
puts " Stage 1: Floorplan Initialization"
puts "============================================================"
# Die Area: 3200 x 3200 um (10.24 mm^2)
# Core Area: 3100 x 3100 um with 50 um margin around edges
# Sites: unithd (0.46 um width x 2.72 um height)
initialize_floorplan \
    -die_area "0 0 3200 3200" \
    -core_area "50 50 3150 3150" \
    -site "unithd"

# Configure standard routing tracks on li1 through met5
make_tracks li1  -x_offset 0.23 -x_pitch 0.46 -y_offset 0.17 -y_pitch 0.34
make_tracks met1 -x_offset 0.17 -x_pitch 0.34 -y_offset 0.17 -y_pitch 0.34
make_tracks met2 -x_offset 0.23 -x_pitch 0.46 -y_offset 0.23 -y_pitch 0.46
make_tracks met3 -x_offset 0.34 -x_pitch 0.68 -y_offset 0.34 -y_pitch 0.68
make_tracks met4 -x_offset 0.46 -x_pitch 0.92 -y_offset 0.46 -y_pitch 0.92
make_tracks met5 -x_offset 0.80 -x_pitch 1.60 -y_offset 0.80 -y_pitch 1.60

# Set wire RC early for accurate wire parasitic models across all stages
set_wire_rc -layer met3

puts "\n============================================================"
puts " Stage 2: Physical SRAM Macro Placement"
puts "============================================================"

if {$sram_backend == 1} {
    # SRAM22 arrangement:
    # 2 columns of 4 rows
    # Col 0: X = 150.42 (snapped to 0.46 um grid: 327 * 0.46 = 150.42)
    # Col 1: X = 2350.14 (snapped to 0.46 um grid: 5109 * 0.46 = 2350.14)
    # Central routing channel: 2350.14 - (150.42 + 690.12) = 1509.60 um wide!
    # Row Y coordinates (snapped to 2.72 um grid: Y % 2.72 == 0):
    #   Row 0: Y = 149.60 (55 * 2.72) -> top: 441.24
    #   Row 1: Y = 700.40 (257.5 -> snap 258*2.72 = 701.76) -> top: 993.40
    #   Row 2: Y = 1300.16 (snap 478*2.72 = 1300.16) -> top: 1591.80
    #   Row 3: Y = 1901.28 (snap 699*2.72 = 1901.28) -> top: 2192.92
    set col0_x 150.42
    set col1_x 2350.14
    set rows_y [list 149.60 701.76 1300.16 1901.28]
} else {
    set col0_x 100.28
    set col1_x 1900.26
    set rows_y [list 100.64 700.40 1300.16 1902.64]
}

# Column 0: Banks 0-3 (Orientation R0)
for {set i 0} {$i < 4} {incr i} {
    set inst_name "${macro_prefix}\\\[$i\\\].u_sram"
    set y_coord [lindex $rows_y $i]
    puts "Placing $inst_name at ($col0_x, $y_coord) R0"
    place_macro -macro_name $inst_name -location [list $col0_x $y_coord] -orientation R0 -snap_to_site_grid
}

# Column 1: Banks 4-7 (Orientation R0)
for {set i 4} {$i < 8} {incr i} {
    set inst_name "${macro_prefix}\\\[$i\\\].u_sram"
    set y_coord [lindex $rows_y [expr {$i - 4}]]
    puts "Placing $inst_name at ($col1_x, $y_coord) R0"
    place_macro -macro_name $inst_name -location [list $col1_x $y_coord] -orientation R0 -snap_to_site_grid
}

# Create placement blockages covering macro bounding boxes + 5.0 um halo on left/right/top/bottom
# This completely prevents standard cells from abutting or entering macro boundaries,
# ensuring both movable and fixed legality checks pass 100% cleanly!
puts "\nAdding placement blockages around SRAM macros for complete halo isolation..."
for {set i 0} {$i < 4} {incr i} {
    set y0 [lindex $rows_y $i]
    set y1 [expr {$y0 + $macro_h}]
    # Blockage for Col 0 macro + 5 um halo
    create_blockage -region [list [expr {$col0_x - 5.0}] [expr {$y0 - 5.0}] [expr {$col0_x + $macro_w + 5.0}] [expr {$y1 + 5.0}]]
    # Blockage for Col 1 macro + 5 um halo
    create_blockage -region [list [expr {$col1_x - 5.0}] [expr {$y0 - 5.0}] [expr {$col1_x + $macro_w + 5.0}] [expr {$y1 + 5.0}]]
}

puts "\n============================================================"
puts " Stage 3: Global Placement"
puts "============================================================"
global_placement -density 0.55 -skip_io

puts "\n============================================================"
puts " CHECKPOINT 2: Globally Placed (Before Buffer Repair)"
puts "============================================================"
estimate_parasitics -placement
report_worst_slack -max
report_worst_slack -min
report_tns
report_checks -path_delay max -fields {capacitance slew input_pins nets} -format full_clock_expanded -endpoint_path_count 1 > "$out_dir/02_global_place_worst_path.rpt"
report_checks -path_delay max -endpoint_path_count 10 > "$out_dir/02_global_place_top10.rpt"
report_check_types -max_slew -max_capacitance -max_fanout -violators > "$out_dir/02_global_place_drc_violators.rpt"

puts "\n============================================================"
puts " Stage 4: High-Fanout, Slew, and Capacitance Repair"
puts "============================================================"
set_wire_rc -layer met3
repair_design -verbose

puts "\n============================================================"
puts " CHECKPOINT 3: Globally Placed (After Buffer Repair)"
puts "============================================================"
estimate_parasitics -placement
report_worst_slack -max
report_worst_slack -min
report_tns
report_checks -path_delay max -fields {capacitance slew input_pins nets} -format full_clock_expanded -endpoint_path_count 1 > "$out_dir/03_post_repair_worst_path.rpt"
report_checks -path_delay max -endpoint_path_count 10 > "$out_dir/03_post_repair_top10.rpt"
report_check_types -max_slew -max_capacitance -max_fanout -violators > "$out_dir/03_post_repair_drc_violators.rpt"

puts "\n============================================================"
puts " Stage 5: Detailed Placement / Legalization & Full Legality Check"
puts "============================================================"
place_pins -hor_layers met3 -ver_layers met2

detailed_placement

# Run full legality check (both movable and fixed instances!)
puts "Checking complete placement legality..."
check_placement -verbose -report_file_name "$out_dir/check_placement_full.rpt"

puts "\n============================================================"
puts " CHECKPOINT 4: Detailed Placement Complete"
puts "============================================================"
estimate_parasitics -placement
report_worst_slack -max
report_worst_slack -min
report_tns
report_checks -path_delay max -fields {capacitance slew input_pins nets} -format full_clock_expanded -endpoint_path_count 1 > "$out_dir/04_detailed_place_worst_path.rpt"
report_checks -path_delay max -endpoint_path_count 10 > "$out_dir/04_detailed_place_top10.rpt"
report_check_types -max_slew -max_capacitance -max_fanout -violators > "$out_dir/04_detailed_place_drc_violators.rpt"

# Save placed DEF and database
write_def "$out_dir/aft_synth_top_placed.def"
write_db "$out_dir/aft_synth_top_placed.odb"

puts "\n============================================================"
puts " Physical Placement Flow Complete!"
puts "============================================================"
exit
