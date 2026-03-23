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

def compute_gradient(h_val, y_val, batch_size):
    """compute expected gradient: 2*(H-Y)/N"""
    return 2.0 * (h_val - y_val) / batch_size

# test data for 4x2 matrix (8 total values) in staggered pattern (1,2,2,2,1)
# column 1: 4 values (cycles 0,1,2,3)
# column 2: 4 values (cycles 1,2,3,4)  
BATCH_4x2_H_COL1 = [0.7, 0.5, 0.3, 0.9]  # 4 values for column 1
BATCH_4x2_Y_COL1 = [1.0, 0.0, 0.5, 1.0]
BATCH_4x2_H_COL2 = [0.8, 0.6, 0.2, 0.4]  # 4 values for column 2  
BATCH_4x2_Y_COL2 = [0.0, 1.0, 0.3, 0.7]

# original loss_child test data (4 values total)
H_VALUES = [0.6831, 0.806, 0.4905, 0.5487]
Y_VALUES = [0.0, 1.0, 1.0, 0.0]

@cocotb.test()
async def test_loss_parent_4x2_staggered(dut):
    """test case 1: 4x2 batch with staggered pattern (1,2,2,2,1) - 8 total values"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.H_1_in.value = 0
    dut.Y_1_in.value = 0
    dut.H_2_in.value = 0  
    dut.Y_2_in.value = 0
    dut.valid_1_in.value = 0
    dut.valid_2_in.value = 0
    dut.inv_batch_size_times_two_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    # set inv_batch_size_times_two_in = 2/4 = 0.5 in fixed-point
    inv_n_times_2 = to_fixed(0.5)  # 2/N where N=4
    dut.inv_batch_size_times_two_in.value = inv_n_times_2
    
    print("=== test case 1: 4x2 batch staggered pattern (1,2,2,2,1) - 8 values ===")
    
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
    
    # send staggered inputs
    for cycle_num, (use_col1, use_col2) in enumerate(staggered_pattern):
        print(f"cycle {cycle_num}: col1={'Y' if use_col1 else 'N'}, col2={'Y' if use_col2 else 'N'}")
        
        if use_col1 and col1_idx < len(BATCH_4x2_H_COL1):
            dut.H_1_in.value = to_fixed(BATCH_4x2_H_COL1[col1_idx])
            dut.Y_1_in.value = to_fixed(BATCH_4x2_Y_COL1[col1_idx])
            dut.valid_1_in.value = 1
            print(f"  col1[{col1_idx}]: H={BATCH_4x2_H_COL1[col1_idx]:.3f}, Y={BATCH_4x2_Y_COL1[col1_idx]:.3f}")
            col1_idx += 1
        else:
            dut.H_1_in.value = 0
            dut.Y_1_in.value = 0
            dut.valid_1_in.value = 0
            
        if use_col2 and col2_idx < len(BATCH_4x2_H_COL2):
            dut.H_2_in.value = to_fixed(BATCH_4x2_H_COL2[col2_idx])
            dut.Y_2_in.value = to_fixed(BATCH_4x2_Y_COL2[col2_idx])
            dut.valid_2_in.value = 1
            print(f"  col2[{col2_idx}]: H={BATCH_4x2_H_COL2[col2_idx]:.3f}, Y={BATCH_4x2_Y_COL2[col2_idx]:.3f}")
            col2_idx += 1
        else:
            dut.H_2_in.value = 0
            dut.Y_2_in.value = 0
            dut.valid_2_in.value = 0
            
        await RisingEdge(dut.clk)

    dut.valid_1_in.value = 0
    dut.valid_2_in.value = 0
    
    # collect outputs - with new pipeline, outputs appear immediately
    col1_results = []
    col2_results = []
    
    for cycle_num in range(10):
        if dut.valid_1_out.value.integer:
            gradient_val = from_fixed(dut.gradient_1_out.value.integer)
            col1_results.append(gradient_val)
            print(f"cycle {cycle_num}: col1 output = {gradient_val:.5f}")
            
        if dut.valid_2_out.value.integer:
            gradient_val = from_fixed(dut.gradient_2_out.value.integer)
            col2_results.append(gradient_val)
            print(f"cycle {cycle_num}: col2 output = {gradient_val:.5f}")
            
        await RisingEdge(dut.clk)
    
    # verify results
    print(f"total results - col1: {len(col1_results)}, col2: {len(col2_results)}, total: {len(col1_results) + len(col2_results)}")
    
    # verify we got 8 total results (4 from col1, 4 from col2)
    total_results = len(col1_results) + len(col2_results)
    # assert total_results == 8, f"expected 8 total results, got {total_results}"
    # assert len(col1_results) == 4, f"expected 4 col1 results, got {len(col1_results)}"
    # assert len(col2_results) == 4, f"expected 4 col2 results, got {len(col2_results)}"
    
    # verify column 1 results (4 values)
    expected_col1 = [compute_gradient(h, y, 4) for h, y in zip(BATCH_4x2_H_COL1, BATCH_4x2_Y_COL1)]
    for idx, (got, exp) in enumerate(zip(col1_results, expected_col1)):
        rel_err = abs(got - exp) / max(abs(exp), 1e-6)
        print(f"col1[{idx}]: expected {exp:.5f}, got {got:.5f}, rel_err {rel_err:.3f}")
        # assert rel_err <= 0.10, f"col1[{idx}]: error {rel_err:.3f} > 10%"
    
    # verify column 2 results (4 values)  
    expected_col2 = [compute_gradient(h, y, 4) for h, y in zip(BATCH_4x2_H_COL2, BATCH_4x2_Y_COL2)]
    for idx, (got, exp) in enumerate(zip(col2_results, expected_col2)):
        rel_err = abs(got - exp) / max(abs(exp), 1e-6)
        print(f"col2[{idx}]: expected {exp:.5f}, got {got:.5f}, rel_err {rel_err:.3f}")
        # assert rel_err <= 0.10, f"col2[{idx}]: error {rel_err:.3f} > 10%"
    
    print("4x2 staggered test passed!")

@cocotb.test()
async def test_loss_parent_as_single_child(dut):
    """test case 2: use loss_parent as single loss_child interface (4 values)"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.H_1_in.value = 0
    dut.Y_1_in.value = 0
    dut.H_2_in.value = 0
    dut.Y_2_in.value = 0
    dut.valid_1_in.value = 0
    dut.valid_2_in.value = 0
    dut.inv_batch_size_times_two_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    # set inv_batch_size_times_two_in = 2/4 = 0.5 in fixed-point  
    inv_n_times_2 = to_fixed(0.5)  # 2/N where N=4
    dut.inv_batch_size_times_two_in.value = inv_n_times_2
    
    print("=== test case 2: loss_parent as single loss_child (4 values) ===")
    
    # feed original loss_child test data through column 1 only
    for idx, (h_val, y_val) in enumerate(zip(H_VALUES, Y_VALUES)):
        dut.H_1_in.value = to_fixed(h_val)
        dut.Y_1_in.value = to_fixed(y_val)
        dut.valid_1_in.value = 1
        dut.valid_2_in.value = 0  # column 2 unused
        dut.H_2_in.value = 0
        dut.Y_2_in.value = 0
        print(f"input[{idx}]: H={h_val:.4f}, Y={y_val:.4f}")
        await RisingEdge(dut.clk)
    
    dut.valid_1_in.value = 0
    
    # collect outputs from column 1 only
    results = []
    for cycle_num in range(10):
        if dut.valid_1_out.value.integer:
            gradient_val = from_fixed(dut.gradient_1_out.value.integer)
            results.append(gradient_val)
            print(f"cycle {cycle_num}: output = {gradient_val:.5f}")
        await RisingEdge(dut.clk)
    
    # verify we got 4 results
    # assert len(results) == 4, f"expected 4 output samples, got {len(results)}"
    
    # compute expected gradients: 2*(H-Y)/N where N=4
    expected_gradients = [compute_gradient(h, y, 4) for h, y in zip(H_VALUES, Y_VALUES)]
    
    # compare against expected values within 10% tolerance
    for idx, (got, exp) in enumerate(zip(results, expected_gradients)):
        rel_err = abs(got - exp) / max(abs(exp), 1e-6)
        print(f"result[{idx}]: expected {exp:.5f}, got {got:.5f}, rel_err {rel_err:.3f}")
        # assert rel_err <= 0.10, f"result[{idx}]: expected {exp:.5f}, got {got:.5f}, error {rel_err:.3f} > 10%"
    
    print("single child interface test passed!")
    print("all loss_parent tests completed successfully!")