import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_acc_input(dut):
    """Test the PE module with a variety of fixed-point inputs."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_load_in = [12, 4, 5, 8]

    # Reset
    dut.rst.value = 1
    dut.acc_load_i.value = 0
    dut.acc_valid_i.value = 0
    for i in range(len(test_load_in)):
        dut.acc_data_in[i].value = 0

    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)




    # Load inputs
    dut.acc_load_i.value = 1
    for i in range(len(test_load_in)):
        dut.acc_data_in[i].value = test_load_in[i]
    await RisingEdge(dut.clk)

    # Set inputs back to 0 and load flag to 0
    dut.acc_load_i.value = 0
    for i in range(len(test_load_in)):
        dut.acc_data_in[i].value = 0
    await RisingEdge(dut.clk)

    # Set valid flag to 1
    dut.acc_valid_i.value = 1
    await ClockCycles(dut.clk, 4)
    dut.acc_valid_i.value = 0


    await ClockCycles(dut.clk, 10)
    test_load_in = [3, 9, 8, 0]

    # Load inputs
    dut.acc_load_i.value = 1
    for i in range(len(test_load_in)):
        dut.acc_data_in[i].value = test_load_in[i]
    await RisingEdge(dut.clk)

    # Set inputs back to 0 and load flag to 0
    dut.acc_load_i.value = 0
    for i in range(len(test_load_in)):
        dut.acc_data_in[i].value = 0
    await RisingEdge(dut.clk)

    # Set valid flag to 1
    dut.acc_valid_i.value = 1
    await ClockCycles(dut.clk, 4)
    dut.acc_valid_i.value = 0


    await ClockCycles(dut.clk, 20)
    



