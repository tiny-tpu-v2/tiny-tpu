import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

@cocotb.test()
async def float32_adder_tb(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    # Initialize all inputs
    dut.rst.value = 1
    dut.input_a.value = 0
    dut.input_b.value = 0
    dut.input_a_stb.value = 0
    dut.input_b_stb.value = 0
    dut.output_z_ack.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst.value = 0

    # ----- First Addition -----

    # Set inputs and assert strobes
    dut.input_a.value = 0x40e9999a      # 7.3
    dut.input_b.value = 0x40000000      # 2.0
    dut.input_a_stb.value = 1
    dut.input_b_stb.value = 1
    
    # Wait for DUT to acknowledge accept, then can set strobes to 0
    # await ReadOnly()
    # if int(dut.input_a_ack.value) == 0:
    #     await RisingEdge(dut.input_a_ack.value)
    # if int(dut.input_a_ack.value) == 1:
    #     await FallingEdge(dut.input_a_ack.value)
    # dut.input_a_stb.value <= 0

    # if int(dut.input_b_ack.value) == 0:
    #     await RisingEdge(dut.input_b_ack.value)
    # if int(dut.input_b_ack.value) == 1:
    #     await FallingEdge(dut.input_b_ack.value)
    # dut.input_b_stb.value <= 0
    
    # Wait for output to be ready
    if int(dut.output_z_stb.value) == 0:
        await RisingEdge(dut.output_z_stb)

    # Check output
    # assert dut.output_z.value == 0x40e9999a
    cocotb.log.info("RESULT: %d",  float(dut.output_z.value))

    # Second Addition
    # dut.input_a.value = 0x40e9999a
    # dut.input_b.value = 0x40000000
    
    