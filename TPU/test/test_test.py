import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.binary import BinaryValue


@cocotb.test()
async def test_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="us").start())

    dut.reset.value = 1
    await ClockCycles(dut.clk, 1)

    dut.reset.value = 0
    dut.in_test.value = 32
    await ClockCycles(dut.clk, 1)


    await ClockCycles(dut.clk, 1)

