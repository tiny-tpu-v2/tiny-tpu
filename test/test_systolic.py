# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_systolic_array(dut): 

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.sys_accept_w_in.value = 0
    dut.sys_switch_in.value = 0
    dut.sys_weight_in_11.value = to_fixed(0.0)
    dut.sys_weight_in_12.value = to_fixed(0.0)
    dut.sys_data_in_11.value = to_fixed(0.0)
    dut.sys_data_in_12.value = to_fixed(0.0)
    dut.sys_start.value = 0
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # t = 0
    dut.sys_accept_w_in.value = 1
    dut.sys_weight_in_11.value = to_fixed(2.0)
    await RisingEdge(dut.clk)

    # t = 1
    dut.sys_accept_w_in.value = 1
    dut.sys_weight_in_11.value = to_fixed(1.0)
    dut.sys_weight_in_12.value = to_fixed(4.0)
    await RisingEdge(dut.clk) 

    # t = 2
    dut.sys_accept_w_in.value = 0
    dut.sys_switch_in.value = 1
    dut.sys_weight_in_12.value = to_fixed(3.0)
    await RisingEdge(dut.clk)

    # t = 3
    dut.sys_switch_in.value = 0
    dut.sys_start.value = 1 
    dut.sys_data_in_11.value = to_fixed(5.0)
    dut.sys_data_in_12.value = to_fixed(0.0)
    await RisingEdge(dut.clk)

    # t = 4
    dut.sys_start.value = 0
    dut.sys_data_in_11.value = to_fixed(0.0)
    dut.sys_data_in_12.value = to_fixed(6.0)
    await RisingEdge(dut.clk)

    # t = 5
    dut.sys_data_in_12.value = to_fixed(0.0)
    await ClockCycles(dut.clk, 10)