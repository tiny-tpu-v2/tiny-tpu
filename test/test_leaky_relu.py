import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits.
    Args:
        val: Float value to convert
        frac_bits: Number of fractional bits (default 8)
    Returns:
        16-bit fixed point number
    """
    # Scale by 2^8 and convert to integer
    scaled = int(round(val * (1 << frac_bits)))
    # Mask to 16 bits and handle overflow
    return scaled & 0xFFFF

def from_fixed(val, frac_bits=8):
    """Convert a 16-bit fixed point number to float.
    Args:
        val: 16-bit fixed point number
        frac_bits: Number of fractional bits (default 8)
    Returns:
        Float value
    """
    # Handle negative numbers (two's complement)
    if val >= (1 << 15):
        val -= (1 << 16)
    # Convert back to float
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_leaky_relu_fixed_point(dut):
    """Test the leaky_relu module with 16-bit fixed point numbers (8 integer, 8 fractional bits)."""

    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Test cases: (input, leak_factor, expected_output)
    test_cases = [
        # Positive inputs
        (2.5, 0.1, 2.5),      # Positive input -> output = input
        (127.0, 0.1, 127.0),  # Maximum positive value
        (0.5, 0.1, 0.5),      # Small positive value
        
        # Negative inputs - using values that can be exactly represented
        (-4.0, 0.25, -1.0),   # Negative input -> output = input * leak_factor
        (-64.0, 0.125, -8.0), # Negative input with exact representation
        (-0.5, 0.25, -0.125), # Small negative value with exact representation
        
        # Edge cases
        (0.0, 0.5, 0.0),      # Zero input
        (-0.0, 0.5, 0.0),     # Negative zero
        (0.1, 0.0, 0.1),      # Zero leak factor with positive input
        (-0.1, 0.0, 0.0),     # Zero leak factor with negative input
    ]

    for input_val, leak_factor, expected in test_cases:
        # Set input values
        dut.input_in.value = to_fixed(input_val)
        dut.leak_factor.value = to_fixed(leak_factor)
        
        # Wait for two clock cycles (one for input register, one for output)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Get result and convert back to float
        result_fixed = dut.out.value.signed_integer
        result_float = from_fixed(result_fixed)
        
        # Check result with tolerance for fixed-point arithmetic
        # Using a larger tolerance to account for fixed-point precision
        tolerance = 0.01
        assert abs(result_float - expected) < tolerance, \
            f"Input: {input_val}, Leak: {leak_factor}, Expected: {expected}, Got: {result_float}"