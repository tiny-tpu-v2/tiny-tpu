import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

def to_fixed(val, frac_bits=8):
    """Convert a float to fixed-point representation (Q8.8 by default)."""
    return int(round(val * (1 << frac_bits)))

def from_fixed(val, frac_bits=8):
    """Convert a fixed-point value back to float."""
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_pe_fixed_point(dut):
    """Test the PE module with fixed-point numbers."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    dut.load_weight.value = 0
    dut.start.value = 0
    dut.input_in.value = 0
    dut.weight.value = 0
    dut.psum_in.value = 0
    await Timer(10, units="ns")
    dut.rst.value = 0

    # Load weight (e.g., 2.5 in Q8.8)
    weight_val = 2.5
    dut.weight.value = to_fixed(weight_val)
    dut.load_weight.value = 1
    await Timer(10, units="ns")
    dut.load_weight.value = 0

    # Provide input and psum, then start (e.g., input=3.0, psum=1.0)
    input_val = 3.0
    psum_val = 1.0
    dut.input_in.value = to_fixed(input_val)
    dut.psum_in.value = to_fixed(psum_val)
    dut.start.value = 1
    await Timer(10, units="ns")
    dut.start.value = 0

    # Wait for output to settle
    await Timer(10, units="ns")

    # Read and convert output
    result_fixed = dut.psum_out.value.signed_integer
    result_float = from_fixed(result_fixed)

    # Calculate expected result: (input * weight) + psum
    expected = (input_val * weight_val) + psum_val

    print(f"Result (fixed): {result_fixed}")
    print(f"Result (float): {result_float}")
    print(f"Expected (float): {expected}")

    # Allow a small tolerance for rounding
    assert abs(result_float - expected) < 0.01, f"Mismatch: got {result_float}, expected {expected}"

    # Try another set of values if desired...