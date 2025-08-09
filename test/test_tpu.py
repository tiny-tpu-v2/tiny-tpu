import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge,  ClockCycles
import numpy as np

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

# X -> H1

# input:
X = np.array([[2., 2.],
              [0., 1.],
              [1., 0.],
              [1., 1.]])
# weight 1
W1 = np.array([
    [0.2985, -0.5792], 
    [0.0913, 0.4234]
])

# bias 1
B1 = [-0.4939, 0.189]

# Expected output from systolic array (Z1 pre bias):
# [-0.5614  1.0294]
# [-0.5792  0.4234]
# [ 0.2985  0.0913]
# [-0.2807  0.5147]

# Expected output from VPU (H1):
# [-0.5277  1.2184]
# [-0.5366  0.6124]
# [-0.0977  0.2803]
# [-0.3873  0.7037]

@cocotb.test()
async def test_tpu(dut): 
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.ub_wr_addr_in.value = 0
    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_host_data_in_1.value = 0
    dut.ub_wr_host_data_in_2.value = 0
    dut.ub_wr_host_valid_in_1.value = 0
    dut.ub_wr_host_valid_in_2.value = 0
    dut.ub_rd_input_transpose.value = 0
    dut.ub_rd_input_start_in.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in.value = 0
    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in.value = 0
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    # set forward pass data pathway
    dut.vpu_data_pathway.value = 0b1100
    dut.vpu_leak_factor_in.value = to_fixed(0.5)

    # Load X into UB
    dut.rst.value = 0
    dut.ub_wr_addr_in.value = 0
    dut.ub_wr_addr_valid_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_host_data_in_1.value = to_fixed(X[0][0])
    dut.ub_wr_host_valid_in_1.value = 1
    await RisingEdge(dut.clk)

    for i in range(3):
        dut.ub_wr_host_data_in_1.value = to_fixed(X[i+1][0])
        dut.ub_wr_host_valid_in_1.value = 1
        dut.ub_wr_host_data_in_2.value = to_fixed(X[i][1])
        dut.ub_wr_host_valid_in_2.value = 1
        await RisingEdge(dut.clk)

    # Load W1 into UB
    dut.ub_wr_host_data_in_1.value = to_fixed(W1[0][0])
    dut.ub_wr_host_valid_in_1.value = 1
    dut.ub_wr_host_data_in_2.value = to_fixed(X[3][1])
    dut.ub_wr_host_valid_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in_1.value = to_fixed(W1[1][0])
    dut.ub_wr_host_valid_in_1.value = 1
    dut.ub_wr_host_data_in_2.value = to_fixed(W1[0][1])
    dut.ub_wr_host_valid_in_2.value = 1
    await RisingEdge(dut.clk)

    # Load B1 into UB
    dut.ub_wr_host_data_in_1.value = to_fixed(B1[0])
    dut.ub_wr_host_valid_in_1.value = 1
    dut.ub_wr_host_data_in_2.value = to_fixed(W1[1][1])
    dut.ub_wr_host_valid_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in_1.value = 0
    dut.ub_wr_host_valid_in_1.value = 0
    dut.ub_wr_host_data_in_2.value = to_fixed(B1[1])
    dut.ub_wr_host_valid_in_2.value = 1
    await RisingEdge(dut.clk)

    # Load W1^T into systolic array (reading W1 from UB)
    dut.ub_rd_weight_start_in.value = 1
    dut.ub_rd_weight_transpose.value = 1
    dut.ub_rd_weight_addr_in.value = 9
    dut.ub_rd_weight_loc_in.value = 4

    dut.ub_wr_host_data_in_2.value = 0
    dut.ub_wr_host_valid_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_input_start_in.value = 1
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in.value = 8
    await RisingEdge(dut.clk)

    dut.ub_rd_input_start_in.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    # Read B1 from UB for 4 clock cycles
    dut.ub_rd_bias_start_in.value = 1
    dut.ub_rd_bias_addr_in.value = 12
    dut.ub_rd_bias_loc_in.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_bias_start_in.value = 1
    dut.ub_rd_bias_addr_in.value = 12
    dut.ub_rd_bias_loc_in.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_bias_start_in.value = 1
    dut.ub_rd_bias_addr_in.value = 12
    dut.ub_rd_bias_loc_in.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_bias_start_in.value = 1
    dut.ub_rd_bias_addr_in.value = 12
    dut.ub_rd_bias_loc_in.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_bias_start_in.value = 0
    dut.ub_rd_bias_addr_in.value = 0
    dut.ub_rd_bias_loc_in.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)

    