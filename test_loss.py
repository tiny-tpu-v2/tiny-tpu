import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

def fixed_point_to_float(val, frac_bits=8):
    """Convert 16-bit signed fixed-point to float"""
    if val >= 2**15:
        val = val - 2**16
    return val / (2**frac_bits)

def float_to_fixed_point(val, frac_bits=8):
    """Convert float to 16-bit signed fixed-point"""
    fixed = int(val * (2**frac_bits))
    if fixed < 0:
        fixed = (1 << 16) + fixed
    return fixed & 0xFFFF

@cocotb.test()
async def test_loss_batch_size_4_single_child(dut):
    """Test loss module with batch size 4 using single child module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    
    # Test data: batch size 4
    H_values = [0.6831, 0.8036, 0.4905, 0.5487]  # Output activations
    Y_values = [0, 1, 1, 0]  # Labels
    batch_size = 4
    
    # Convert to fixed-point
    H_fixed = [float_to_fixed_point(h) for h in H_values]
    Y_fixed = [float_to_fixed_point(y) for y in Y_values]
    
    # Calculate expected MSE loss for verification
    expected_losses = []
    for h, y in zip(H_values, Y_values):
        diff = h - y
        loss = (diff ** 2) / batch_size
        expected_losses.append(loss)
    
    print(f\"Expected losses: {expected_losses}\")\n    print(f\"H values: {H_values}\")\n    print(f\"Y values: {Y_values}\")\n    \n    # Setup test inputs\n    dut.batch_size_in.value = batch_size\n    dut.loss_start_in.value = 1\n    dut.valid_in.value = 1\n    \n    # Test each sample (only using child 1 for this test)\n    for i, (h_val, y_val) in enumerate(zip(H_fixed, Y_fixed)):\n        print(f\"\\nCycle {i+1}: H={fixed_point_to_float(h_val):.4f}, Y={fixed_point_to_float(y_val):.4f}\")\n        \n        dut.H_col_1_in.value = h_val\n        dut.Y_col_1_in.value = y_val\n        dut.H_col_2_in.value = 0  # Not used in this test\n        dut.Y_col_2_in.value = 0  # Not used in this test\n        \n        await RisingEdge(dut.clk)\n        \n        # Wait for pipeline delay (3 cycles for loss_child)\n        if i >= 2:  # After pipeline fills\n            loss_out_1 = fixed_point_to_float(dut.loss_1_out.value)\n            valid_out_1 = dut.valid_1_out.value\n            \n            print(f\"  Output: loss_1={loss_out_1:.4f}, valid_1={valid_out_1}\")\n            \n            if valid_out_1:\n                # Check if output is reasonable (within expected range)\n                expected = expected_losses[i-2]  # Account for pipeline delay\n                print(f\"  Expected: {expected:.4f}\")\n                assert abs(loss_out_1 - expected) < 0.1, f\"Loss calculation error: got {loss_out_1}, expected {expected}\"\n    \n    # Wait for remaining pipeline to flush\n    for _ in range(5):\n        await RisingEdge(dut.clk)\n        loss_out_1 = fixed_point_to_float(dut.loss_1_out.value)\n        valid_out_1 = dut.valid_1_out.value\n        if valid_out_1:\n            print(f\"Final output: loss_1={loss_out_1:.4f}\")\n    \n    print(\"\\nTest passed: Single child loss module working correctly\")\n\n@cocotb.test()\nasync def test_loss_dual_child_modules(dut):\n    \"\"\"Test loss module using both child modules with staggered pattern\"\"\"\n    \n    # Setup clock\n    clock = Clock(dut.clk, 10, units=\"ns\")\n    cocotb.start_soon(clock.start())\n    \n    # Reset\n    dut.rst.value = 1\n    await RisingEdge(dut.clk)\n    dut.rst.value = 0\n    await RisingEdge(dut.clk)\n    \n    # Test data: batch size 6 to test both child modules\n    # Column 1 data\n    H1_values = [0.7234, 0.5891, 0.8156, 0.4923, 0.6745, 0.3821]\n    Y1_values = [1, 0, 1, 0, 1, 0]\n    \n    # Column 2 data  \n    H2_values = [0.6102, 0.7845, 0.3567, 0.9234, 0.5123, 0.8901]\n    Y2_values = [0, 1, 0, 1, 0, 1]\n    \n    batch_size = 6\n    \n    # Convert to fixed-point\n    H1_fixed = [float_to_fixed_point(h) for h in H1_values]\n    Y1_fixed = [float_to_fixed_point(y) for y in Y1_values]\n    H2_fixed = [float_to_fixed_point(h) for h in H2_values]\n    Y2_fixed = [float_to_fixed_point(y) for y in Y2_values]\n    \n    print(f\"Testing dual child modules with batch size {batch_size}\")\n    print(f\"Column 1 - H: {H1_values}\")\n    print(f\"Column 1 - Y: {Y1_values}\")\n    print(f\"Column 2 - H: {H2_values}\")\n    print(f\"Column 2 - Y: {Y2_values}\")\n    \n    # Setup test inputs\n    dut.batch_size_in.value = batch_size\n    dut.loss_start_in.value = 1\n    dut.valid_in.value = 1\n    \n    # Test staggered pattern: 1, 2, 2, 2, 2, 1\n    cycle_count = 0\n    for i in range(batch_size):\n        print(f\"\\nCycle {i+1}:\")\n        print(f\"  H1={H1_values[i]:.4f}, Y1={Y1_values[i]:.4f}\")\n        print(f\"  H2={H2_values[i]:.4f}, Y2={Y2_values[i]:.4f}\")\n        \n        dut.H_col_1_in.value = H1_fixed[i]\n        dut.Y_col_1_in.value = Y1_fixed[i]\n        dut.H_col_2_in.value = H2_fixed[i]\n        dut.Y_col_2_in.value = Y2_fixed[i]\n        \n        await RisingEdge(dut.clk)\n        cycle_count += 1\n        \n        # Check staggered output pattern after pipeline delay\n        if cycle_count >= 4:  # After pipeline fills\n            loss_out_1 = fixed_point_to_float(dut.loss_1_out.value)\n            loss_out_2 = fixed_point_to_float(dut.loss_2_out.value)\n            valid_out_1 = dut.valid_1_out.value\n            valid_out_2 = dut.valid_2_out.value\n            \n            print(f\"  Outputs: loss_1={loss_out_1:.4f} (valid={valid_out_1}), loss_2={loss_out_2:.4f} (valid={valid_out_2})\")\n            \n            # Verify staggered pattern\n            if cycle_count == 4:  # First output cycle - should be staggered (only child 1)\n                assert valid_out_1 == 1, \"First cycle should have valid_out_1\"\n                assert valid_out_2 == 0, \"First cycle should not have valid_out_2 (staggered)\"\n            elif cycle_count == batch_size + 3:  # Last output cycle - should be staggered (only child 2)\n                assert valid_out_1 == 0, \"Last cycle should not have valid_out_1 (staggered)\"\n                assert valid_out_2 == 1, \"Last cycle should have valid_out_2\"\n            else:  # Middle cycles - both should be valid\n                assert valid_out_1 == 1, f\"Middle cycle {cycle_count} should have valid_out_1\"\n                assert valid_out_2 == 1, f\"Middle cycle {cycle_count} should have valid_out_2\"\n    \n    # Wait for remaining pipeline to flush\n    for _ in range(5):\n        await RisingEdge(dut.clk)\n        cycle_count += 1\n        \n        loss_out_1 = fixed_point_to_float(dut.loss_1_out.value)\n        loss_out_2 = fixed_point_to_float(dut.loss_2_out.value)\n        valid_out_1 = dut.valid_1_out.value\n        valid_out_2 = dut.valid_2_out.value\n        \n        if valid_out_1 or valid_out_2:\n            print(f\"Flush cycle {cycle_count}: loss_1={loss_out_1:.4f} (valid={valid_out_1}), loss_2={loss_out_2:.4f} (valid={valid_out_2})\")\n    \n    print(\"\\nTest passed: Dual child loss modules with staggered pattern working correctly\")\n