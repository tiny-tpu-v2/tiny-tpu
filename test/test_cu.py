import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer

@cocotb.test()
async def test_cu(dut):
    dut._log.info("Starting test")

    await Timer(10, units="ns")

    dut.instruction.value = 0b00000

    await Timer(10, units="ns")

    dut.instruction.value = 0b00001

    await Timer(10, units="ns")

    dut.instruction.value = 0b00010

    await Timer(10, units="ns")

    dut.instruction.value = 0b00011

    await Timer(10, units="ns")

    dut.instruction.value = 0b00100

    await Timer(10, units="ns")

    dut.instruction.value = 0b00101

    await Timer(10, units="ns")

    dut.instruction.value = 0b00110

    await Timer(10, units="ns")

    dut.instruction.value = 0b00111

    await Timer(10, units="ns")

    dut.instruction.value = 0b01000

    await Timer(10, units="ns")

    dut.instruction.value = 0b01001

    await Timer(10, units="ns")

    dut.instruction.value = 0b01010

    await Timer(10, units="ns")

    dut.instruction.value = 0b01011

    await Timer(10, units="ns")

    dut.instruction.value = 0b01100

    await Timer(10, units="ns")

    dut.instruction.value = 0b01101

    await Timer(10, units="ns")

    dut.instruction.value = 0b01110

    await Timer(10, units="ns")

    dut.instruction.value = 0b01111

    await Timer(10, units="ns")

    dut.instruction.value = 0b10000

    await Timer(10, units="ns")

    dut.instruction.value = 0b10001

    await Timer(10, units="ns")
    

    