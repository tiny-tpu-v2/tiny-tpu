import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_pe(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ps").start())
    
    # Initialize all inputs
    dut.reset.value = 1
    dut.start.value = 0
    dut.load_weight.value = 0
    dut.weight_in.value = 0
    dut.input_in.value = 0
    dut.sum_in.value = 0
    
    await ClockCycles(dut.clk, 5)


    dut.reset.value = 0
    dut.load_weight.value = 1
    dut.weight_in.value = 3
    await ClockCycles(dut.clk, 1)


    dut.weight_in.value = 0
    dut.load_weight.value = 0
    dut.reset.value = 0
    dut.start.value = 1
    dut.input_in.value = 0b00111111111000000000000000000000
    dut.sum_in.value = 0b01000001010110100000000000000000
    await ClockCycles(dut.clk, 40)