vlib work
vlog -sv -cover bcesf -incdir ../../../../bus/apb/include -incdir ../../include \
    ../../../../bus/apb/include/apb_if.sv \
    ../../include/digital_io_mux_if.sv \
    ../../include/digital_io_mux_cell_if.sv \
    ../../rtl/digital_io_mux_cell.sv \
    ../../rtl/digital_io_mux_apb.sv \
    ../../rtl/digital_io_mux.sv \
    ../../../../digital_lib/sync_2ff.sv \
    ../tb/tb_digital_io_mux.sv
vsim -c -voptargs=+acc -coverage -L work tb_digital_io_mux
coverage save -onexit coverage.ucdb
run -all
coverage report -details -annotate -file coverage_report.txt
quit -f
