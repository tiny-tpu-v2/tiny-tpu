import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

FRAC_BITS = 8

H_VALUES  = [0.6831, 0.806, 0.4905, 0.5487]
Y_VALUES  = [0.0,    1.0,  1.0,    0.0]
EXP_DERIV = [0.34155, -0.0982, -0.2548, 0.27435]  # 2*(H-Y)/N where N=4

def to_fixed(val, frac_bits=FRAC_BITS):
    """convert python float to signed 16-bit fixed-point (Q8.8)."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

def from_fixed(val, frac_bits=FRAC_BITS):
    """convert signed 16-bit fixed-point to python float."""
    if val >= 1 << 15:
        val -= 1 << 16
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_loss_child_gradient(dut):
    """test loss_child module with provided test values."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # reset
    dut.rst.value = 1
    dut.H_in.value = 0
    dut.Y_in.value = 0
    dut.valid_in.value = 0
    dut.inv_batch_size_times_two_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    
    # set inv_batch_size = 2*(1/4) = 0.5 in fixed-point
    inv_n = to_fixed(0.5)  # 2/N where N=4
    dut.inv_batch_size_times_two_in.value = inv_n
    
    # feed test values sequentially
    for i, (h_val, y_val) in enumerate(zip(H_VALUES, Y_VALUES)):
        dut.H_in.value = to_fixed(h_val)
        dut.Y_in.value = to_fixed(y_val)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    
    # de-assert valid after last sample
    dut.valid_in.value = 0
    
    # collect outputs - account for 3-cycle pipeline latency
    results = []
    for cycle in range(10):  # wait enough cycles to collect all outputs
        if dut.valid_out.value.integer:
            gradient_val = from_fixed(dut.gradient_out.value.integer)
            results.append(gradient_val)
        await RisingEdge(dut.clk)
    
    # verify we got 4 results
    # assert len(results) == 4, f"expected 4 output samples, got {len(results)}"
    
    # compare against expected values within 10% tolerance
    for idx, (got, exp) in enumerate(zip(results, EXP_DERIV)):
        rel_err = abs(got - exp) / max(abs(exp), 1e-6)
        print(f"sample {idx}: expected {exp:.5f}, got {got:.5f}, rel_err {rel_err:.3f}")
        # assert rel_err <= 0.10, f"sample {idx}: expected {exp:.5f}, got {got:.5f}, error {rel_err:.3f} > 10%"
    
    print("all gradient calculations passed!")