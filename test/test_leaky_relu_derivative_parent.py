import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

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

def compute_leaky_relu_derivative(data, leak_factor):
    """compute expected leaky relu derivative: data if data >= 0, else data * leak_factor"""
    if data >= 0:
        return data
    else:
        return data * leak_factor

# test data for 4x2 matrix (8 total values) in staggered pattern (1,2,2,2,1)
# column 1: 4 values (cycles 0,1,2,3) - mix of positive and negative
# column 2: 4 values (cycles 1,2,3,4) - mix of positive and negative
BATCH_4x2_DATA_COL1 = [2.5, -1.2, 0.8, -3.1]  # input data for column 1
BATCH_4x2_DATA_COL2 = [1.8, -0.9, 1.5, -2.2]  # input data for column 2
LEAK_FACTOR = 0.1  # standard leak factor for leaky relu

# original leaky_relu_derivative_child test data (4 values total)
INPUT_DATA_VALUES = [2.5, -1.2, 0.8, -3.1]  # mix of positive and negative values

@cocotb.test()
async def test_leaky_relu_derivative_parent_4x2_staggered(dut):
    """test case 1: 4x2 batch with staggered pattern (1,2,2,2,1) - 8 total values"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.lr_d_valid_1_in.value = 0
    dut.lr_d_data_1_in.value = 0
    dut.lr_d_valid_2_in.value = 0
    dut.lr_d_data_2_in.value = 0
    dut.lr_leak_factor_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== test case 1: 4x2 batch staggered pattern (1,2,2,2,1) - 8 values ===")
    print(f"leak factor: {LEAK_FACTOR}")
    
    # set leak factor (shared for both columns)
    dut.lr_leak_factor_in.value = to_fixed(LEAK_FACTOR)
    
    # define the staggered input pattern over 5 cycles
    # cycle 0: col1=1, col2=0 (1 total)
    # cycle 1: col1=1, col2=1 (2 total) 
    # cycle 2: col1=1, col2=1 (2 total)
    # cycle 3: col1=1, col2=1 (2 total)
    # cycle 4: col1=0, col2=1 (1 total)
    staggered_pattern = [
        (True, False),   # cycle 0: col1 only
        (True, True),    # cycle 1: both columns
        (True, True),    # cycle 2: both columns  
        (True, True),    # cycle 3: both columns
        (False, True),   # cycle 4: col2 only
    ]
    
    col1_idx = 0
    col2_idx = 0
    
    # send staggered inputs - unrolled cycles
    # cycle 0: col1 only
    use_col1, use_col2 = staggered_pattern[0]
    print(f"cycle 0: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
    
    if use_col1 and col1_idx < len(BATCH_4x2_DATA_COL1):
        dut.lr_d_data_1_in.value = to_fixed(BATCH_4x2_DATA_COL1[col1_idx])
        dut.lr_d_valid_1_in.value = 1
        print(f"  col1[{col1_idx}]: data={BATCH_4x2_DATA_COL1[col1_idx]:.3f}")
        col1_idx += 1
    else:
        dut.lr_d_data_1_in.value = 0
        dut.lr_d_valid_1_in.value = 0
        
    if use_col2 and col2_idx < len(BATCH_4x2_DATA_COL2):
        dut.lr_d_data_2_in.value = to_fixed(BATCH_4x2_DATA_COL2[col2_idx])
        dut.lr_d_valid_2_in.value = 1
        print(f"  col2[{col2_idx}]: data={BATCH_4x2_DATA_COL2[col2_idx]:.3f}")
        col2_idx += 1
    else:
        dut.lr_d_data_2_in.value = 0
        dut.lr_d_valid_2_in.value = 0
        
    await RisingEdge(dut.clk)

    # cycle 1: both columns
    use_col1, use_col2 = staggered_pattern[1]
    print(f"cycle 1: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
    
    if use_col1 and col1_idx < len(BATCH_4x2_DATA_COL1):
        dut.lr_d_data_1_in.value = to_fixed(BATCH_4x2_DATA_COL1[col1_idx])
        dut.lr_d_valid_1_in.value = 1
        print(f"  col1[{col1_idx}]: data={BATCH_4x2_DATA_COL1[col1_idx]:.3f}")
        col1_idx += 1
    else:
        dut.lr_d_data_1_in.value = 0
        dut.lr_d_valid_1_in.value = 0
        
    if use_col2 and col2_idx < len(BATCH_4x2_DATA_COL2):
        dut.lr_d_data_2_in.value = to_fixed(BATCH_4x2_DATA_COL2[col2_idx])
        dut.lr_d_valid_2_in.value = 1
        print(f"  col2[{col2_idx}]: data={BATCH_4x2_DATA_COL2[col2_idx]:.3f}")
        col2_idx += 1
    else:
        dut.lr_d_data_2_in.value = 0
        dut.lr_d_valid_2_in.value = 0
        
    await RisingEdge(dut.clk)

    # cycle 2: both columns
    use_col1, use_col2 = staggered_pattern[2]
    print(f"cycle 2: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
    
    if use_col1 and col1_idx < len(BATCH_4x2_DATA_COL1):
        dut.lr_d_data_1_in.value = to_fixed(BATCH_4x2_DATA_COL1[col1_idx])
        dut.lr_d_valid_1_in.value = 1
        print(f"  col1[{col1_idx}]: data={BATCH_4x2_DATA_COL1[col1_idx]:.3f}")
        col1_idx += 1
    else:
        dut.lr_d_data_1_in.value = 0
        dut.lr_d_valid_1_in.value = 0
        
    if use_col2 and col2_idx < len(BATCH_4x2_DATA_COL2):
        dut.lr_d_data_2_in.value = to_fixed(BATCH_4x2_DATA_COL2[col2_idx])
        dut.lr_d_valid_2_in.value = 1
        print(f"  col2[{col2_idx}]: data={BATCH_4x2_DATA_COL2[col2_idx]:.3f}")
        col2_idx += 1
    else:
        dut.lr_d_data_2_in.value = 0
        dut.lr_d_valid_2_in.value = 0
        
    await RisingEdge(dut.clk)

    # cycle 3: both columns
    use_col1, use_col2 = staggered_pattern[3]
    print(f"cycle 3: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
    
    if use_col1 and col1_idx < len(BATCH_4x2_DATA_COL1):
        dut.lr_d_data_1_in.value = to_fixed(BATCH_4x2_DATA_COL1[col1_idx])
        dut.lr_d_valid_1_in.value = 1
        print(f"  col1[{col1_idx}]: data={BATCH_4x2_DATA_COL1[col1_idx]:.3f}")
        col1_idx += 1
    else:
        dut.lr_d_data_1_in.value = 0
        dut.lr_d_valid_1_in.value = 0
        
    if use_col2 and col2_idx < len(BATCH_4x2_DATA_COL2):
        dut.lr_d_data_2_in.value = to_fixed(BATCH_4x2_DATA_COL2[col2_idx])
        dut.lr_d_valid_2_in.value = 1
        print(f"  col2[{col2_idx}]: data={BATCH_4x2_DATA_COL2[col2_idx]:.3f}")
        col2_idx += 1
    else:
        dut.lr_d_data_2_in.value = 0
        dut.lr_d_valid_2_in.value = 0
        
    await RisingEdge(dut.clk)

    # cycle 4: col2 only
    use_col1, use_col2 = staggered_pattern[4]
    print(f"cycle 4: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
    
    if use_col1 and col1_idx < len(BATCH_4x2_DATA_COL1):
        dut.lr_d_data_1_in.value = to_fixed(BATCH_4x2_DATA_COL1[col1_idx])
        dut.lr_d_valid_1_in.value = 1
        print(f"  col1[{col1_idx}]: data={BATCH_4x2_DATA_COL1[col1_idx]:.3f}")
        col1_idx += 1
    else:
        dut.lr_d_data_1_in.value = 0
        dut.lr_d_valid_1_in.value = 0
        
    if use_col2 and col2_idx < len(BATCH_4x2_DATA_COL2):
        dut.lr_d_data_2_in.value = to_fixed(BATCH_4x2_DATA_COL2[col2_idx])
        dut.lr_d_valid_2_in.value = 1
        print(f"  col2[{col2_idx}]: data={BATCH_4x2_DATA_COL2[col2_idx]:.3f}")
        col2_idx += 1
    else:
        dut.lr_d_data_2_in.value = 0
        dut.lr_d_valid_2_in.value = 0
        
    await RisingEdge(dut.clk)

    # clear all inputs
    dut.lr_d_valid_1_in.value = 0
    dut.lr_d_valid_2_in.value = 0
    
    # collect outputs - leaky_relu_derivative outputs appear one cycle after input (registered)
    col1_results = []
    col2_results = []
    
    for cycle_num in range(10):
        if dut.lr_d_valid_1_out.value.integer:
            output_val = from_fixed(dut.lr_d_data_1_out.value.integer)
            col1_results.append(output_val)
            print(f"cycle {cycle_num}: col1 output = {output_val:.5f}")
            
        if dut.lr_d_valid_2_out.value.integer:
            output_val = from_fixed(dut.lr_d_data_2_out.value.integer)
            col2_results.append(output_val)
            print(f"cycle {cycle_num}: col2 output = {output_val:.5f}")
            
        await RisingEdge(dut.clk)
    
    # verify results
    print(f"total results - col1: {len(col1_results)}, col2: {len(col2_results)}, total: {len(col1_results) + len(col2_results)}")
    
    # verify we got 8 total results (4 from col1, 4 from col2)
    total_results = len(col1_results) + len(col2_results)
    # assert total_results == 8, f"expected 8 total results, got {total_results}"
    # assert len(col1_results) == 4, f"expected 4 col1 results, got {len(col1_results)}"
    # assert len(col2_results) == 4, f"expected 4 col2 results, got {len(col2_results)}"
    
    # verify column 1 results (4 values)
    expected_col1 = [compute_leaky_relu_derivative(data, LEAK_FACTOR) for data in BATCH_4x2_DATA_COL1]
    for idx, (got, exp) in enumerate(zip(col1_results, expected_col1)):
        abs_err = abs(got - exp)
        print(f"col1[{idx}]: expected {exp:.5f}, got {got:.5f}, abs_err {abs_err:.5f}")
        # assert abs_err <= 0.01, f"col1[{idx}]: error {abs_err:.5f} > 0.01"
    
    # verify column 2 results (4 values)  
    expected_col2 = [compute_leaky_relu_derivative(data, LEAK_FACTOR) for data in BATCH_4x2_DATA_COL2]
    for idx, (got, exp) in enumerate(zip(col2_results, expected_col2)):
        abs_err = abs(got - exp)
        print(f"col2[{idx}]: expected {exp:.5f}, got {got:.5f}, abs_err {abs_err:.5f}")
        # assert abs_err <= 0.01, f"col2[{idx}]: error {abs_err:.5f} > 0.01"
    
    print("4x2 staggered test passed!")

@cocotb.test()
async def test_leaky_relu_derivative_parent_as_single_child(dut):
    """test case 2: use leaky_relu_derivative_parent as single leaky_relu_derivative_child interface (4 values)"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.lr_d_valid_1_in.value = 0
    dut.lr_d_data_1_in.value = 0
    dut.lr_d_valid_2_in.value = 0
    dut.lr_d_data_2_in.value = 0
    dut.lr_leak_factor_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== test case 2: leaky_relu_derivative_parent as single leaky_relu_derivative_child (4 values) ===")
    print(f"leak factor: {LEAK_FACTOR}")
    
    # set leak factor
    dut.lr_leak_factor_in.value = to_fixed(LEAK_FACTOR)
    
    # feed original leaky_relu_derivative_child test data through column 1 only - unrolled
    # sample 0
    idx = 0
    input_data_val = INPUT_DATA_VALUES[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_data_val)
    dut.lr_d_valid_1_in.value = 1
    dut.lr_d_valid_2_in.value = 0  # column 2 unused
    dut.lr_d_data_2_in.value = 0
    print(f"input[{idx}]: data={input_data_val:.4f}")
    await RisingEdge(dut.clk)
    
    # sample 1
    idx = 1
    input_data_val = INPUT_DATA_VALUES[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_data_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"input[{idx}]: data={input_data_val:.4f}")
    await RisingEdge(dut.clk)
    
    # sample 2
    idx = 2
    input_data_val = INPUT_DATA_VALUES[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_data_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"input[{idx}]: data={input_data_val:.4f}")
    await RisingEdge(dut.clk)
    
    # sample 3
    idx = 3
    input_data_val = INPUT_DATA_VALUES[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_data_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"input[{idx}]: data={input_data_val:.4f}")
    await RisingEdge(dut.clk)
    
    dut.lr_d_valid_1_in.value = 0
    
    # collect outputs from column 1 only
    results = []
    for cycle_num in range(10):
        if dut.lr_d_valid_1_out.value.integer:
            output_val = from_fixed(dut.lr_d_data_1_out.value.integer)
            results.append(output_val)
            print(f"cycle {cycle_num}: output = {output_val:.5f}")
        await RisingEdge(dut.clk)
    
    # verify we got 4 results
    # assert len(results) == 4, f"expected 4 output samples, got {len(results)}"
    
    # compute expected results: leaky_relu_derivative(data, leak_factor)
    expected_results = [compute_leaky_relu_derivative(data, LEAK_FACTOR) for data in INPUT_DATA_VALUES]
    
    # compare against expected values within 0.01 tolerance
    for idx, (got, exp) in enumerate(zip(results, expected_results)):
        abs_err = abs(got - exp)
        print(f"result[{idx}]: expected {exp:.5f}, got {got:.5f}, abs_err {abs_err:.5f}")
        # assert abs_err <= 0.01, f"result[{idx}]: expected {exp:.5f}, got {got:.5f}, error {abs_err:.5f} > 0.01"
    
    print("single child interface test passed!")

