import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def to_fixed(val, frac_bits=8):
    return int(round(val * (1 << frac_bits))) & 0xFFFF

def from_fixed(val, frac_bits=8):
    if val >= (1 << 15):
        val -= (1 << 16)
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_pe_various_inputs(dut):
    """Test the PE module with a variety of fixed-point inputs."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    dut.load_weight.value = 0
    dut.start.value = 0
    dut.input_in.value = 0
    dut.weight.value = 0
    dut.psum_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # List of test cases: (input_val, weight_val, psum_val)
    test_cases = [
        (2.5, 1.0, 0.0),
        (-3.0, 2.0, 1.0),
        (0.0, 1.5, 2.0),
        (1.25, -2.0, -1.0),
        (-1.5, -1.5, 0.5),
        (4.0, 0.0, 3.0),
        (0.0, 0.0, 0.0),
        (127.0, 1.0, 0.0),      # Large positive
        (-128.0, 1.0, 0.0),     # Large negative
        (0.5, 0.5, 0.5),        # Small values
        (-0.5, -0.5, -0.5),     # Small negative values
    ]

    for idx, (input_val, weight_val, psum_val) in enumerate(test_cases):
        # Load weight
        dut.weight.value = to_fixed(weight_val)
        dut.load_weight.value = 1
        await RisingEdge(dut.clk)
        dut.load_weight.value = 0
        await RisingEdge(dut.clk)

        # Provide input and psum, then start
        dut.input_in.value = to_fixed(input_val)
        dut.psum_in.value = to_fixed(psum_val)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Read and convert output
        result_fixed = dut.psum_out.value.signed_integer
        result_float = from_fixed(result_fixed)

        # Calculate expected result: (input * weight) + psum
        expected = (input_val * weight_val) + psum_val

        print(f"Test {idx}: input={input_val}, weight={weight_val}, psum={psum_val} => out={result_float} (expected {expected})")
        assert abs(result_float - expected) < 0.01, f"Test {idx} failed: got {result_float}, expected {expected}"

        await RisingEdge(dut.clk)