import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_pe(dut):
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 10, units="us").start())
    
    # Initialize all inputs
    dut.reset.value = 1
    dut.valid.value = 0
    dut.load_weight.value = 0
    dut.a_in.value = 0
    dut.weight.value = 0
    dut.acc_in.value = 0
    
    # Reset cycle
    await ClockCycles(dut.clk, 1)

    # Test 1: Load weight
    dut.reset.value = 0
    dut.load_weight.value = 1 #This is a wire so you'll see change on same cycle
    dut.weight.value = 5 # This is a wire so you'll see change on same cycle, register value for this is updated on next cycle
    await ClockCycles(dut.clk, 1) 




    dut.load_weight.value = 0
    # Wait one cycle to ensure weight is loaded
    await ClockCycles(dut.clk, 1)
    



    # Test 2: Basic MAC operation
    dut.valid.value = 1 # This happens on same clock cycle as input because its a wire
    dut.a_in.value = 3 
    dut.acc_in.value = 10
    await ClockCycles(dut.clk, 1)
    



    # Wait one cycle to see the result
    await ClockCycles(dut.clk, 1)
    
    # Verify MAC result: 10 + (3 * 5) = 25
    assert dut.acc_out.value == 25, f"Expected acc_out to be 25, got {dut.acc_out.value}"
    assert dut.a_out.value == 3, f"Expected a_out to be 3, got {dut.a_out.value}"
    