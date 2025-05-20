import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

def to_fixed(val, frac_bits=8):
    return int(round(val * (1 << frac_bits))) & 0xFFFF

def from_fixed(val, frac_bits=8):
    if val >= (1 << 15):
        val -= (1 << 16)
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_leaky_relu_fixed_point(dut):
    """Test the leaky_relu module with fixed-point numbers."""

    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Test positive input
    input_val = 2.5
    leak_factor = 0.1
    dut.input_in.value = to_fixed(input_val)
    dut.leak_factor.value = to_fixed(leak_factor)
    await RisingEdge(dut.clk)  # First clock: registers input
    await RisingEdge(dut.clk)  # Second clock: output is valid

    result_fixed = dut.out.value.signed_integer
    result_float = from_fixed(result_fixed)
    assert abs(result_float - input_val) < 0.01, f"Expected {input_val}, got {result_float}"

    # Test negative input
    input_val = -4.0
    leak_factor = 0.2
    dut.input_in.value = to_fixed(input_val)
    dut.leak_factor.value = to_fixed(leak_factor)
    await RisingEdge(dut.clk)  # First clock: registers input
    await RisingEdge(dut.clk)  # Second clock: output is valid

    result_fixed = dut.out.value.signed_integer
    result_float = from_fixed(result_fixed)
    expected = input_val * leak_factor
    assert abs(result_float - expected) < 0.01, f"Expected {expected}, got {result_float}"

    # Test zero input
    input_val = 0.0
    leak_factor = 0.5
    dut.input_in.value = to_fixed(input_val)
    dut.leak_factor.value = to_fixed(leak_factor)
    await RisingEdge(dut.clk)  # First clock: registers input
    await RisingEdge(dut.clk)  # Second clock: output is valid

    result_fixed = dut.out.value.signed_integer
    result_float = from_fixed(result_fixed)
    assert abs(result_float - 0.0) < 0.01, f"Expected 0.0, got {result_float}"