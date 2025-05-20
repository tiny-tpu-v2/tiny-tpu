# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_systolic_array(dut): 

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.load_weights.value = 0
    dut.weight_11.value = to_fixed(0.0)
    dut.weight_12.value = to_fixed(0.0)

    dut.weight_21.value = to_fixed(0.0)
    dut.weight_22.value = to_fixed(0.0)

    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)
    dut.start.value = 0
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)

    dut.load_weights.value = 1
    dut.weight_11.value = to_fixed(1.0)
    dut.weight_12.value = to_fixed(3.0)
    dut.weight_21.value = to_fixed(2.0)
    dut.weight_22.value = to_fixed(4.0)
    await RisingEdge(dut.clk)

    dut.load_weights.value = 0
    await RisingEdge(dut.clk) 

    # dut.start.value = 0 
    dut.input_11.value = to_fixed(5.0)
    dut.input_21.value = to_fixed(0.0)
    await RisingEdge(dut.clk)


    dut.start.value = 1 
    await RisingEdge(dut.clk)

    dut.start.value = 1 # i think this should be off now ?? keep it on for now
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(6.0)

    await RisingEdge(dut.clk)

    dut.start.value = 0 
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await RisingEdge(dut.clk)
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await RisingEdge(dut.clk)
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Optionally, you can add from_fixed and print outputs here if desired
    # Example:
    # def from_fixed(val, frac_bits=8):
    #     if val >= (1 << 15):
    #         val -= (1 << 16)
    #     return float(val) / (1 << frac_bits)
    # print("Output:", from_fixed(int(dut.out_21.value)))