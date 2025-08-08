import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

X = [
 [2, 2],
 [0, 1],
 [1, 0,],
 [1, 1]
]

W1 =[
    [0.2985, -0.5792],
 [0.0913, 0.4234]]

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
    dut.ub_wr_addr_in.value = 0 # begin at addr 0
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

    dut.ub_wr_addr_in.value = 8 ## first weight will be in address 8
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

    # Testing reading X to left side of systolic array
    dut.ub_rd_input_start_in.value = 1
    dut.ub_rd_input_transpose.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in = 8
    await RisingEdge(dut.clk)

    dut.ub_rd_input_start_in.value = 0
    dut.ub_rd_input_transpose.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)

    # Testing reading W1^T so that it can be properly fed into the systolic array
    dut.ub_rd_weight_start_in.value = 1
    dut.ub_rd_weight_transpose.value = 1
    dut.ub_rd_weight_addr_in.value = 9
    dut.ub_rd_weight_loc_in = 4
    await RisingEdge(dut.clk)

    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in = 0
    await RisingEdge(dut.clk)
    
    await ClockCycles(dut.clk, 10)

    # Testing reading W1 so that it can be properly fed into the systolic array
    # for non transpose address = 10 and make transpose = 0
    dut.ub_rd_weight_start_in.value = 1
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 10
    dut.ub_rd_weight_loc_in = 4
    await RisingEdge(dut.clk)

    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in = 0
    await RisingEdge(dut.clk)
    
    await ClockCycles(dut.clk, 10)
    


    
    
