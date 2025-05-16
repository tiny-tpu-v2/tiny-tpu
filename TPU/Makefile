SOURCES = src/dut.sv
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

# show_%: %.vcd %.gtkw (%.gtkw file allows me to config my waveform) but MUST have the gtkw file to work
show_%: %.vcd %.gtkw
	gtkwave $^

# general recipes
lint:
	verible-verilog-lint src/*sv --rules_config verible.rules

clean:
	rm -rf *vcd sim_build test/__pycache__

.PHONY: clean