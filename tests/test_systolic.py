# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

#VERIFIED FUNCIONALITY ✅

@cocotb.test()
async def test_systolic_array(dut): 

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.load_weights.value = 0
    dut.weight_11.value = 0
    dut.weight_12.value = 0
    dut.weight_13.value = 0
    dut.weight_21.value = 0
    dut.weight_22.value = 0
    dut.weight_23.value = 0
    dut.weight_31.value = 0
    dut.weight_32.value = 0
    dut.weight_33.value = 0
    dut.input_11.value = 0
    dut.input_21.value = 0
    dut.input_31.value = 0
    dut.start.value = 0

    await Timer(10, units="ns")

    dut.rst.value = 0

    await Timer(10, units="ns")

    dut.load_weights.value = 1
    dut.weight_11.value = 1
    dut.weight_12.value = 2
    dut.weight_13.value = 3
    dut.weight_21.value = 4
    dut.weight_22.value = 5
    dut.weight_23.value = 6
    dut.weight_31.value = 7
    dut.weight_32.value = 8
    dut.weight_33.value = 9
    
    await Timer(10, units="ns")

    dut.start.value = 1
    dut.load_weights.value = 0

    await Timer(10, units="ns")
    dut.input_11.value = 5
    dut.input_21.value = 0
    dut.input_31.value = 0

    await Timer(10, units="ns")
    dut.input_11.value = 0
    dut.input_21.value = 6
    dut.input_31.value = 0

    await Timer(10, units="ns")
    dut.input_11.value = 0
    dut.input_21.value = 0
    dut.input_31.value = 7

    await Timer(10, units="ns")
    dut.input_11.value = 0
    dut.input_21.value = 0
    dut.input_31.value = 0

    await Timer(10, units="ns")
    dut.input_11.value = 0
    dut.input_21.value = 0
    dut.input_31.value = 0

    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")

    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
