import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_weight_acc(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_weight = [2, 4, 6, 8]

    # Reset
    dut.rst.value = 1
    dut.weight_acc_valid_in.value = 0
    dut.weight_acc_valid_data_in.value = 0
    dut.weight_acc_data_in.value = 0

    await RisingEdge(dut.clk)
    dut.rst.value = 0

    await RisingEdge(dut.clk)

    dut.weight_acc_valid_data_in.value = 1
    for i in range(len(test_weight)):
        dut.weight_acc_data_in.value = test_weight[i]
        await RisingEdge(dut.clk)

    dut.weight_acc_valid_data_in.value = 0

    await RisingEdge(dut.clk)


    dut.weight_acc_valid_in.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.weight_acc_valid_in.value = 0
    await ClockCycles(dut.clk, 20)
