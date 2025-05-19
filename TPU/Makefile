#================DO NOT MODIFY BELOW===================== Compiler and simulator settings
IVERILOG = iverilog
VVP = vvp
COCOTB_PREFIX = $(shell cocotb-config --prefix)


COCOTB_LIBS = $(COCOTB_PREFIX)/cocotb/libs

SIM_BUILD_DIR = sim_build
SIM_VVP = $(SIM_BUILD_DIR)/sim.vvp

# Environment variables
export COCOTB_REDUCED_LOG_FMT=1
export LIBPYTHON_LOC=$(shell cocotb-config --libpython)
export PYTHONPATH := test:$(PYTHONPATH)

#=============== MODIFY BELOW ======================
# IF YOU HAVE A NEW VERILOG FILE, ADD IT TO THE SOURCES VARIABLE
SOURCES = src/pe.sv src/systolic_array.sv src/test.sv

# MODIFY 1) variable next to -s 
# MODIFY 2) variable next to $(SOURCES)
# MODIFY 3) variable right of MODULE=
# MODIFY 4) file name next to mv (i.e. pe.vcd)


# Test targets
test_pe: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s pe -s dump -g2012 $(SOURCES) test/dump_pe.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_pe $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv pe.vcd waveforms/ 2>/dev/null || true

test_test: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s test -s dump -g2012 $(SOURCES) test/dump_test.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_test $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv test.vcd waveforms/ 2>/dev/null || true


# ============ DO NOT MODIFY BELOW THIS LINE ==============

# Create simulation build directory and waveforms directory
$(SIM_BUILD_DIR):
	mkdir -p $(SIM_BUILD_DIR)
	mkdir -p waveforms

# Waveform viewing
show_%: waveforms/%.vcd waveforms/%.gtkw
	gtkwave $^

# Linting
lint:
	verible-verilog-lint src/*sv --rules_config verible.rules

# Cleanup
clean:
	rm -rf waveforms/*vcd $(SIM_BUILD_DIR) test/__pycache__

.PHONY: clean