import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

X = [
 [2, 2],
 [0, 1],
 [1, 0,],
 [1, 1]
]

W1 =[
    [0.2985, -0.5792],
    [0.0913, 0.4234]
    ]

W1_grad = [
        [0.0405, 0.023], 
        [0.0455, 0.0258]
        ]

lr = 0.75


def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

def from_fixed(val, frac_bits=8):
    """convert signed 16-bit fixed-point to python float."""
    if val >= 1 << 15:
        val -= 1 << 16
    return float(val) / (1 << frac_bits)

def compute_gradient_descent(W_row, grad_row, lr_fixed):
    """Compute gradient descent for a row of weights."""
    updated_row = []
    for w, g in zip(W_row, grad_row):
        # Convert to fixed point
        w_fixed = to_fixed(w)
        g_fixed = to_fixed(g)
        
        # Perform gradient descent in fixed point: W_new = W_old - lr * grad
        # Convert lr back to float for computation, then convert result to fixed point
        lr_float = from_fixed(lr_fixed)
        w_float = from_fixed(w_fixed)
        g_float = from_fixed(g_fixed)
        
        updated_weight_float = w_float - lr_float * g_float
        updated_weight_fixed = to_fixed(updated_weight_float)
        updated_row.append(updated_weight_fixed)
    
    return updated_row

# function to compute gradient descent and print the results in fixed point format
def print_weights_fixed_point(weights_fixed, title):
    """Print weights in both fixed point and float format."""
    print(f"\n{title}:")
    for i, row in enumerate(weights_fixed):
        print(f"  Row {i}: ", end="")
        for j, weight_fixed in enumerate(row):
            weight_float = from_fixed(weight_fixed)
            print(f"0x{weight_fixed:04X} ({weight_float:.4f})", end="")
            if j < len(row) - 1:
                print(", ", end="")
        print()


@cocotb.test()
async def test_unified_buffer(dut):
    # create a clock (10 nanoseconds clock period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start()) # start the clock

    # Test addressed writing

    # reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)

    # set the address of where to start writing from
    dut.rst.value = 0
    dut.ub_wr_addr_in.value = 0 # begin at addr 0
    dut.ub_wr_addr_valid_in.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_addr_in.value = 12 # THIS SHOULD NOT LATCH INTO THE ADDR REGISTER 
    dut.ub_wr_addr_valid_in.value = 0    

    dut.ub_wr_data_in_1.value = to_fixed(X[0][0])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(X[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)


    dut.ub_wr_data_in_1.value = to_fixed(X[2][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[1][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(X[3][0])
    dut.ub_wr_data_in_2.value = to_fixed(X[2][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)


    dut.ub_wr_data_in_2.value = to_fixed(X[3][1])
    dut.ub_wr_valid_data_in_1.value = 0

    dut.ub_wr_addr_in.value = 8 ## first weight will be in address 8
    dut.ub_wr_addr_valid_in.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)
    
    dut.ub_wr_data_in_1.value = to_fixed(W1[0][0])
    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(W1[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(W1[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    dut.ub_wr_addr_valid_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_2.value = to_fixed(W1[1][1])
    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    # Testing reading X to left side of systolic array
    dut.ub_rd_input_start_in.value = 1
    dut.ub_rd_input_transpose.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in = 8
    await RisingEdge(dut.clk)

    dut.ub_rd_input_start_in.value = 0
    dut.ub_rd_input_transpose.value = 0
    dut.ub_rd_input_addr_in.value = 0
    dut.ub_rd_input_loc_in = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)

    # Testing reading W1^T so that it can be properly fed into the systolic array
    dut.ub_rd_weight_start_in.value = 1
    dut.ub_rd_weight_transpose.value = 1
    dut.ub_rd_weight_addr_in.value = 9
    dut.ub_rd_weight_loc_in = 4
    await RisingEdge(dut.clk)

    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in = 0
    await RisingEdge(dut.clk)
    
    await ClockCycles(dut.clk, 10)

    # Testing reading W1 so that it can be properly fed into the systolic array
    # for non transpose address = 10 and make transpose = 0
    dut.ub_rd_weight_start_in.value = 1
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 10
    dut.ub_rd_weight_loc_in = 4
    await RisingEdge(dut.clk)

    dut.ub_rd_weight_start_in.value = 0
    dut.ub_rd_weight_transpose.value = 0
    dut.ub_rd_weight_addr_in.value = 0
    dut.ub_rd_weight_loc_in = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)

    dut.rst.value = 1
    await RisingEdge(dut.clk)

    dut.rst.value = 0

    await RisingEdge(dut.clk)
    dut.ub_wr_addr_in.value = 0 ## first weight will be in address 8
    dut.ub_wr_addr_valid_in.value = 1
    await RisingEdge(dut.clk)
    
    dut.ub_wr_data_in_1.value = to_fixed(W1[0][0])
    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_1.value = to_fixed(W1[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(W1[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    dut.ub_wr_addr_valid_in.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in_2.value = to_fixed(W1[1][1])
    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_addr_in.value = 4
    dut.ub_wr_addr_valid_in.value = 1

    await RisingEdge(dut.clk)

    # write gradient to address 4
    dut.ub_wr_addr_valid_in.value = 0
    dut.ub_wr_data_in_1.value = to_fixed(W1_grad[0][0])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 0
    await RisingEdge(dut.clk)

    
    dut.ub_wr_data_in_1.value = to_fixed(W1_grad[1][0])
    dut.ub_wr_data_in_2.value = to_fixed(W1_grad[0][1])
    dut.ub_wr_valid_data_in_1.value = 1
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)
    
    dut.ub_wr_data_in_2.value = to_fixed(W1_grad[1][1])
    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_valid_data_in_1.value = 0
    dut.ub_wr_valid_data_in_2.value = 0

    await ClockCycles(dut.clk, 10)

    # Testing gradient descent
    
    dut.ub_grad_descent_lr_in.value = to_fixed(lr)
    dut.ub_grad_descent_w_old_addr_in.value = 0
    dut.ub_grad_descent_grad_addr_in.value = 4
    dut.ub_grad_descent_loc_in = 4

    await RisingEdge(dut.clk)

    dut.ub_grad_descent_start_in.value = 1
    
    await ClockCycles(dut.clk, 4)

    # Testing reading W1 from gradient descent
    dut.ub_grad_descent_start_in.value = 0

    # Compute and print updated weights in fixed point format
    lr_fixed = to_fixed(lr)
    updated_weights = []
    for i in range(len(W1)):
        updated_row = compute_gradient_descent(W1[i], W1_grad[i], lr_fixed)
        updated_weights.append(updated_row)
    
    print_weights_fixed_point(updated_weights, "Updated Weights (Fixed Point Format)")

    await ClockCycles(dut.clk, 10)
