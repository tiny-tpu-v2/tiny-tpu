import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

@cocotb.test()
async def systolic_array_tb(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    matrix_a = [
        [5, 6],
        [7, 8]
    ]
    weight_matrix = [
        [1, 2],
        [3, 4]
    ]
    
    # Initialize all inputs
    dut.reset.value = 1
    dut.start.value = 0
    dut.load_weight.value = 0
    dut.load_input.value = 0

    dut.w00.value = 0
    dut.w01.value = 0
    dut.w10.value = 0
    dut.w11.value = 0

    dut.a00.value = 0
    dut.a01.value = 0
    dut.a10.value = 0
    dut.a11.value = 0

    await ClockCycles(dut.clk, 5)

    # Load weights and inputs
    dut.reset.value = 0
    dut.load_weight.value = 1
    dut.load_input.value = 1
    dut.w00.value = weight_matrix[0][0]
    dut.w01.value = weight_matrix[0][1]
    dut.w10.value = weight_matrix[1][0]
    dut.w11.value = weight_matrix[1][1]
    dut.a00.value = matrix_a[0][0]
    dut.a01.value = matrix_a[0][1]
    dut.a10.value = matrix_a[1][0]
    dut.a11.value = matrix_a[1][1]

    await ClockCycles(dut.clk, 1)
    dut.load_weight.value = 0
    dut.load_input.value = 0
    dut.w00.value = 0
    dut.w01.value = 0
    dut.w10.value = 0
    dut.w11.value = 0
    dut.a00.value = 0
    dut.a01.value = 0
    dut.a10.value = 0
    dut.a11.value = 0

    # Start the systolic array
    dut.start.value = 1
   

    if(dut.done.value == 0):
        await RisingEdge(dut.done)
    
    dut.start.value = 0
    await ClockCycles(dut.clk, 30)

