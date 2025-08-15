import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles


def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

X = [
    [1, 2],
    [3, 4],
    [5, 6],
    [7, 8],
]

@cocotb.test()
async def test_unified_buffer(dut):

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # rst the DUT (device under test)
    dut.rst.value = 1
    await RisingEdge(dut.clk)

    dut.rst.value = 0
    dut.learning_rate_in.value = to_fixed(2)
    dut.ub_wr_data_in[0].value = 0
    dut.ub_wr_data_in[1].value = 0
    dut.ub_wr_valid_in[0].value = 0
    dut.ub_wr_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    # write to UB
    dut.ub_wr_host_data_in[0].value = to_fixed(X[0][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = 0
    dut.ub_wr_host_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(X[1][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(X[0][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(X[2][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(X[1][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = to_fixed(X[3][0])
    dut.ub_wr_host_valid_in[0].value = 1
    dut.ub_wr_host_data_in[1].value = to_fixed(X[2][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = 0
    dut.ub_wr_host_valid_in[0].value = 0
    dut.ub_wr_host_data_in[1].value = to_fixed(X[3][1])
    dut.ub_wr_host_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_host_data_in[0].value = 0
    dut.ub_wr_host_valid_in[0].value = 0
    dut.ub_wr_host_data_in[1].value = 0
    dut.ub_wr_host_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    # Reading inputs from UB to left side of systolic array (untransposed)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 0     # Selecting input pointer
    dut.ub_rd_addr_in.value = 2
    dut.ub_rd_row_size.value = 3
    dut.ub_rd_col_size.value = 2
    dut.ub_rd_transpose.value = 0
    await RisingEdge(dut.clk)

    # Reading weights from UB to top of systolic array (untransposed)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 3
    dut.ub_rd_col_size.value = 2
    dut.ub_rd_transpose.value = 0
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.ub_rd_transpose.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 6)

    # Reading inputs from UB to left side of systolic array (transposed)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 3
    dut.ub_rd_col_size.value = 2
    dut.ub_rd_transpose.value = 1
    await RisingEdge(dut.clk)

    # Reading weights from UB to top of systolic array (transposed)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 1
    dut.ub_rd_addr_in.value = 2
    dut.ub_rd_row_size.value = 3
    dut.ub_rd_col_size.value = 2
    dut.ub_rd_transpose.value = 1
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.ub_rd_transpose.value = 0
    await RisingEdge(dut.clk)

    # Reading bias from UB to bias modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 2
    dut.ub_rd_addr_in.value = 5
    dut.ub_rd_row_size.value = 4
    dut.ub_rd_col_size.value = 3
    await RisingEdge(dut.clk)

    # Reading Y from UB to loss modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 3
    dut.ub_rd_addr_in.value = 2
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    # Reading H from UB to activation derivative modules in VPU
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 4
    dut.ub_rd_addr_in.value = 4
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 6)

    # Testing gradient descent (biases)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 5
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.ub_wr_data_in[0].value = to_fixed(X[2][0])
    dut.ub_wr_valid_in[0].value = 1
    dut.ub_wr_data_in[1].value = 0
    dut.ub_wr_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = to_fixed(X[3][0])
    dut.ub_wr_valid_in[0].value = 1
    dut.ub_wr_data_in[1].value = to_fixed(X[2][1])
    dut.ub_wr_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = 0
    dut.ub_wr_valid_in[0].value = 0
    dut.ub_wr_data_in[1].value = to_fixed(X[3][1])
    dut.ub_wr_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = 0
    dut.ub_wr_valid_in[0].value = 0
    dut.ub_wr_data_in[1].value = 0
    dut.ub_wr_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 6)

    # Testing gradient descent (weights)
    dut.ub_rd_start_in.value = 1
    dut.ub_ptr_select.value = 6
    dut.ub_rd_addr_in.value = 4
    dut.ub_rd_row_size.value = 2
    dut.ub_rd_col_size.value = 2
    await RisingEdge(dut.clk)

    dut.ub_rd_start_in.value = 0
    dut.ub_ptr_select.value = 0
    dut.ub_rd_addr_in.value = 0
    dut.ub_rd_row_size.value = 0
    dut.ub_rd_col_size.value = 0
    dut.ub_wr_data_in[0].value = to_fixed(X[0][0])
    dut.ub_wr_valid_in[0].value = 1
    dut.ub_wr_data_in[1].value = 0
    dut.ub_wr_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = to_fixed(X[1][0])
    dut.ub_wr_valid_in[0].value = 1
    dut.ub_wr_data_in[1].value = to_fixed(X[0][1])
    dut.ub_wr_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = 0
    dut.ub_wr_valid_in[0].value = 0
    dut.ub_wr_data_in[1].value = to_fixed(X[1][1])
    dut.ub_wr_valid_in[1].value = 1
    await RisingEdge(dut.clk)

    dut.ub_wr_data_in[0].value = 0
    dut.ub_wr_valid_in[0].value = 0
    dut.ub_wr_data_in[1].value = 0
    dut.ub_wr_valid_in[1].value = 0
    await RisingEdge(dut.clk)

    await ClockCycles(dut.clk, 10)
