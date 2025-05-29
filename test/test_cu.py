import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

@cocotb.test()
async def test_cu(dut):
    dut._log.info("Starting test")

    await Timer(10, units="ns")

    dut.instruction.value = 0b0000000000000000000000000

    await Timer(10, units="ns")

    dut.instruction.value = 0b0000000000000000000000001

    await Timer(10, units="ns")

    dut.instruction.value = 0b00000000000000000000110

    await Timer(10, units="ns")

    dut.instruction.value = 0b00000000011000000001010

    await Timer(10, units="ns")

    dut.instruction.value = 0b00000000001000000001110

    await Timer(10, units="ns")

    dut.instruction.value = 0b10000000001000000001110

    await Timer(10, units="ns")

    dut.instruction.value = 0b00000000001000000001111

    await Timer(10, units="ns")

    

    