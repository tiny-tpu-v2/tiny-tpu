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


# INSTRUCTION FORMAT (24 bits):
# [23] - nn_start flag
# [22] - accept flag
# [21] - switch flag
# [19:20] - activation_datapath
# [17:18] - load_weights, load_bias, load_inputs
# [16] - address
# [15:0] - weight_data_in

@cocotb.test()
async def test_nn(dut): 

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await ClockCycles(dut.clk, 1)
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.instruction.value = 0b0_0_0_00_00_0_0000000000000000 
    await ClockCycles(dut.clk, 1)

    # rst is off now
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

    #########################################################

    # LOADING INPUTS (passing in the inputs as such: [(0,0), (1,1), (0,1), (1,0)])
    dut.instruction.value = 0b0_0_0_01_01_0_0000000000000000 | to_fixed(0.0) # 0 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_01_1_0000000000000000 | to_fixed(0.0) # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_01_0_0000000000000000 | to_fixed(0.0) # 1 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_01_1_0000000000000000 | to_fixed(1.0) # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_01_0_0000000000000000 | to_fixed(1.0) # 0 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_01_1_0000000000000000 | to_fixed(0.0) # 1 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_01_0_0000000000000000 | to_fixed(1.0) # 1 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_01_1_0000000000000000 | to_fixed(1.0) # 1 to acc 2
    await ClockCycles(dut.clk, 1)

    ##########################################################

    # LOADING WEIGHTS
    dut.instruction.value = 0b0_0_0_01_10_0_0000000000000000 | to_fixed(-0.8821614980697632)    # w12 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_10_1_0000000000000000 | to_fixed(1.0648175477981567)   # w22 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_10_0_0000000000000000 | to_fixed(0.8821601271629333)   # w11 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_10_1_0000000000000000 | to_fixed(-1.0646932125091553)   # w21 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_10_0_0000000000000000 | to_fixed(1.216535210609436) # wB2 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_10_1_0000000000000000 | to_fixed(0.0) # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    dut.instruction.value = 0b0_0_0_01_10_0_0000000000000000 | to_fixed(1.1482632160186768) # wB1 to acc 1
    await ClockCycles(dut.clk, 1)
    dut.instruction.value = 0b0_0_0_01_10_1_0000000000000000 | to_fixed(0.0) # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    ##########################################################

    # t=16 -- ASSERTING ACCEPT FLAG (LOADING WEIGHTS INTO FIRST PE) (LOADING FIRST BIAS)
    dut.instruction.value = 0b0_1_0_01_11_0_0000000000000000 | to_fixed(-0.00012433409574441612) # b2 to bias
    await ClockCycles(dut.clk, 1)

    # t=17 -- ASSERTING ACCEPT FLAG and START FLAG (LOADING SECOND BIAS)
    dut.instruction.value = 0b1_1_0_01_11_0_0000000000000000 | to_fixed(0.25080394744873047) # b1 to bias
    await ClockCycles(dut.clk, 1)

    # t=18 -- ASSERTING SWITCH FLAG 
    dut.instruction.value = 0b1_0_1_01_00_0_00000000_00000000
    await ClockCycles(dut.clk, 1)
    
    # t=19
    dut.instruction.value = 0b1_0_0_01_00_0_00000000_00000000 # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    # # t=20
    dut.instruction.value = 0b1_1_0_01_00_0_00000000_00000000 # 0 to acc 2
    await ClockCycles(dut.clk, 1)

    # # t=21
    dut.instruction.value = 0b0_1_0_01_11_0_00000000_00000000 | to_fixed(0.0) # 0 to bias
    await ClockCycles(dut.clk, 1)

    # # t=22
    dut.instruction.value = 0b0_0_1_01_11_0_00000000_00000000  | to_fixed(-0.28798729181289673) # b3 to bias
    await ClockCycles(dut.clk, 1)

    # t=23
    dut.instruction.value = 0b1_0_0_01_00_0_00000000_00000000 

    # t=24
    dut.instruction.value = 0b1_0_0_01_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=25
    dut.instruction.value = 0b1_0_0_01_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=26
    dut.instruction.value = 0b1_0_0_01_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=27
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=28
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=29
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=30
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=31
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)

    # t=32
    dut.instruction.value = 0b0_0_0_10_00_0_00000000_00000000 
    await ClockCycles(dut.clk, 1)


