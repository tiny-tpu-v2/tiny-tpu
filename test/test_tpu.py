import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import numpy as np

### TODO: optimize for clk cycles later: focus on functionality first
# For transposed weight matrices set the start address one address above where the first element of the weight matrix is stored in UB

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF


# input:
X = np.array([[0., 0.],
              [0., 1.],
              [1., 0.],
              [1., 1.]])

Y = np.array([0, 1, 1, 0])

# weight layer 1
W1 = np.array([
    [0.2985, -0.5792], 
    [0.0913, 0.4234]
])

# weight layer 2
W2 = np.array([0.5266, 0.2958])

# bias 1
B1 = [-0.4939, 0.189]


B2 = np.array([0.6358])

# learning rate 
learning_rate = 0.75
leak_factor = 0.5

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

# H2:
# [[0.7183]
#  [0.5344]
#  [0.6673]
#  [0.64  ]]

# dL/dZ1:
# [[ 0.0946  0.1062]
#  [-0.0613 -0.0689]
#  [-0.0438 -0.0492]
#  [ 0.0843  0.0947]]

@cocotb.test()
async def test_tpu(dut): 
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.ub_wr_host_data_in[0].value = 0
    dut.ub_wr_host_data_in[1].value = 0
    dut.ub_wr_host_valid_in[0].value = 0
    dut.ub_wr_host_valid_in[1].value = 0
    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.learning_rate_in.value = 0
    dut.vpu_data_pathway.value = 0
    dut.sys_switch_in.value = 0
    dut.vpu_leak_factor_in.value = 0
    dut.inv_batch_size_times_two_in.value = 0
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    dut.learning_rate_in.value = to_fixed(learning_rate)
    dut.vpu_leak_factor_in.value = to_fixed(leak_factor)
    dut.inv_batch_size_times_two_in.value = to_fixed(2/len(X))
    await RisingEdge(dut.clk)

    # Load X, Y, W1, B1, W2, B2 (in that order)
    dut.ub_wr_host_data_in[0].value = to_fixed(X[0][0])
    dut.ub_wr_host_valid_in[0].value = 1
    await RisingEdge(dut.clk)

    for i in range(len(X) - 1):
        dut.ub_wr_host_data_in[0].value = to_fixed(X[i + 1][0])
        dut.ub_wr_host_valid_in[0].value = 1
        dut.ub_wr_host_data_in[1].value = to_fixed(X[i][1])
        dut.ub_wr_host_valid_in[1].value = 1
        await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(Y[0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(X[3][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    for i in range(len(Y) - 1):
        dut.ub_wr_host_data_in[0].value = to_fixed(Y[i + 1])
        dut.ub_wr_host_valid_in[0].value = 1
        dut.ub_wr_host_data_in[1].value = 0
        dut.ub_wr_host_valid_in[1].value = 0
        await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(W1[0][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = 0
    dut.ub_wr_host_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(W1[1][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(W1[0][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(B1[0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(W1[1][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(W2[0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(B1[1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(B2[0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(W2[1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = 0
    dut.ub_wr_host_valid_in[0].value = 0
    dut.ub_wr_host_data_in[1].value = 0
    dut.ub_wr_host_valid_in[1].value = 0
    await RisingEdge(dut.clk)


    # Load W1^T into systolic array (reading W1 from UB to top of systolic array)
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 12
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load X into systolic array (reading X from UB to left side of systolic array)
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 2
    dut.vpu_data_pathway.value = 0b1100     # Set VPU datapathway to do forward pass
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)
    
    # Read B1 from UB for 4 clock cycles
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 2
    dut.ub_rd_addr_in.value = 16
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)  # wait until last value of vpu is done

    # Load in W2^T
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 18
    dut.ub_rd_row_size.value = 1
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load in H1
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 21
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 2
    dut.vpu_data_pathway.value = 0b1111     # Set VPU datapathway to the transition pathway from forward pass to backward pass
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read B2 from UB for 4 clock cycles because we have a batch size of 4
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 2
    dut.ub_rd_addr_in.value = 20
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 1
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Reading Y values for the loss modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 3
    dut.ub_rd_addr_in.value = 8
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 1
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Read biases (B2) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 5
    dut.ub_rd_addr_in.value = 20
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 1
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    await FallingEdge(dut.vpu_valid_out_1)

    # Load in W2 from UB to top of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 18
    dut.ub_rd_row_size.value = 1
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load in dL/dZ from UB to left side of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 29
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 1
    dut.vpu_data_pathway.value = 0b0001
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read H1 from UB to VPU (activation derivative modules) for 4 clock cycles
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 4
    dut.ub_rd_addr_in.value = 21
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    # Read biases (B1) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 5
    dut.ub_rd_addr_in.value = 16
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)

    # NOW CALCULATING LEAF NODES (Weight gradients, requires tiling)
    
    # Calculating W1 gradients (W1 before W2)
    # Load first X inputs tile into top of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load first (dL/dZ1)^T tile into left side of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 33
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    dut.vpu_data_pathway.value = 0b0000
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read weights (W1) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 6
    dut.ub_rd_addr_in.value = 12
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)

    # Load second H1 tile into top of systolic array (we are calculating dL/dW2 first)
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 4
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load second (dL/dZ1)^T tile into left side of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 37
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    dut.vpu_data_pathway.value = 0b0000
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read weights (W1) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 6
    dut.ub_rd_addr_in.value = 12
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)

    # Now calculating W2 gradients
    # Load first H1 tile into top of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 21
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load first (dL/dZ2)^T tile into left side of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 29
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 1
    dut.vpu_data_pathway.value = 0b0000
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read weights (W2) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 6
    dut.ub_rd_addr_in.value = 18
    dut.ub_rd_row_size.value = 1
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)

    # Load second H1 tile into top of systolic array (we are calculating dL/dW2 first)
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 25
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    # Load second (dL/dZ2)^T tile into left side of systolic array
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 1
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 31
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 1
    dut.vpu_data_pathway.value = 0b0000
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.sys_switch_in.value = 1
    await RisingEdge(dut.clk)

    # Read weights (W2) from UB to gradient descent modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 6
    dut.ub_rd_addr_in.value = 18
    dut.ub_rd_row_size.value = 1
    dut.ub_rd_col_size.value = 2
    dut.sys_switch_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_rd_transpose.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await FallingEdge(dut.vpu_valid_out_1)



    await ClockCycles(dut.clk, 10)

    
    
    
