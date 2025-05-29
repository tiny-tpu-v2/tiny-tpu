import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_input_acc(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_input = [2, 4]

    # Reset
    dut.rst.value = 1
    dut.input_acc_valid_in.value = 0
    dut.input_acc_valid_data_in.value = 0
    dut.input_acc_data_in.value = 0

    await RisingEdge(dut.clk)
    dut.rst.value = 0

    await RisingEdge(dut.clk)

    dut.input_acc_valid_data_nn_in.value = 1
    dut.input_acc_data_nn_in.value = 1
    await RisingEdge(dut.clk)
    dut.input_acc_valid_data_nn_in.value = 0
    dut.input_acc_data_nn_in.value = 2
    await RisingEdge(dut.clk)

    dut.input_acc_valid_data_in.value = 1
    
    dut.input_acc_data_in.value = 2
    await RisingEdge(dut.clk)

    dut.input_acc_data_in.value = 4
    await RisingEdge(dut.clk)

    dut.input_acc_data_in.value = 6
    await RisingEdge(dut.clk)

    dut.input_acc_valid_data_in.value = 0

    await RisingEdge(dut.clk)


    dut.input_acc_valid_in.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.input_acc_valid_in.value = 0
    await ClockCycles(dut.clk, 20)
