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
    dut.bias_valid_in.value = 0 # this would enable the PE to start processing the inputs. but it doesnt here
    dut.load_bias_in.value = 0
    # Load bias
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    dut.load_bias_in.value = 1

    await RisingEdge(dut.clk)
    dut.bias_data_in.value = to_fixed(10.0)
    dut.bias_temp_bias_in.value = to_fixed(5.0)
    dut.bias_valid_in.value = 1

    await RisingEdge(dut.clk)
    dut.bias_data_in.value = to_fixed(6.0)
    dut.bias_temp_bias_in.value = to_fixed(8.0)
    dut.bias_valid_in.value = 1

    await RisingEdge(dut.clk)
    dut.bias_data_in.value = to_fixed(3.0)
    dut.bias_temp_bias_in.value = to_fixed(5.0)
    dut.bias_valid_in.value = 1
    

    await RisingEdge(dut.clk)
    dut.bias_data_in.value = to_fixed(5.0)
    dut.bias_temp_bias_in.value = to_fixed(8.0)
    dut.bias_valid_in.value = 0
    dut.load_bias_in.value = 0

    await RisingEdge(dut.clk)
    dut.bias_valid_in.value = 0 # i set this to 0 to make sure the bias doesnt get updated to 3
    
    # dut.bias_data_in.value = to_fixed(12.0)
    # dut.bias_temp_bias_in.value = to_fixed(9.0)

    await RisingEdge(dut.clk)
    # dut.bias_data_in.value = to_fixed(9.0)
    # dut.bias_in.value = to_fixed(3.0)
    dut.bias_valid_in.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Check output
    
