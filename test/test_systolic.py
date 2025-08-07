# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

X = [
    [2., 2.],
    [0., 1.],
    [1., 0.],
    [1., 1.]
]

W1 = [
    [0.2985, -0.5792], 
    [0.0913, 0.4234]
]

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

# Calculating X @ W1^T
# Expected output:
# [-0.5614  1.0294]
# [-0.5792  0.4234]
# [ 0.2985  0.0913]
# [-0.2807  0.5147]


# First column of accept weight signal turns off -> set switch flag on and set first row start signal on (start loading in X)
@cocotb.test()
async def test_systolic_array(dut): 

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.sys_accept_w_1.value = 0
    dut.sys_accept_w_2.value = 0
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    # load in transposed weight matrix:
    dut.rst.value = 0
    dut.sys_weight_in_11.value = to_fixed(W1[0][1])
    dut.sys_accept_w_1.value = 1
    await RisingEdge(dut.clk)

    dut.sys_weight_in_11.value = to_fixed(W1[0][0])
    dut.sys_accept_w_1.value = 1
    dut.sys_weight_in_12.value = to_fixed(W1[1][1])
    dut.sys_accept_w_2.value = 1
    await RisingEdge(dut.clk)

    dut.sys_accept_w_1.value = 0
    dut.sys_weight_in_12.value = to_fixed(W1[1][0])
    dut.sys_accept_w_2.value = 1
    dut.sys_switch_in.value = 1
    dut.sys_data_in_11.value = to_fixed(X[0][0])
    dut.sys_start_1.value = 1
    await RisingEdge(dut.clk)

    dut.sys_accept_w_1.value = 0
    dut.sys_accept_w_2.value = 0
    dut.sys_switch_in.value = 0
    dut.sys_data_in_11.value = to_fixed(X[1][0])
    dut.sys_start_1.value = 1
    dut.sys_data_in_21.value = to_fixed(X[0][1])
    dut.sys_start_2.value = 1
    await RisingEdge(dut.clk)

    dut.sys_data_in_11.value = to_fixed(X[2][0])
    dut.sys_start_1.value = 1
    dut.sys_data_in_21.value = to_fixed(X[1][1])
    dut.sys_start_2.value = 1
    await RisingEdge(dut.clk)

    dut.sys_data_in_11.value = to_fixed(X[3][0])
    dut.sys_start_1.value = 1
    dut.sys_data_in_21.value = to_fixed(X[2][1])
    dut.sys_start_2.value = 1
    await RisingEdge(dut.clk)

    dut.sys_start_1.value = 0
    dut.sys_data_in_21.value = to_fixed(X[3][1])
    dut.sys_start_2.value = 1
    await RisingEdge(dut.clk)

    dut.sys_start_1.value = 0
    dut.sys_start_2.value = 0
    await RisingEdge(dut.clk)
    
    await ClockCycles(dut.clk, 10)