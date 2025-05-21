import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_accumulator(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_input = [2]

    # Reset
    dut.rst.value = 1
    dut.acc_valid_in.value = 0
    dut.acc_valid_data_in.value = 0
    dut.acc_data_in.value = 0

    await RisingEdge(dut.clk)
    dut.rst.value = 0

    await RisingEdge(dut.clk)
    dut.acc_valid_data_in.value = 1
    for i in range(len(test_input)):
        dut.acc_data_in.value = test_input[i]
        await RisingEdge(dut.clk)
    
    dut.acc_valid_data_in.value = 0

    await RisingEdge(dut.clk)


    dut.acc_valid_in.value = 1
    await ClockCycles(dut.clk, 20)


