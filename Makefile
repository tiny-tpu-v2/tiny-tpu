# Simulation parameters
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Use the correct file path and module name
VERILOG_SOURCES += $(PWD)/divider.sv

# Enable SystemVerilog support for Icarus Verilog
IVERILOG_ARGS += -g2012

test_pe:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s pe -s dump -g2012 src/pe.sv tests/dump_pe.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_pe vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_systolic:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s systolic -s dump -g2012 src/pe.sv src/systolic.sv tests/dump_systolic.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_systolic vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_leaky_relu:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s leaky_relu -s dump src/leaky_relu.sv tests/dump_leaky_relu.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_leaky_relu vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_layer1:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s layer1 -s dump src/pe.sv src/systolic.sv src/leaky_relu.sv src/layer1.sv tests/dump_layer1.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_layer1 vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_exp:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s exp -s dump src/exp.sv tests/dump_exp.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_exp vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_max:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s max -s dump src/fifo.sv src/max.sv tests/dump_max.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_max vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_subtract:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s subtract -s dump src/subtract.sv tests/dump_subtract.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_subtract vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

test_softmax:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog $(IVERILOG_ARGS) -o sim_build/sim.vvp -s softmax -s dump src/fifo.sv src/exp.sv src/max.sv src/divider.sv src/softmax.sv tests/dump_softmax.sv
	PYTHONOPTIMIZE=${NOASSERT} MODULE=tests.test_softmax vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp
	! grep failure results.xml

# Other targets
clean::
	rm -rf __pycache__
	rm -rf sim_build 
	rm -f results.xml
	rm -f pe.vcd