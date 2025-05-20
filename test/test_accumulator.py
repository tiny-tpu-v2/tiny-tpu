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
async def test_pe_various_inputs(dut):
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
    dut.acc_data_in.value = 20
    await RisingEdge(dut.clk)
    dut.acc_valid_i.value = 0
    await RisingEdge(dut.clk)

    for i in range(4):
        val = dut.acc_mem[i].value
        print(f"acc_mem[{i}] = {val}")