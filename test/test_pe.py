import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def to_fixed(val, frac_bits=8):
    return int(round(val * (1 << frac_bits))) & 0xFFFF

def from_fixed(val, frac_bits=8):
    if val >= (1 << 15):
        val -= (1 << 16)
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_pe(dut):
    """Test the PE module with a variety of fixed-point inputs."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    dut.pe_valid_in.value = 0 # this would enable the PE to start processing the inputs. but it doesnt here

    dut.load_weight.value = 0
    dut.input_in.value = to_fixed(0.0)
    dut.weight.value = to_fixed(0.0)
    dut.psum_in.value = to_fixed(0.0)
    await RisingEdge(dut.clk)

    # Release reset
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Stage the weights
    dut.load_weight.value = 1;
    dut.weight.value = to_fixed(10.0) # this gets latched in the next clock cycle
    await RisingEdge(dut.clk)

    dut.load_weight.value = 0; # turn off load weight signal
    dut.weight.value = to_fixed(10.0) # this doesnt matter cus load weight off
    await RisingEdge(dut.clk)

    # stage the psum
    dut.psum_in.value = to_fixed(50.0)
    dut.input_in.value = to_fixed(2.0)
    await RisingEdge(dut.clk)

    dut.pe_valid_in.value = 1; 
    await RisingEdge(dut.clk)


    # Turn off valid input signal
    dut.pe_valid_in.value = 0;  # set valid in signal to zero
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Check output
    
