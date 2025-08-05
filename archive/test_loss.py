# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import RisingEdge, ClockCycles

# FRAC_BITS = 8

# H_VALUES  = [0.6831, 0.806, 0.4905, 0.5487]
# Y_VALUES  = [0.0,    1.0,  1.0,    0.0]
# EXP_DERIV = [0.34155, -0.0982, -0.2548, 0.27435]  # 2*(H-Y)/N where N=4

# def to_fixed(val, frac_bits=FRAC_BITS):
#     """Convert Python float to signed 16-bit fixed-point (Q8.8)."""
#     scaled = int(round(val * (1 << frac_bits)))
#     return scaled & 0xFFFF


# def from_fixed(val, frac_bits=FRAC_BITS):
#     if val >= 1 << 15:
#         val -= 1 << 16
#     return float(val) / (1 << frac_bits)





# @cocotb.test()
# async def test_loss_derivative(dut):
#     """Feed four samples sequentially and check dL/dH results ~ expected (+/-10%)."""

#     clock = Clock(dut.clk, 10, units="ns")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut.rst.value = 1
#     dut.valid_in_1.value = 0
#     dut.valid_in_2.value = 0
#     dut.H_in_1.value = 0
#     dut.H_in_2.value = 0
#     dut.target_Y_in_1.value = 0
#     dut.target_Y_in_2.value = 0
#     await RisingEdge(dut.clk)
#     dut.rst.value = 0

#     # Configure derivative mode, N = 4
#     # NOTE: num_samples_in should be an integer, not fixed-point
#     dut.compute_derivative.value = 1
#     dut.num_samples_in.value = 4  # Just use 4, not to_fixed(4.0)
#     await RisingEdge(dut.clk)

#     # Feed four samples sequentially through the first input port
#     for i, (h_val, y_val) in enumerate(zip(H_VALUES, Y_VALUES)):
#         dut.H_in_1.value        = to_fixed(h_val)
#         dut.target_Y_in_1.value = to_fixed(y_val)
#         dut.valid_in_1.value    = 1
#         dut.valid_in_2.value    = 0
#         await RisingEdge(dut.clk)

#     # De-assert valids after sending the last sample
#     dut.valid_in_1.value = 0
#     dut.valid_in_2.value = 0

#     # Collect outputs for enough cycles to get all 4 results
#     # With 3-cycle latency, outputs should appear on cycles 3,4,5,6 relative to start
#     results = []
#     for cycle in range(15):
#         if dut.valid_out_1.value.integer:
#             val = from_fixed(dut.loss_out_1.value.integer)
#             results.append(val)
#         await RisingEdge(dut.clk)

#     assert len(results) == 4, f"Did not receive 4 output samples, got {len(results)}"

#     # Compare against expected within 10 %
#     for idx, (got, exp) in enumerate(zip(results, EXP_DERIV)):
#         rel_err = abs(got - exp) / max(abs(exp), 1e-6)
#         assert rel_err <= 0.10, f"Sample {idx}: expected {exp:.5f}, got {got:.5f}"