import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

X = [
    [1, 2],
    [3, 4],
    [5, 6],
    [7, 8],
]

W1 = [
    [-1, -2],
    [-3, -4]
]

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_unified_buffer(dut):
    # create a clock (10 nanoseconds clock period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start()) # start the clock

    # Test addressed writing

    # reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)

    # set the address of where to start writing from
    dut.rst.value = 0
    dut.ub_wr_addr_in.value = 2 # begin at addr 2
    dut.ub_wr_addr_valid_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_addr_in.value = 12 # THIS SHOULD NOT LATCH INTO THE ADDR REGISTER 
    dut.ub_wr_addr_valid_in.value = 0    

    dut.ub_wr_data_in_1.value = to_fixed(X[0][0])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(X[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)


    dut.ub_wr_data_in_1.value = to_fixed(X[2][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[1][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(X[3][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[2][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)


    dut.ub_wr_data_in_2.value = to_fixed(X[3][1])
    dut.ub_wr_valid_data_in_1.value = 0

    dut.ub_wr_addr_in.value = 13
    dut.ub_wr_addr_valid_in.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)
    
    dut.ub_wr_data_in_1.value = to_fixed(W1[0][0])
    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(W1[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(W1[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    dut.ub_wr_addr_valid_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_2.value = to_fixed(W1[1][1])
    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    
    await ClockCycles(dut.clk, 10)
    

    
