# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


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

    await ClockCycles(dut.clk, 1)
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.nn_valid_load_weights.value = 0
    dut.nn_valid_in_1.value = 0 # TODO: rename
    dut.nn_data_in_1.value = to_fixed(0.0)
    dut.nn_valid_in_2.value = 0 # TODO: rename
    dut.nn_data_in_2.value = to_fixed(0.0)
    ## Initialize weights to zero
    dut.nn_temp_weight_11.value = to_fixed(0.0)
    dut.nn_temp_weight_12.value = to_fixed(0.0)
    dut.nn_temp_weight_21.value = to_fixed(0.0)
    dut.nn_temp_weight_22.value = to_fixed(0.0)
    # Initialize start signal to 0
    dut.nn_start.value = 0
    await RisingEdge(dut.clk)

    # rst is off now
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    dut.nn_valid_in_1.value = 1
    dut.nn_data_in_1.value = to_fixed(1.0)       # INPUT TO NN (X1)
    dut.nn_valid_in_2.value = 1
    dut.nn_data_in_2.value = to_fixed(0.0)       # INPUT TO NN (X2)
    await RisingEdge(dut.clk)


    # Input valid flags switch off
    dut.nn_valid_in_1.value = 0
    dut.nn_valid_in_2.value = 0
    # Load weights flag is on
    dut.nn_valid_load_weights.value = 1
    # Initialize leak factor
    dut.nn_temp_leak_factor.value = to_fixed(0.01)
    # Initializing bias values
    dut.nn_temp_bias_1.value = to_fixed(0.25080394744873047)
    dut.nn_temp_bias_2.value = to_fixed(-0.00012433409574441612)
    # Initializing weight values
    dut.nn_temp_weight_11.value = to_fixed(0.8821601271629333)
    dut.nn_temp_weight_12.value = to_fixed(-1.0646932125091553)
    dut.nn_temp_weight_21.value = to_fixed(-0.8821614980697632)
    dut.nn_temp_weight_22.value = to_fixed(1.0648175477981567)
    await RisingEdge(dut.clk)
    
    # weights from prev clock cycle are latched due to load_weights flag being on. 
    # now we dont have any more weight inputs, and we turn it off. 
    dut.nn_temp_weight_11.value = to_fixed(0.0)
    dut.nn_temp_weight_12.value = to_fixed(0.0)
    dut.nn_temp_weight_21.value = to_fixed(0.0)
    dut.nn_temp_weight_22.value = to_fixed(0.0)
    dut.nn_valid_load_weights.value = 0                  # load weight flag is off now
    await RisingEdge(dut.clk) 

    # Inputs are ALREADY staged to systolic array (dut.input_xx.value directly connects to systolic array)
    dut.nn_start.value = 1 # Now systolic array will start processing
    await ClockCycles(dut.clk, 1)

    # Now, we turn off the start signal and "already" staged inputs will propagate through the systolic array.
    # In this testbench, it looks like we input dut.input_11.value and dut.input_21.value ...
    # but in reality, the inputs are already staged to the systolic array....
    # These values below (0.0, 6.0) would have to be inputted in the PREVIOUS clock cycle.
    dut.nn_start.value = 0
    await ClockCycles(dut.clk, 20)

    dut.nn_valid_load_weights.value = 1
    dut.nn_temp_weight_11.value = to_fixed(1.1482632160186768)
    dut.nn_temp_weight_12.value = to_fixed(0)
    dut.nn_temp_weight_21.value = to_fixed(1.216535210609436)
    dut.nn_temp_weight_22.value = to_fixed(0)
    dut.nn_temp_bias_1.value = to_fixed(-0.28798729181289673)
    dut.nn_temp_bias_2.value = to_fixed(0)

    await ClockCycles(dut.clk, 1)
    dut.nn_valid_load_weights.value = 0
    dut.nn_start.value = 1
    await ClockCycles(dut.clk, 1)
    dut.nn_start.value = 0

    await ClockCycles(dut.clk, 30)

    # Start flag will now STAY off for the rest of the testbench. We will not change this value anymore. 
