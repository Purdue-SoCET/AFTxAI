VERILATOR_ROOT ?= /usr/share/verilator
VFLAGS = --timing -Wall -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-UNOPTFLAT --assert
INCDIRS = -I../../bus/apb/include -I../../bus/ahb/include -I../../peripherals/gpio/src -I../../peripherals/pwm/src -I../../peripherals/timer/src -I../../peripherals/digital_io_mux/rtl -I../../bus/apb/rtl -I../../bus/bus/apb_ahb_bridge -I../../digital_lib/src -I../../bus/generic -I../../peripherals/interrupt_controller/plic/include -I../../peripherals/interrupt_controller/plic/rtl

SRCS = \
	../../digital_lib/src/sync_2ff.sv \
	../../bus/apb/rtl/apb_interconnect.sv \
	../../bus/bus/apb_ahb_bridge/ahb2apb.sv \
	../../peripherals/gpio/src/gpio_apb.sv \
	../../peripherals/gpio/src/gpio_apb_wrapper.sv \
	../../peripherals/pwm/src/pwm_core.sv \
	../../peripherals/pwm/src/pwm_apb_wrapper.sv \
	../../peripherals/timer/src/timer_apb.sv \
	../../peripherals/timer/src/timer_apb_wrapper.sv \
	../../peripherals/digital_io_mux/rtl/digital_io_mux_apb.sv \
	../../peripherals/interrupt_controller/plic/rtl/plic.sv \
	peripheral_subsystem.sv \
	peripheral_subsystem_tb.sv

all: lint run

lint:
	verilator --lint-only $(VFLAGS) $(INCDIRS) peripheral_subsystem.sv

run:
	verilator --binary -j 0 --trace $(VFLAGS) $(INCDIRS) $(SRCS) --top-module peripheral_subsystem_tb
	./obj_dir/Vperipheral_subsystem_tb

run_neg:
	verilator --binary -j 0 --trace $(VFLAGS) $(INCDIRS) $(SRCS) --top-module peripheral_subsystem_tb
	if ./obj_dir/Vperipheral_subsystem_tb +EXPECT_FAILURE=1 > run_neg.log 2>&1; then \
		echo "Expected simulator to fail but it returned 0 exit code"; exit 1; \
	fi
	grep "Intentional failure triggered" run_neg.log

run_overlap:
	verilator --binary -j 0 --trace $(VFLAGS) $(INCDIRS) $(SRCS) --top-module peripheral_subsystem_tb -DTEST_OVERLAP
	if ./obj_dir/Vperipheral_subsystem_tb > run_overlap.log 2>&1; then \
		echo "Expected simulator to fail on overlap but it passed"; exit 1; \
	fi
	grep "Overlapping APB selection detected" run_overlap.log

clean:
	rm -rf obj_dir
