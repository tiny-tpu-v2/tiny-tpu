# FPGA variables
PROJECT = fpga/tpu_project
SOURCES = src/dut.sv
ICEBREAKER_DEVICE = up5k
ICEBREAKER_PIN_DEF = fpga/icebreaker.pcf
ICEBREAKER_PACKAGE = sg48
SEED = 1

# COCOTB variables
export COCOTB_REDUCED_LOG_FMT=1
export PYTHONPATH := test:$(PYTHONPATH)
export LIBPYTHON_LOC=$(shell cocotb-config --libpython)

all: test_dut

# if you run rules with NOASSERT=1 it will set PYTHONOPTIMIZE, which turns off assertions in the tests
test_dut:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s dut -s dump -g2012 src/dut.sv test/dump_dut.sv 
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test_dut vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml


# will need to make another make command for testing my entire chip (command should be just like the tpu command but add the tt_um_tpu src files)

# show_%: %.vcd %.gtkw (%.gtkw file allows me to config my waveform) but MUST have the gtkw file to work
# show_%: %.vcd %.gtkw
show_%: %.vcd
	gtkwave $^

# FPGA recipes
show_synth_%: src/%.sv
	yosys -p "read_verilog $<; proc; opt; show -colors 2 -width -signed"

%.json: $(SOURCES)
	yosys -l fpga/yosys.log -p 'synth_ice40 -top dut -json $(PROJECT).json' $(SOURCES)

%.asc: %.json $(ICEBREAKER_PIN_DEF)
	nextpnr-ice40 -l fpga/nextpnr.log --seed $(SEED) --freq 20 --package $(ICEBREAKER_PACKAGE) --$(ICEBREAKER_DEVICE) --asc $@ --pcf $(ICEBREAKER_PIN_DEF) --json $

%.bin: %.asc
	icepack $< $@

prog: $(PROJECT).bin
	iceprog $

# general recipes
lint:
	verible-verilog-lint src/*sv --rules_config verible.rules

clean:
	rm -rf *vcd sim_build fpga/*log fpga/*bin test/__pycache__

.PHONY: clean