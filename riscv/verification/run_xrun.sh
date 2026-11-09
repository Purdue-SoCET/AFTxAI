#!/bin/bash
export XCELIUM_HOME="/package/eda/cadence/XCELIUM2303"
export PATH="/package/eda/cadence/XCELIUM2303/bin:$PATH"
export CDS_LIC_FILE="1720@marina.ecn.purdue.edu"

xrun -sv ../include/*.sv ../rtl/datapath/*.sv ../rtl/caches/*.sv ../rtl/memory/*.sv ../rtl/*.sv tb/ahb_memory.sv uvm/tb_top.sv -access +rwc
