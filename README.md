# tiny-tpu

## Setup

### MacOS specific

### Ubuntu specific

## Adding a new module to the tiny-tpu

Follow these steps to add a new module to the project:

### 1. Create the module file

Add your new module file `<MODULE_NAME>.sv` in the `src/` directory.

### 2. Create the dump file

Create `dump_<MODULE_NAME>.sv` in the `test/` directory with the following code:

```systemverilog
module dump();
initial begin
  $dumpfile("waveforms/<MODULE_NAME>.vcd");
  $dumpvars(0, <MODULE_NAME>); 
end
endmodule
```

### 3. Create the test file

Create `test_<MODULE_NAME>.py` in the `test/` directory.

### 4. Update the Makefile

Add your module to the `SOURCES` variable and create a test target:

```makefile
test_<MODULE_NAME>: $(SIM_BUILD_DIR)
	$(IVERILOG) -o $(SIM_VVP) -s <MODULE_NAME> -s dump -g2012 $(SOURCES) test/dump_<MODULE_NAME>.sv
	PYTHONOPTIMIZE=$(NOASSERT) MODULE=test_<MODULE_NAME> $(VVP) -M $(COCOTB_LIBS) -m libcocotbvpi_icarus $(SIM_VVP)
	! grep failure results.xml
	mv <MODULE_NAME>.vcd waveforms/ 2>/dev/null || true
```

### 5. View waveforms

Run the following command to view the generated waveforms:

```bash
gtkwave waveforms/<MODULE_NAME>.vcd
```

## Running commands from Makefile
```bash
make test_<MODULE_NAME>
```
```bash
gtkwave waveform/<MODULE_NAME>
```

## Then, can run the following:
```bash
make show_<MODULE_NAME>
```



## Fixed point vieweing in gtkwave
Right click all signals
Data Format -> Fixed Point Shift -> Specify -> Put in 8 -> OK
Data Format -> Signed Decimal
Data Format -> Fixed Point Shift -> ON



## What is a gtkw file?
Stores the signals for make show_<MODULE_NAME>. Only need to save it once, after running gtkwave waveforms/<MODULE_NAME>.vcd


# one-off (current terminal only)
export GSETTINGS_SCHEMA_DIR=$(brew --prefix)/share/glib-2.0/schemas
gtkwave loss.vcd

^^ run this command is GTKWAVE is not letting u save the waveform!!