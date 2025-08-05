# Test these three pathways:
# (forward pass: hidden layer computations) input from sys --> bias --> leaky relu --> output
# (transition) input from sys --> bias --> leaky relu --> loss --> leaky relu derivative (handles a staggered hadamard product)--> output
# (backward pass) input from sys --> leaky relu derivative --> output

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_vector_unit(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test forward pass pathway


    # Test transition pathway


    # Test 