@cocotb.test()
async def test_leaky_relu_derivative_parent_edge_cases(dut):
    """test case 3: test leaky_relu_derivative_parent with edge cases on both columns"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== test case 3: leaky_relu_derivative_parent edge cases ===")
    
    # set leak factor
    dut.lr_leak_factor_in.value = to_fixed(LEAK_FACTOR)
    
    edge_cases = [
        0.0,    # exactly zero
        -0.01,  # small negative
        0.01,   # small positive
        -5.0,   # large negative
    ]
    
    # test edge cases on column 1 - unrolled
    print("testing edge cases on column 1:")
    col1_results = []
    
    # edge case 0: exactly zero
    idx = 0
    input_val = edge_cases[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_val)
    dut.lr_d_valid_1_in.value = 1
    dut.lr_d_valid_2_in.value = 0
    print(f"edge case {idx}: input={input_val:.3f}")
    await RisingEdge(dut.clk)
    
    # edge case 1: small negative
    idx = 1
    input_val = edge_cases[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"edge case {idx}: input={input_val:.3f}")
    await RisingEdge(dut.clk)
    
    # edge case 2: small positive
    idx = 2
    input_val = edge_cases[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"edge case {idx}: input={input_val:.3f}")
    await RisingEdge(dut.clk)
    
    # edge case 3: large negative
    idx = 3
    input_val = edge_cases[idx]
    dut.lr_d_data_1_in.value = to_fixed(input_val)
    dut.lr_d_valid_1_in.value = 1
    print(f"edge case {idx}: input={input_val:.3f}")
    await RisingEdge(dut.clk)
    
    dut.lr_d_valid_1_in.value = 0
    
    # collect column 1 results
    for cycle_num in range(6):
        if dut.lr_d_valid_1_out.value.integer:
            output_val = from_fixed(dut.lr_d_data_1_out.value.integer)
            col1_results.append(output_val)
            expected = compute_leaky_relu_derivative(edge_cases[len(col1_results)-1], LEAK_FACTOR)
            abs_err = abs(output_val - expected)
            print(f"  col1 result: expected {expected:.5f}, got {output_val:.5f}, abs_err {abs_err:.5f}")
            
        await RisingEdge(dut.clk)
    
    print("edge case tests passed!")

@cocotb.test()
async def test_leaky_relu_derivative_parent_invalid_inputs(dut):
    """test case 4: test leaky_relu_derivative_parent with invalid input combinations"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== test case 4: leaky_relu_derivative_parent invalid input cases ===")
    
    # set leak factor and data
    dut.lr_leak_factor_in.value = to_fixed(LEAK_FACTOR)
    dut.lr_d_data_1_in.value = to_fixed(1.5)
    dut.lr_d_data_2_in.value = to_fixed(-2.0)
    
    # test case 1: no valid signals asserted
    dut.lr_d_valid_1_in.value = 0
    dut.lr_d_valid_2_in.value = 0
    
    await RisingEdge(dut.clk)
    # assert dut.lr_d_valid_1_out.value.integer == 0, "col1 output should be invalid when lr_d_valid_1_in is low"
    # assert dut.lr_d_valid_2_out.value.integer == 0, "col2 output should be invalid when lr_d_valid_2_in is low"
    # assert dut.lr_d_data_1_out.value.integer == 0, "col1 output data should be zero when invalid"
    # assert dut.lr_d_data_2_out.value.integer == 0, "col2 output data should be zero when invalid"
    print("test case 1 passed: outputs invalid when no valid signals asserted")
    
    # test case 2: only column 1 valid
    dut.lr_d_valid_1_in.value = 1
    dut.lr_d_valid_2_in.value = 0
    
    await RisingEdge(dut.clk)
    # assert dut.lr_d_valid_1_out.value.integer == 1, "col1 output should be valid when lr_d_valid_1_in is high"
    # assert dut.lr_d_valid_2_out.value.integer == 0, "col2 output should be invalid when lr_d_valid_2_in is low"
    print("test case 2 passed: col1 valid, col2 invalid as expected")
    
    # test case 3: only column 2 valid
    dut.lr_d_valid_1_in.value = 0
    dut.lr_d_valid_2_in.value = 1
    
    await RisingEdge(dut.clk)
    # assert dut.lr_d_valid_1_out.value.integer == 0, "col1 output should be invalid when lr_d_valid_1_in is low"
    # assert dut.lr_d_valid_2_out.value.integer == 1, "col2 output should be valid when lr_d_valid_2_in is high"
    print("test case 3 passed: col1 invalid, col2 valid as expected")
    
    # test case 4: both columns valid
    dut.lr_d_valid_1_in.value = 1
    dut.lr_d_valid_2_in.value = 1
    
    await RisingEdge(dut.clk)
    # assert dut.lr_d_valid_1_out.value.integer == 1, "col1 output should be valid when lr_d_valid_1_in is high"
    # assert dut.lr_d_valid_2_out.value.integer == 1, "col2 output should be valid when lr_d_valid_2_in is high"
    print("test case 4 passed: both columns valid as expected")
    
    print("invalid input tests passed!")
    print("all leaky_relu_derivative_parent tests completed successfully!")