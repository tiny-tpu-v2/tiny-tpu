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
# ********** IF YOU HAVE A NEW VERILOG FILE, ADD IT TO THE SOURCES VARIABLE
SOURCES = src/pe.sv \
          src/leaky_relu_child.sv \
          src/leaky_relu_parent.sv \
          src/leaky_relu_derivative_child.sv \
          src/leaky_relu_derivative_parent.sv \
          src/systolic.sv \
          src/bias_child.sv \
          src/bias_parent.sv \
          src/fixedpoint.sv \
          src/control_unit.sv \
          src/unified_buffer.sv \
          src/vpu.sv \
          src/loss_parent.sv \
		  src/loss_child.sv \
		  src/tpu.sv \
		  src/gradient_descent.sv

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

test_leaky_relu: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s leaky_relu -s dump -g2012 $(SOURCES) test/dump_leaky_relu.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_leaky_relu $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv test.vcd waveforms/ 2>/dev/null || true

test_systolic: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s systolic -s dump -g2012 $(SOURCES) test/dump_systolic.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_systolic $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv systolic.vcd waveforms/ 2>/dev/null || true

test_nn: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s nn -s dump -g2012 $(SOURCES) test/dump_nn.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_nn $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv nn.vcd waveforms/ 2>/dev/null || true

test_bias: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s bias -s dump -g2012 $(SOURCES) test/dump_bias.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_bias $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv bias.vcd waveforms/ 2>/dev/null || true

test_input_acc: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s input_acc -s dump -g2012 $(SOURCES) test/dump_input_acc.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_input_acc $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv input_acc.vcd waveforms/ 2>/dev/null || true

test_weight_acc: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s weight_acc -s dump -g2012 $(SOURCES) test/dump_weight_acc.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_weight_acc $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv weight_acc.vcd waveforms/ 2>/dev/null || true

test_cu: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s control_unit -s dump -g2012 $(SOURCES) test/dump_cu.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_cu $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv cu.vcd waveforms/ 2>/dev/null || true

test_unified_buffer: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s unified_buffer -s dump -g2012 $(SOURCES) test/dump_unified_buffer.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_unified_buffer $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv unified_buffer.vcd waveforms/ 2>/dev/null || true

# Loss module test

test_loss_child: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s loss_child -s dump -g2012 $(SOURCES) test/dump_loss_child.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_loss_child $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv loss_child.vcd waveforms/ 2>/dev/null || true

test_loss_parent: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s loss_parent -s dump -g2012 $(SOURCES) test/dump_loss_parent.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_loss_parent $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv loss_parent.vcd waveforms/ 2>/dev/null || true

# Leaky ReLU module tests
test_leaky_relu_child: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s leaky_relu_child -s dump -g2012 $(SOURCES) test/dump_leaky_relu_child.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_leaky_relu_child $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv leaky_relu_child.vcd waveforms/ 2>/dev/null || true

test_leaky_relu_parent: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s leaky_relu_parent -s dump -g2012 $(SOURCES) test/dump_leaky_relu_parent.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_leaky_relu_parent $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv leaky_relu_parent.vcd waveforms/ 2>/dev/null || true

test_leaky_relu_derivative_child: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s leaky_relu_derivative_child -s dump -g2012 $(SOURCES) test/dump_leaky_relu_derivative_child.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_leaky_relu_derivative_child $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv leaky_relu_derivative_child.vcd waveforms/ 2>/dev/null || true

test_leaky_relu_derivative_parent: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s leaky_relu_derivative_parent -s dump -g2012 $(SOURCES) test/dump_leaky_relu_derivative_parent.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_leaky_relu_derivative_parent $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv leaky_relu_derivative_parent.vcd waveforms/ 2>/dev/null || true

# Bias module tests
test_bias_child: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s bias_child -s dump -g2012 $(SOURCES) test/dump_bias_child.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_bias_child $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv bias_child.vcd waveforms/ 2>/dev/null || true

test_bias_parent: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s bias_parent -s dump -g2012 $(SOURCES) test/dump_bias_parent.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_bias_parent $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv bias_parent.vcd waveforms/ 2>/dev/null || true

# Vector Processing unit test
test_vpu: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s vpu -s dump -g2012 $(SOURCES) test/dump_vpu.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_vpu $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv vpu.vcd waveforms/ 2>/dev/null || true

test_tpu: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s tpu -s dump -g2012 $(SOURCES) test/dump_tpu.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_tpu $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv tpu.vcd waveforms/ 2>/dev/null || true

test_gradient_descent: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s gradient_descent -s dump -g2012 $(SOURCES) test/dump_gradient_descent.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_gradient_descent $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv gradient_descent.vcd waveforms/ 2>/dev/null || true


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
