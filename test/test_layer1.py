# import cocotb
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
async def test_layer1(dut): 

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
    await Timer(10, units="ns")

    dut.rst.value = 0
    await Timer(10, units="ns")

    dut.load_weights.value = 1
    dut.leak_factor.value = to_fixed(2.0)

    dut.in_bias_21.value = to_fixed(1.0)
    dut.in_bias_22.value = to_fixed(1.0)

    dut.weight_11.value = to_fixed(1.0)
    dut.weight_12.value = to_fixed(3.0)
    dut.weight_21.value = to_fixed(-2.0)
    dut.weight_22.value = to_fixed(4.0)
    await Timer(10, units="ns")

    dut.start.value = 1 
    dut.load_weights.value = 0

    await Timer(10, units="ns") 
    dut.input_11.value = to_fixed(5.0)
    dut.input_21.value = to_fixed(0.0)

    await Timer(10, units="ns")
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(6.0)

    await Timer(10, units="ns")
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await Timer(10, units="ns")
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await Timer(10, units="ns")
    dut.input_11.value = to_fixed(0.0)
    dut.input_21.value = to_fixed(0.0)

    await Timer(10, units="ns")
    await Timer(10, units="ns")

    await Timer(10, units="ns")
    await Timer(10, units="ns")

    result = dut.out1.value
    # result_float = from_fixed(result)
    

    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")

    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
    await Timer(10, units="ns")
