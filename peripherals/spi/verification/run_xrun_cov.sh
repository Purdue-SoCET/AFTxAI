#!/bin/bash
# Xcelium coverage regression run script for SPI module

module load cadence/xcelium/23.03
module load cadence/vmanager/23.03

mkdir -p work_cov
cd work_cov

cat << 'EOF' > exclude.ccf
// Coverage exclusion for reserved tied-off bits
select_coverage -block -module spi_wrapper
select_coverage -expr -module spi_wrapper
select_coverage -toggle -module spi_wrapper
//deselect_coverage -toggle -module spi_wrapper -instance * -node status.reserved*
//deselect_coverage -toggle -module spi_wrapper -instance * -node ctrl.reserved*
EOF

cat << 'EOF' > imc_report.tcl
load -run cov_work/scope/spi_baseline
report -summary -out coverage_summary.txt -overwrite
report -detail -out cov_details.txt -overwrite
exit
EOF

xrun \
  -sv \
  -coverage all \
  -covoverwrite \
  -covworkdir ./cov_work \
  -covtest spi_baseline \
  -covfile exclude.ccf \
  -access +rwc \
  -incdir ../../rtl \
  -incdir ../../include \
  -incdir ../../../../bus/apb/include \
  ../../../../bus/apb/include/apb_if.sv \
  ../../include/spi_types_pkg.sv \
  ../../include/spi_if.sv \
  ../../rtl/clock_generator.sv \
  ../../rtl/edge_detect_spi.sv \
  ../../rtl/fifo.sv \
  ../../rtl/flex_sr_spi.sv \
  ../../rtl/interrupt_control.sv \
  ../../rtl/controller.sv \
  ../../rtl/spi_wrapper.sv \
  ../tb/tb_spi_top.sv \
  -top tb_spi_top \
  -timescale 1ns/1ps

# Generate coverage report
imc -exec imc_report.tcl
