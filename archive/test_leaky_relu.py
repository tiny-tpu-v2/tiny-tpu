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
    dut.lr_valid_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    dut.input_in.value = to_fixed(10.0)
    dut.leak_factor.value = to_fixed(0.2)
    dut.lr_valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.input_in.value = to_fixed(8.0)
    dut.lr_valid_in.value = 0
    await RisingEdge(dut.clk)

    dut.input_in.value = to_fixed(-10.0)
    dut.leak_factor.value = to_fixed(0.1)
    dut.lr_valid_in.value = 1
    await RisingEdge(dut.clk)
    dut.lr_valid_in.value = 0
    await RisingEdge(dut.clk)