import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge,  ClockCycles
import numpy as np

# X -> Z1_prebias

# input:
X = np.array([[0., 0.],
              [0., 1.],
              [1., 0.],
              [1., 1.]])
# weight 1
W1 = np.array([
    [0.2985, -0.5792], 
    [0.0913, 0.4234]
])

# Z1 pre bias (output):
# [[ 0.      0.    ]
#  [-0.5792  0.4234]
#  [ 0.2985  0.0913]
#  [-0.2807  0.5147]]

@cocotb.test()
async def test_tpu(dut): 
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # rst the DUT (device under test)
    dut.rst.value = 1

    # Store X and W1 in UB

    # Read X and W1 from UB to systolic array

    