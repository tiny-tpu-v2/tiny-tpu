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


h0 = [
    [0.0, 0.0],
    [0.0, 1.0],
    [1.0, 0.0],
    [1.0, 1.0]
]
h1 = [
    [0.0, 0.0],
    [0.0, 0.0],
    [0.0, 0.0],
    [0.0, 0.0]
]
h2 = [
    [0.0, 0.0],
    [0.0, 0.0], 
    [0.0, 0.0],
    [0.0, 0.0]
]

# w1 = [[0.8821601271629333, -0.8821614980697632], [-1.0646932125091553, 1.0648175477981567]]
# w2 = [[1.1482632160186768, 1.216535210609436], [0.0, 0.0]]
# b1 = [0.25080394744873047, -0.00012433409574441612]
# b2 = [-0.28798729181289673, 0.0]

w1 = [[0.5406103730201721, 0.5869042277336121], [-0.16565565764904022, 0.6495562791824341]]
w2 = [[-0.34425848722457886, 0.4152715504169464], [0.0, 0.0]]
b1 = [-0.15492962300777435, 0.14268755912780762]
b2 = [0.6233449578285217, 0.0]


# INSTRUCTION FORMAT (24 bits):
# [24] - lr_is_backward flag
# [23] - nn_start flag
# [22] - accept flag
# [21] - switch flag
# [19:20] - activation_datapath ([19] feeds output to accumulators, [20] feeds output to host)
# [17:18] - load_weights, load_bias, load_inputs
# [16] - address
# [15:0] - weight_data_in

instruction_list = [
    # LOADING INPUTS (passing in the inputs as such: [(0,0), (1,1), (0,1), (1,0)])
    0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(h0[0][0]), # 0 to acc 1
    0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(h0[0][1]), # 0 to acc 2
    0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(h0[1][0]), # 1 to acc 1
    0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(h0[1][1]), # 1 to acc 2
    0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(h0[2][0]), # 0 to acc 1
    0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(h0[2][1]), # 1 to acc 2
    0b0_0_0_0_01_01_0_0000000000000000 | to_fixed(h0[3][0]), # 1 to acc 1
    0b0_0_0_0_01_01_1_0000000000000000 | to_fixed(h0[3][1]), # 1 to acc 2

    # LOADING WEIGHTS
    0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w1[0][1]),   # w12 to acc 1
    0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w1[1][1]),   # w22 to acc 2
    0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w1[0][0]),   # w11 to acc 1
    0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w1[1][0]),   # w21 to acc 2
    0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w2[0][1]),   # wB2 to acc 1
    0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w2[1][1]),   # 0 to acc 2
    0b0_0_0_0_01_10_0_0000000000000000 | to_fixed(w2[0][0]),   # wB1 to acc 1
    0b0_0_0_0_01_10_1_0000000000000000 | to_fixed(w2[1][0]),   # 0 to acc 2

    # t=16 -- ASSERTING ACCEPT FLAG (LOADING WEIGHTS INTO FIRST PE) (LOADING FIRST BIAS)
    0b0_0_1_0_01_11_0_0000000000000000 | to_fixed(b1[1]), # b2 to 
    
    # t=17 -- ASSERTING ACCEPT FLAG and START FLAG (LOADING SECOND BIAS)
    0b0_1_1_0_01_11_0_0000000000000000 | to_fixed(b1[0]), # b1 to bias

    # t=18 -- ASSERTING SWITCH FLAG 
    0b0_1_0_1_11_00_0_00000000_00000000,

    # t=19
    0b0_1_0_0_11_00_0_00000000_00000000,

    # t=20
    0b0_1_1_0_11_00_0_00000000_00000000,

    # t=21
    0b0_0_1_0_11_11_0_00000000_00000000 | to_fixed(b2[1]), # 0 to bias

    # t=22
    0b0_0_0_1_11_11_0_00000000_00000000  | to_fixed(b2[0]), # b3 to bias

    # t=23
    0b0_1_0_0_11_00_0_00000000_00000000,

    # t=24
    0b0_1_0_0_11_00_0_00000000_00000000,

    # t=25
    0b0_1_0_0_11_00_0_00000000_00000000,

    # t=26
    0b0_1_0_0_11_00_0_00000000_00000000,

    # t=27
    0b0_0_0_0_10_00_0_00000000_00000000,

    # t=28
    0b0_0_0_0_10_00_0_00000000_00000000,

    # t=29
    0b0_0_0_0_10_00_0_00000000_00000000,

    # t=30
    0b0_0_0_0_10_00_0_00000000_00000000,

    # t=31
    0b0_0_0_0_10_00_0_00000000_00000000,

    # t=32
    0b0_0_0_0_10_00_0_00000000_00000000,
]

@cocotb.test()
async def test_nn(dut): 

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await ClockCycles(dut.clk, 1)
    
    # rst the DUT (device under test)
    dut.rst.value = 1
    dut.instruction.value = 0b0_0_0_0_00_00_0_0000000000000000 
    await ClockCycles(dut.clk, 1)

    # rst is off now
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

    #########################################################

    counter1 = 0
    counter2 = 0
    for instruction in instruction_list:
        dut.instruction.value = instruction
        if(dut.nn_valid_out_1.value):
            if(counter1//4 == 0):
                h1[counter1%4][0] = int(dut.nn_data_out_1.value)
            elif(counter1//4 == 1):
                h2[counter1%4][0] = int(dut.nn_data_out_1.value)
            counter1 += 1

        if(dut.nn_valid_out_2.value):
            if(counter2//4 == 0):
                h1[counter2%4][1] = int(dut.nn_data_out_2.value)
            elif(counter2//4 == 1):
                h2[counter2%4][1] = int(dut.nn_data_out_2.value)
            counter2 += 1

        await ClockCycles(dut.clk, 1)

    await ClockCycles(dut.clk, 5)



    h1_converted = [[from_fixed(val) for val in row] for row in h1]
    h2_converted = [[from_fixed(val) for val in row] for row in h2]

    print("H1")
    for row in h1_converted:
        print(row)
    print("")

    print("H2")
    for row in h2_converted:
        print(row)



