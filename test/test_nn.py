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

w1 = [[0.5406103730201721, 0.5869042277336121],
      [-0.16565565764904022, 0.6495562791824341]]

b1 = [-0.15492962300777435, 0.14268755912780762]

w2 = [-0.34425848722457886, 0.4152715504169464]

b2 = [0.6233449578285217]


@cocotb.test()
async def test_nn(dut):
    clockCyclesNS = 0  

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await ClockCycles(dut.clk, 1)
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    
    dut.instruction.value = 0b0_0_0_0_00_00_0_0000000000000000 
    await ClockCycles(dut.clk, 1)
    clockCyclesNS += 10
    

    # rst is off now
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)
    clockCyclesNS += 10

    #########################################################

    INSTRUCTIONS = [
        # LOADING INPUTS (passing in the inputs as such: [(0,0), (1,1), (0,1), (1,0)])
        0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(0.0),  # 0 to acc 1
        0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(0.0),  # 0 to acc 2
        0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(0.0),  # 1 to acc 1
        0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(1.0),  # 0 to acc 2
        0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(1.0),  # 0 to acc 1
        0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(0.0),  # 1 to acc 2
        0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(1.0),  # 1 to acc 1
        0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(1.0),  # 1 to acc 2

        # LOADING WEIGHTS
        0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w1[0][1]),    # w12 to acc 1
        0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w1[1][1]),    # w22 to acc 2
        0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w1[0][0]),    # w11 to acc 1
        0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w1[1][0]),    # w21 to acc 2
        0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w2[1]),       # wB2 to acc 1
        0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(0.0),         # 0 to acc 2
        0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w2[0]),       # wB1 to acc 1
        0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(0.0),         # 0 to acc 2

        0b0_0_1_0_11_11_0_0000000000000000 | to_fixed(b1[1]),       # t=16 -- ASSERTING ACCEPT FLAG (LOADING WEIGHTS INTO FIRST PE) (LOADING FIRST BIAS) b2 to bias
        0b0_1_1_0_11_11_0_0000000000000000 | to_fixed(b1[0]),       # t=17 -- ASSERTING ACCEPT FLAG and START FLAG (LOADING SECOND BIAS) b1 to bias
        0b0_1_0_1_11_00_0_00000000_00000000,                        # t=18 -- ASSERTING SWITCH FLAG
        0b0_1_0_0_11_00_0_00000000_00000000,                        # t=19 -- 0 to acc 2
        0b0_1_1_0_11_00_0_00000000_00000000,                        # t=20 -- 0 to acc 2
        0b0_0_1_0_11_11_0_00000000_00000000 | to_fixed(0.0),        # t=21 -- 0 to bias
        0b0_0_0_1_11_11_0_00000000_00000000 | to_fixed(b2[0]),      # t=22 -- b3 to bias
        0b0_1_0_0_11_00_0_00000000_00000000,                        # t=23 ### STARTING SECOND LAYER
        0b0_1_0_0_11_00_0_00000000_00000000,                        # t=24
        0b0_1_0_0_11_00_0_00000000_00000000,                        # t=25
        0b0_1_0_0_11_00_0_00000000_00000000,                        # t=26
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=27
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=28
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=29
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=30
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=31
        0b0_0_0_0_10_00_0_00000000_00000000,                        # t=32
    ]

    stashed_H_col1 = []
    stashed_H_col2 = []

    for instruction in INSTRUCTIONS:
        dut.instruction.value = instruction

        if dut.nn_valid_out_1.value == 1: 
            print(f"Stashed activation H: {from_fixed(int(dut.nn_data_out_1.value))}")
            stashed_H_col1.append(from_fixed(int(dut.nn_data_out_1.value)))

        if dut.nn_valid_out_2.value == 1: 
            print(f"Stashed activation H: {from_fixed(int(dut.nn_data_out_2.value))}")
            stashed_H_col2.append(from_fixed(int(dut.nn_data_out_2.value)))

        await ClockCycles(dut.clk, 1)
        clockCyclesNS += 10

    await ClockCycles(dut.clk, 1)
    clockCyclesNS += 10

    print("---------------------------------------------")
    print(f"Stashed activation H1: {stashed_H_col1}")
    print("---------------------------------------------")
    print(f"Stashed activation H2: {stashed_H_col2}")
    print("---------------------------------------------")
    print(f"Clock Cycles: {clockCyclesNS} ns")







    


