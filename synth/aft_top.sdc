# SDC constraints for AFTxAI aft_synth_top
# Target frequency: 100 MHz (10.0 ns period) based on top_tb.sv baseline

create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

# Standard input/output delays (assume 20% budget for I/O)
set_input_delay -clock clk 2.0 [all_inputs -no_clocks]
set_output_delay -clock clk 2.0 [all_outputs]
