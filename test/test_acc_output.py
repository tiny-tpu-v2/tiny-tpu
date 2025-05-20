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
async def test_acc_output(dut):
    """Test the PE module with a variety of fixed-point inputs."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    dut.acc_valid_i.value = 0
    dut.acc_data_in.value = 0
    
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    dut.acc_valid_i.value = 1
    dut.acc_data_in.value = 5
    await RisingEdge(dut.clk)
    dut.acc_data_in.value = 10
    await RisingEdge(dut.clk)
    dut.acc_data_in.value = 15
    await RisingEdge(dut.clk)

    dut.acc_valid_i.value = 0   # Set acc_valid_i to 0 to stop storing values. It wont store anything after this

    dut.acc_data_in.value = 20
    await RisingEdge(dut.clk)
    dut.acc_valid_i.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)

