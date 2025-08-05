# Test these three pathways:
# (forward pass: hidden layer computations) input from sys --> bias --> leaky relu --> output
# (transition) input from sys --> bias --> leaky relu --> loss --> leaky relu derivative (handles a staggered hadamard product)--> output
# (backward pass) input from sys --> leaky relu derivative --> output

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

FRAC_BITS = 8

def to_fixed(val, frac_bits=FRAC_BITS):
    """convert python float to signed 16-bit fixed-point (Q8.8)."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

def from_fixed(val, frac_bits=FRAC_BITS):
    """convert signed 16-bit fixed-point to python float."""
    if val >= 1 << 15:
        val -= 1 << 16
    return float(val) / (1 << frac_bits)

Z1_pre = [
    [ 0, 0,],
    [-0.5792, 0.4234],
    [ 0.2985, 0.0913],
    [-0.2807, 0.5147],
]

B1 = [-0.4939,  0.189 ]

# H1:
# [[-0.247   0.189 ]
#  [-0.5366  0.6124]
#  [-0.0977  0.2803]
#  [-0.3873  0.7037]]

Z2_pre = [
    [-0.0741],
    [-0.1014],
    [ 0.0315],
    [ 0.0042],
]

B2 = [0.6358]

Y = [
    [0.],
    [1.],
    [1.],
    [0.],
]


# H2:
# [[0.5617]
#  [0.5344]
#  [0.6673]
#  [0.64  ]]

# dL/dH2:
# [[ 0.2808]
#  [-0.2328]
#  [-0.1664]
#  [ 0.32  ]]


@cocotb.test()
async def test_vector_unit(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)

    # Test forward pass pathway
    dut.rst.value = 0
    dut.data_pathway.value = 0b0001 
    
    dut.vpu_valid_in_1.value = 1
    dut.vpu_valid_in_2.value = 1

    # Comes from UB
    dut.bias_scalar_in_1.value = to_fixed(B1[0])
    dut.bias_scalar_in_2.value = to_fixed(B1[1])       
    dut.lr_leak_factor_in.value = to_fixed(0.5)

    for z in Z1_pre:
        dut.vpu_data_in_1.value = to_fixed(z[0])
        dut.vpu_data_in_2.value = to_fixed(z[1])
        await RisingEdge(dut.clk)

    dut.vpu_data_in_1.value = to_fixed(0)
    dut.vpu_data_in_2.value = to_fixed(0)

    dut.vpu_valid_in_1.value = 0
    dut.vpu_valid_in_2.value = 0
    await ClockCycles(dut.clk, 10)


    # Test transition pathway
    dut.rst.value = 1
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    dut.data_pathway.value = 0b0010 
    dut.vpu_valid_in_1.value = 1
    # dut.vpu_valid_in_2.value = 1

    dut.bias_scalar_in_1.value = to_fixed(B2[0])
    # dut.bias_scalar_in_1.value = to_fixed(B2[1])
    
    dut.lr_leak_factor_in.value = to_fixed(0.5)

    dut.inv_batch_size_times_two_in = to_fixed(2/4)     # 2/N where N is our batch size which is 4

    dut.vpu_data_in_1.value = to_fixed(Z2_pre[0][0])
    # dut.vpu_data_in_2.value = to_fixed(z[1])
    await RisingEdge(dut.clk)

    dut.vpu_data_in_1.value = to_fixed(Z2_pre[1][0])
    # dut.vpu_data_in_2.value = to_fixed(z[1])
    await RisingEdge(dut.clk)
    
    ## START PUTTING TARGET VALUES HERE??? IDK? if not, then shift it down by 1 clk cycle

    dut.vpu_data_in_1.value = to_fixed(Z2_pre[2][0])
    # dut.vpu_data_in_2.value = to_fixed(z[1])
    dut.Y_in_1.value = to_fixed(Y[0][0])
    # dut.Y_in_2.value = to_fixed(Y[0][0])
    await RisingEdge(dut.clk)


    dut.vpu_data_in_1.value = to_fixed(Z2_pre[3][0])
    # dut.vpu_data_in_2.value = to_fixed(z[1])
    dut.Y_in_1.value = to_fixed(Y[1][0])
    # dut.Y_in_2.value = to_fixed(Y[0][0])
    await RisingEdge(dut.clk)

    dut.Y_in_1.value = to_fixed(Y[2][0])
    # dut.Y_in_2.value = to_fixed(Y[0][0])
    dut.vpu_valid_in_1 = 0
    await RisingEdge(dut.clk)

    dut.Y_in_1.value = to_fixed(Y[3][0])
    # dut.Y_in_2.value = to_fixed(Y[0][0])
    await RisingEdge(dut.clk)
    
    dut.vpu_valid_in_1.value = 0
    # dut.vpu_valid_in_2.value = 0
    await ClockCycles(dut.clk, 10)



    # dut.Y_in_1.value = 
    # dut.Y_in_2.value = 


    # Test backward pass pathway
    # dut.H_in_1.value = 
    # dut.H_in_2.value = 