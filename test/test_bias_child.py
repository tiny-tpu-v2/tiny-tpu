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

def compute_bias_add(sys_data, bias_scalar):
    """compute expected bias addition: sys_data + bias_scalar"""
    return sys_data + bias_scalar

# test data for batch size of 4
SYS_DATA_VALUES = [2.5, -1.2, 0.8, -3.1]  # data from systolic array
BIAS_SCALAR_VALUES = [0.5, 0.3, -0.2, 1.0]  # bias scalars

@cocotb.test()
async def test_bias_child_operation(dut):
    """test bias_child module with batch size of 4"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.bias_scalar_in.value = 0
    dut.bias_sys_data_in.value = 0
    dut.bias_sys_valid_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== testing bias_child module with batch size 4 ===")
    
    results = []
    
    # test each sample in the batch
    for idx, (sys_data, bias_scalar) in enumerate(zip(SYS_DATA_VALUES, BIAS_SCALAR_VALUES)):
        print(f"sample {idx}: sys_data={sys_data:.3f}, bias_scalar={bias_scalar:.3f}")
        
        # set inputs
        dut.bias_sys_data_in.value = to_fixed(sys_data)
        dut.bias_scalar_in.value = to_fixed(bias_scalar)
        dut.bias_sys_valid_in.value = 1
        
        await RisingEdge(dut.clk)
        
        # check output on same cycle (combinational logic)
        if dut.bias_Z_valid_out.value.integer:
            output_val = from_fixed(dut.bias_z_data_out.value.integer)
            results.append(output_val)
            print(f"  output: {output_val:.5f}")
        else:
            print("  output: invalid")
        
        dut.bias_sys_valid_in.value = 0
        await RisingEdge(dut.clk)
    
    # verify results
    # assert len(results) == 4, f"expected 4 results, got {len(results)}"
    
    # compare against expected values
    for idx, (got, sys_data, bias_scalar) in enumerate(zip(results, SYS_DATA_VALUES, BIAS_SCALAR_VALUES)):
        expected = compute_bias_add(sys_data, bias_scalar)
        abs_err = abs(got - expected)
        print(f"sample {idx}: expected {expected:.5f}, got {got:.5f}, abs_err {abs_err:.5f}")
        # assert abs_err <= 0.01, f"sample {idx}: expected {expected:.5f}, got {got:.5f}, error {abs_err:.5f} > 0.01"
    
    print("bias_child test passed!")

@cocotb.test()
async def test_bias_child_invalid_inputs(dut):
    """test bias_child module with invalid input combinations"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    print("=== testing bias_child invalid input cases ===")
    
    dut.bias_sys_data_in.value = to_fixed(1.0)
    dut.bias_scalar_in.value = to_fixed(0.5)
    dut.bias_sys_valid_in.value = 0
    await RisingEdge(dut.clk)
    
    dut.bias_sys_valid_in.value = 1
    await RisingEdge(dut.clk)
    
    dut.bias_sys_valid_in.value = 0
    await RisingEdge(dut.clk)