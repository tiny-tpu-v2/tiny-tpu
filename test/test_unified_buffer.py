import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_unified_buffer(dut):
    # create a clock (10 nanoseconds clock period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start()) # start the clock

    # clock is low here
     # rst the DUT (device under test)
    dut.rst.value = 1
    dut.ub_write_data_1_in.value = 0
    dut.ub_write_data_2_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    await RisingEdge(dut.clk) # values change here

    dut.rst.value = 0
    dut.ub_write_start_in = 1
    dut.ub_write_data_1_in.value = to_fixed(2.3)
    dut.ub_write_valid_1_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_write_data_1_in.value = to_fixed(3.4)
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_data_2_in.value = to_fixed(5.6)
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_write_data_1_in.value = to_fixed(7.8)
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_data_2_in.value = to_fixed(9.11)
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)

    # Stop writing on this clock cycle (value won't be written to memory)
    dut.ub_write_start_in = 0          
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_data_2_in.value = to_fixed(10.3)
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    await RisingEdge(dut.clk)

    # waits for 10 clock cycles
    await ClockCycles(dut.clk, 10)


