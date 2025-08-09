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


@cocotb.test()
async def test_gradient_descent(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    

    old_weights =[
    [5.8, 2.7],
    [3.5, 4.8]]

    gradients = [
    [0.12, 0.91],
    [0.23, 0.11]
    ]

    # learning rate
    lr = to_fixed(0.1)

    # Reset
    dut.rst.value = 1
    dut.grad_descent_start_in.value = 0
    dut.lr_in.value = 0
    dut.W_old_in.value = 0
    dut.grad_in.value = 0

    await RisingEdge(dut.clk)
    dut.rst.value = 0

    await RisingEdge(dut.clk)

    dut.lr_in.value = lr
    dut.W_old_in.value = to_fixed(old_weights[0][0])
    dut.grad_in.value = to_fixed(gradients[0][0])
    dut.grad_descent_start_in.value = 1

    # await RisingEdge(dut.clk)
    # dut.grad_descent_start_in.value = 0

    # assert dut.W_updated_out.value == compute_gradient_descent(old_weights[0], gradients[0], lr)
    # assert dut.grad_descent_done_out.value == 1

    await RisingEdge(dut.clk)
    dut.grad_descent_start_in.value = 1
    dut.W_old_in.value = to_fixed(old_weights[0][1])
    dut.grad_in.value = to_fixed(gradients[0][1])

    # await RisingEdge(dut.clk)
    # dut.grad_descent_start_in.value = 0

    # assert dut.W_updated_out.value == compute_gradient_descent(old_weights[1], gradients[1], lr)
    # assert dut.grad_descent_done_out.value == 1

    await RisingEdge(dut.clk)
    dut.grad_descent_start_in.value = 1
    dut.W_old_in.value = to_fixed(old_weights[1][0])
    dut.grad_in.value = to_fixed(gradients[1][0])

    # await RisingEdge(dut.clk)
    # dut.grad_descent_start_in.value = 0

    # assert dut.W_updated_out.value == compute_gradient_descent(old_weights[2], gradients[2], lr)
    # assert dut.grad_descent_done_out.value == 1

    await RisingEdge(dut.clk)
    dut.grad_descent_start_in.value = 1
    dut.W_old_in.value = to_fixed(old_weights[1][1])
    dut.grad_in.value = to_fixed(gradients[1][1])

    # await RisingEdge(dut.clk)
    # dut.grad_descent_start_in.value = 0

    # assert dut.W_updated_out.value == compute_gradient_descent(old_weights[3], gradients[3], lr)
    # assert dut.grad_descent_done_out.value == 1

    await RisingEdge(dut.clk)
    dut.grad_descent_start_in.value = 0

    await ClockCycles(dut.clk, 10)

