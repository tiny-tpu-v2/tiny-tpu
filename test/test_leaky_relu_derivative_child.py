import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

FRAC_BITS = 8

def to_fixed(val, frac_bits=FRAC_BITS):
    """convert python float to signed 16-bit fixed-point (Q8.8)."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

def from_fixed(val, frac_bits=FRAC_BITS):
    """convert signed 16-bit fixed-point to python float."""
    if val >= 1 << 15:
        val -= 1 << 16
    return float(val) / (1 << frac_bits)

def compute_leaky_relu(data, leak_factor):
    """compute expected leaky relu: data if data >= 0, else data * leak_factor"""
    if data >= 0:
        return data
    else:
        return data * leak_factor

# test data for batch size of 4
INPUT_DATA_VALUES = [2.5, -1.2, 0.8, -3.1]  # mix of positive and negative values
LEAK_FACTOR = 0.1  # standard leak factor for leaky relu

@cocotb.test()
async def test_leaky_relu_child_operation(dut):
    """test leaky_relu_child module with batch size of 4"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.lr_d_valid_in.value = 0
    dut.lr_d_data_in.value = 0
    dut.lr_leak_factor_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== testing leaky_relu_child module with batch size 4 ===")
    print(f"leak factor: {LEAK_FACTOR}")
    
    # set leak factor (constant for all samples)
    dut.lr_leak_factor_in.value = to_fixed(LEAK_FACTOR)
    
    results = []
    
    # test each sample in the batch
    for idx, input_data in enumerate(INPUT_DATA_VALUES):
        print(f"sample {idx}: input_data={input_data:.3f}")
        
        # set inputs
        dut.lr_d_data_in.value = to_fixed(input_data)
        dut.lr_d_valid_in.value = 1
        
        await RisingEdge(dut.clk)
        
        # check output on this cycle (output is registered)
        if dut.lr_d_valid_out.value.integer:
            output_val = from_fixed(dut.lr_d_data_out.value.integer)
            results.append(output_val)
            print(f"  output: {output_val:.5f}")
        else:
            print("  output: invalid")
        
        # de-assert valid signal for next cycle
        dut.lr_d_valid_in.value = 0

    await ClockCycles(dut.clk, 10)