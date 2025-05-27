import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

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

    dut.rst.value = 1
    await RisingEdge(dut.clk)

    # Reset
    dut.rst.value = 0
    dut.bias_valid_in.value = 0 # this would enable the PE to start processing the inputs. but it doesnt here
    dut.bias_switch_in.value = 0
    dut.load_bias_in.value = 1
    dut.bias_scalar_in.value = to_fixed(5.0)
    # Load bias
    await RisingEdge(dut.clk)

    dut.load_bias_in.value = 1
    dut.bias_scalar_in.value = to_fixed(8.0)
    dut.bias_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.load_bias_in.value = 1
    dut.bias_sys_data_in.value = to_fixed(10.0)
    dut.bias_valid_in.value = 1
    dut.bias_switch_in.value = 1
    await RisingEdge(dut.clk)
    
    dut.bias_sys_data_in.value = to_fixed(6.0) # this shouldnt be read!
    dut.load_bias_in.value = 0
    dut.bias_valid_in.value = 0
    dut.bias_switch_in.value = 0
    # Check output
    await ClockCycles(dut.clk, 3)
