import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_leaky_relu(dut):
    """Test the processing_element module."""

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    await Timer(10, units="ns")

    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.input_in.value = 0
    dut.leak_factor.value = 0

    # deactivate rst to allow other functionality
    await Timer(10, units="ns")
    dut.rst.value = 0

    # load weight on to the PE
    dut.input_in.value = 10
    dut.leak_factor.value = 2
    await Timer(10, units="ns")

    # set input_in and psum_in to arbitrary values  
    dut.input_in.value = 5

    await Timer(10, units="ns")

    # set input_in and psum_in to different values 
    dut.input_in.value = -20
    await Timer(10, units="ns")
    # Deactivate the start signal
    dut.input_in.value = 0


    await Timer(10, units="ns")