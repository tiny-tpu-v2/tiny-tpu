import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_unified_buffer(dut):
    # create a clock (10 nanoseconds clock period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start()) # start the clock

    # initialize all inputs to zero
    dut.ub_write_data_1_in.value = 0
    dut.ub_write_data_2_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    dut.ub_write_start_in.value = 0
    dut.ub_read_start_in.value = 0
    dut.ub_transpose.value = 0 # if want tranpose, turn it to 1 (will make all test cases transpose)
    dut.ub_read_addr_in.value = 0
    dut.ub_num_mem_locations_in.value = 0

    # initialize bias port inputs to zero (read-only)
    dut.ub_bias_read_start_in.value = 0
    dut.ub_bias_addr_in.value = 0
    dut.ub_bias_num_mem_locations_in.value = 0

    # initialize activation port inputs to zero (read-only)
    dut.ub_activation_read_start_in.value = 0
    dut.ub_activation_addr_in.value = 0
    dut.ub_activation_num_mem_locations_in.value = 0

    # initialize loss port inputs to zero (read-only)
    dut.ub_loss_read_start_in.value = 0
    dut.ub_loss_addr_in.value = 0
    dut.ub_loss_num_mem_locations_in.value = 0

    # initialize activation derivative port inputs to zero (read-only)
    dut.ub_activation_derivative_read_start_in.value = 0
    dut.ub_activation_derivative_addr_in.value = 0
    dut.ub_activation_derivative_num_mem_locations_in.value = 0

    # reset the dut
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # test 1: write sequential data to buffer
    print("\n=== test 1: writing data to buffer ===")
    dut.ub_write_start_in.value = 1
    
    # write single value at location 0
    dut.ub_write_data_1_in.value = to_fixed(1.0) ## FROM Leaky relu 1
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 0
    await RisingEdge(dut.clk)
    
    # write two values at locations 1,2
    dut.ub_write_data_1_in.value = to_fixed(3.0) ## FROM Leaky relu 1
    dut.ub_write_data_2_in.value = to_fixed(2.0) ## FROM Leaky relu 2
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)
    
    # write two more values at locations 3,4
    dut.ub_write_data_1_in.value = to_fixed(5.0) ## FROM Leaky relu 1
    dut.ub_write_data_2_in.value = to_fixed(4.0) ## FROM Leaky relu 2
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)
    
    # write single value at location 5
    dut.ub_write_data_1_in.value = 0
    dut.ub_write_data_2_in.value = to_fixed(6.0)
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 1
    await RisingEdge(dut.clk)
    
    # stop writing
    dut.ub_write_start_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    await ClockCycles(dut.clk, 2)
    
    # test 2: read even number of locations (6 values starting from address 0)
    print("\n=== test 2: reading even number of locations ===")
    dut.ub_read_addr_in.value = 0b0000
    dut.ub_num_mem_locations_in.value = 6
    dut.ub_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_read_start_in.value = 0  # pulse read start
    # cycle 1: expect first value on data_1_out only
    # assert dut.ub_valid_1_out.value == 1
    # assert dut.ub_valid_2_out.value == 0
    print(f"cycle 1: data_1={dut.ub_data_1_out.value.integer/256.0:.1f} (expect 1.0)")
    await RisingEdge(dut.clk)
    # cycle 2: expect values 2,3
    # assert dut.ub_valid_1_out.value == 1
    # assert dut.ub_valid_2_out.value == 1
    print(f"cycle 2: data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 2.0, 3.0)")
    await RisingEdge(dut.clk)
    # cycle 3: expect values 4,5
    # assert dut.ub_valid_1_out.value == 1
    # assert dut.ub_valid_2_out.value == 1
    print(f"cycle 3: data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 4.0, 5.0)")
    await RisingEdge(dut.clk)
    # cycle 4: expect last value on data_2_out only
    # assert dut.ub_valid_1_out.value == 0
    # assert dut.ub_valid_2_out.value == 1
    print(f"cycle 4: data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 6.0)")
    await RisingEdge(dut.clk)
    # should be back to idle
    # assert dut.ub_valid_1_out.value == 0
    # assert dut.ub_valid_2_out.value == 0
    await ClockCycles(dut.clk, 2)
    
    # test 3: read odd number of locations (5 values starting from address 1)
    print("\n=== test 3: reading odd number of locations ===")
    dut.ub_read_addr_in.value = 0x0000
    dut.ub_num_mem_locations_in.value = 4
    dut.ub_transpose.value = 1 # enable transpose!!!!
    dut.ub_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_read_start_in.value = 0
    
    # cycle 1: expect value at addr 1 on data_1_out
    # assert dut.ub_valid_1_out.value == 1
    # assert dut.ub_valid_2_out.value == 0
    print(f"cycle 1: data_1={dut.ub_data_1_out.value.integer/256.0:.1f} (expect 2.0)")
    await RisingEdge(dut.clk)
    
    # cycle 2: expect values at addr 2,3
    # assert dut.ub_valid_1_out.value == 1
    # assert dut.ub_valid_2_out.value == 1
    print(f"cycle 2: data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 3.0, 4.0)")
    await RisingEdge(dut.clk)
    
    # cycle 3: expect last value at addr 5 on data_2_out
    # assert dut.ub_valid_1_out.value == 0
    # assert dut.ub_valid_2_out.value == 1
    print(f"cycle 3: data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 6.0)")
    await RisingEdge(dut.clk)
    
    await ClockCycles(dut.clk, 2)
    
    
    # test 4: concurrent read and write
    print("\n=== test 4: concurrent read and write ===")
    # start writing new data while reading
    dut.ub_write_start_in.value = 1
    dut.ub_write_data_1_in.value = to_fixed(10.0)
    dut.ub_write_data_2_in.value = to_fixed(11.0)
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 1
    # no transpose for this test
    dut.ub_transpose.value = 0 # disable transpose!!!!
    # simultaneously start reading from address 0
    dut.ub_read_addr_in.value = 0
    dut.ub_num_mem_locations_in.value = 6
    dut.ub_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_read_start_in.value = 0
    # continue writing while reading
    print(f"concurrent cycle 1: reading data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, writing 10.0, 11.0")
    
    dut.ub_write_data_1_in.value = to_fixed(12.0)
    dut.ub_write_data_2_in.value = to_fixed(13.0)
    await RisingEdge(dut.clk)
    
    print(f"concurrent cycle 2: reading data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, data_2={dut.ub_data_2_out.value.integer/256.0:.1f}, writing 12.0, 13.0")
    
    dut.ub_write_start_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    await RisingEdge(dut.clk)
    
    print(f"concurrent cycle 3: reading data_2={dut.ub_data_2_out.value.integer/256.0:.1f}")
    
    await ClockCycles(dut.clk, 8)
    
    # test 5: edge case - read 2 locations
    print("\n=== test 5: edge case - read exactly 2 locations ===")
    dut.ub_read_addr_in.value = 0
    dut.ub_num_mem_locations_in.value = 2
    dut.ub_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_read_start_in.value = 0
    
    # cycle 1: first value
    print(f"cycle 1: data_1={dut.ub_data_1_out.value.integer/256.0:.1f}, valid_1={dut.ub_valid_1_out.value}, valid_2={dut.ub_valid_2_out.value}")
    await RisingEdge(dut.clk)
    
    # cycle 2: second value on data_2
    print(f"cycle 2: data_2={dut.ub_data_2_out.value.integer/256.0:.1f}, valid_1={dut.ub_valid_1_out.value}, valid_2={dut.ub_valid_2_out.value}")
    await RisingEdge(dut.clk)
    
    print("\n=== main port tests complete ===")

    # ======================================
    # bias port tests (read-only)
    # ======================================
    
    # test 6: bias port read even number of locations (6 values starting from address 0)
    print("\n=== test 6: bias port - reading even number of locations ===")
    dut.ub_bias_addr_in.value = 0b0000
    dut.ub_bias_num_mem_locations_in.value = 6
    dut.ub_bias_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_bias_read_start_in.value = 0  # pulse read start
    # cycle 1: expect first value on data_1_out only
    print(f"cycle 1: bias_data_1={dut.ub_bias_data_1_out.value.integer/256.0:.1f} (expect 7.0)")
    await RisingEdge(dut.clk)
    # cycle 2: expect values 8,9
    print(f"cycle 2: bias_data_1={dut.ub_bias_data_1_out.value.integer/256.0:.1f}, bias_data_2={dut.ub_bias_data_2_out.value.integer/256.0:.1f} (expect 8.0, 9.0)")
    await RisingEdge(dut.clk)
    # cycle 3: expect values 10,11
    print(f"cycle 3: bias_data_1={dut.ub_bias_data_1_out.value.integer/256.0:.1f}, bias_data_2={dut.ub_bias_data_2_out.value.integer/256.0:.1f} (expect 10.0, 11.0)")
    await RisingEdge(dut.clk)
    # cycle 4: expect last value on data_2_out only
    print(f"cycle 4: bias_data_2={dut.ub_bias_data_2_out.value.integer/256.0:.1f} (expect 12.0)")
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 2)
    
    print("\n=== bias port tests complete ===")

    # ======================================
    # activation port tests (read-only)
    # ======================================
    
    # test 8: activation port read even number of locations (6 values starting from address 0)
    print("\n=== test 8: activation port - reading even number of locations ===")
    dut.ub_activation_addr_in.value = 0b0000
    dut.ub_activation_num_mem_locations_in.value = 6
    dut.ub_activation_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_activation_read_start_in.value = 0  # pulse read start
    # cycle 1: expect first value on data_1_out only
    print(f"cycle 1: activation_data_1={dut.ub_activation_data_1_out.value.integer/256.0:.1f} (expect 10.0)")
    await RisingEdge(dut.clk)
    # cycle 2: expect values from global write
    print(f"cycle 2: activation_data_1={dut.ub_activation_data_1_out.value.integer/256.0:.1f}, activation_data_2={dut.ub_activation_data_2_out.value.integer/256.0:.1f} (expect 11.0, 12.0)")
    await RisingEdge(dut.clk)
    # cycle 3: expect more values from global write
    print(f"cycle 3: activation_data_1={dut.ub_activation_data_1_out.value.integer/256.0:.1f}, activation_data_2={dut.ub_activation_data_2_out.value.integer/256.0:.1f} (expect 13.0, 0.0)")
    await RisingEdge(dut.clk)
    # cycle 4: expect last value on data_2_out only
    print(f"cycle 4: activation_data_2={dut.ub_activation_data_2_out.value.integer/256.0:.1f} (expect 0.0)")
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 2)
    
    print("\n=== activation port tests complete ===")

    # ======================================
    # loss port tests (read-only)
    # ======================================
    
    # test 9: loss port read even number of locations (6 values starting from address 0)
    print("\n=== test 9: loss port - reading even number of locations ===")
    dut.ub_loss_addr_in.value = 0b0000
    dut.ub_loss_num_mem_locations_in.value = 6
    dut.ub_loss_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_loss_read_start_in.value = 0  # pulse read start
    # cycle 1: expect first value on data_1_out only
    print(f"cycle 1: loss_data_1={dut.ub_loss_data_1_out.value.integer/256.0:.1f} (expect 10.0)")
    await RisingEdge(dut.clk)
    # cycle 2: expect values from global write
    print(f"cycle 2: loss_data_1={dut.ub_loss_data_1_out.value.integer/256.0:.1f}, loss_data_2={dut.ub_loss_data_2_out.value.integer/256.0:.1f} (expect 11.0, 12.0)")
    await RisingEdge(dut.clk)
    # cycle 3: expect more values from global write
    print(f"cycle 3: loss_data_1={dut.ub_loss_data_1_out.value.integer/256.0:.1f}, loss_data_2={dut.ub_loss_data_2_out.value.integer/256.0:.1f} (expect 13.0, 0.0)")
    await RisingEdge(dut.clk)
    # cycle 4: expect last value on data_2_out only
    print(f"cycle 4: loss_data_2={dut.ub_loss_data_2_out.value.integer/256.0:.1f} (expect 0.0)")
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 2)
    
    print("\n=== loss port tests complete ===")

    # ======================================
    # activation derivative port tests (read-only)
    # ======================================
    
    # test 10: activation derivative port read even number of locations (6 values starting from address 0)
    print("\n=== test 10: activation derivative port - reading even number of locations ===")
    dut.ub_activation_derivative_addr_in.value = 0b0000
    dut.ub_activation_derivative_num_mem_locations_in.value = 6
    dut.ub_activation_derivative_read_start_in.value = 1
    await RisingEdge(dut.clk)
    dut.ub_activation_derivative_read_start_in.value = 0  # pulse read start
    # cycle 1: expect first value on data_1_out only
    print(f"cycle 1: activation_derivative_data_1={dut.ub_activation_derivative_data_1_out.value.integer/256.0:.1f} (expect 10.0)")
    await RisingEdge(dut.clk)
    # cycle 2: expect values from global write
    print(f"cycle 2: activation_derivative_data_1={dut.ub_activation_derivative_data_1_out.value.integer/256.0:.1f}, activation_derivative_data_2={dut.ub_activation_derivative_data_2_out.value.integer/256.0:.1f} (expect 11.0, 12.0)")
    await RisingEdge(dut.clk)
    # cycle 3: expect more values from global write
    print(f"cycle 3: activation_derivative_data_1={dut.ub_activation_derivative_data_1_out.value.integer/256.0:.1f}, activation_derivative_data_2={dut.ub_activation_derivative_data_2_out.value.integer/256.0:.1f} (expect 13.0, 0.0)")
    await RisingEdge(dut.clk)
    # cycle 4: expect last value on data_2_out only
    print(f"cycle 4: activation_derivative_data_2={dut.ub_activation_derivative_data_2_out.value.integer/256.0:.1f} (expect 0.0)")
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 2)
    
    print("\n=== activation derivative port tests complete ===")

    # ======================================
    # multi-port simultaneous tests
    # ======================================
    
    # test 14: write to all 5 ports simultaneously
    print("\n=== test 14: writing to all 5 ports simultaneously ===")
    
    # start writing on all ports
    dut.ub_write_start_in.value = 1
    dut.ub_bias_read_start_in.value = 1
    dut.ub_activation_read_start_in.value = 1
    dut.ub_loss_read_start_in.value = 1
    dut.ub_activation_derivative_read_start_in.value = 1
    
    # write single values to main port only
    dut.ub_write_data_1_in.value = to_fixed(31.0)
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 0
    
    await RisingEdge(dut.clk)
    
    # write dual values to main port only
    dut.ub_write_data_1_in.value = to_fixed(37.0)
    dut.ub_write_data_2_in.value = to_fixed(36.0)
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 1
    
    await RisingEdge(dut.clk)
    
    # stop writing on all ports
    dut.ub_write_start_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    
    dut.ub_bias_read_start_in.value = 0
    
    dut.ub_activation_read_start_in.value = 0
    
    dut.ub_loss_read_start_in.value = 0
    
    dut.ub_activation_derivative_read_start_in.value = 0
    
    await ClockCycles(dut.clk, 2)
    print("multi-port write completed")
    
    # test 15: read from all 5 ports simultaneously 
    print("\n=== test 15: reading from all 5 ports simultaneously ===")
    
    # start reading from all ports (reading 4 locations each from address 0)
    dut.ub_read_addr_in.value = 0
    dut.ub_num_mem_locations_in.value = 4
    dut.ub_read_start_in.value = 1
    
    # ensure all write signals are off for reading operations
    dut.ub_bias_addr_in.value = 0
    dut.ub_bias_num_mem_locations_in.value = 4
    dut.ub_bias_read_start_in.value = 1
    
    dut.ub_activation_addr_in.value = 0
    dut.ub_activation_num_mem_locations_in.value = 4
    dut.ub_activation_read_start_in.value = 1
    
    dut.ub_loss_addr_in.value = 0
    dut.ub_loss_num_mem_locations_in.value = 4
    dut.ub_loss_read_start_in.value = 1
    
    dut.ub_activation_derivative_addr_in.value = 0
    dut.ub_activation_derivative_num_mem_locations_in.value = 4
    dut.ub_activation_derivative_read_start_in.value = 1
    
    await RisingEdge(dut.clk)
    
    # stop read start signals (pulse)
    dut.ub_read_start_in.value = 0
    dut.ub_bias_read_start_in.value = 0
    dut.ub_activation_read_start_in.value = 0
    dut.ub_loss_read_start_in.value = 0
    dut.ub_activation_derivative_read_start_in.value = 0
    
    await ClockCycles(dut.clk, 3)
    print("multi-port read completed")
    
    # test 16: concurrent write/read operations across all ports
    print("\n=== test 16: concurrent write/read operations across all ports ===")
    
    # start concurrent operations: write new data while reading existing data
    # write to higher memory addresses while reading from lower addresses
    
    # start writing to all ports at higher addresses
    dut.ub_write_start_in.value = 1
    dut.ub_write_data_1_in.value = to_fixed(46.0)
    dut.ub_write_data_2_in.value = to_fixed(47.0) 
    dut.ub_write_valid_1_in.value = 1
    dut.ub_write_valid_2_in.value = 1
    
    dut.ub_bias_read_start_in.value = 1
    
    dut.ub_activation_read_start_in.value = 1
    
    dut.ub_loss_read_start_in.value = 1
    
    dut.ub_activation_derivative_read_start_in.value = 1
    
    # simultaneously start reading from all ports at lower addresses
    dut.ub_read_addr_in.value = 1
    dut.ub_num_mem_locations_in.value = 2
    dut.ub_read_start_in.value = 1
    
    dut.ub_bias_addr_in.value = 1  
    dut.ub_bias_num_mem_locations_in.value = 2
    # note: bias_start_in already set to 1 for writing, this will handle both
    
    dut.ub_activation_addr_in.value = 1
    dut.ub_activation_num_mem_locations_in.value = 2
    # note: activation_start_in already set to 1 for writing
    
    dut.ub_loss_addr_in.value = 1
    dut.ub_loss_num_mem_locations_in.value = 2
    # note: loss_start_in already set to 1 for writing
    
    dut.ub_activation_derivative_addr_in.value = 1
    dut.ub_activation_derivative_num_mem_locations_in.value = 2
    # note: activation_derivative_start_in already set to 1 for writing
    
    await RisingEdge(dut.clk)
    
    # stop read start signals (pulse)
    dut.ub_read_start_in.value = 0
    
    # print(f"concurrent cycle 1: writing new values while reading:")
    # print(f"  main: reading data_1={dut.ub_data_1_out.value.integer/256.0:.1f} (expect 36.0), writing 46.0, 47.0")
    # print(f"  bias: reading data_1={dut.ub_bias_data_1_out.value.integer/256.0:.1f} (expect 38.0), writing 48.0, 49.0")
    # print(f"  activation: reading data_1={dut.ub_activation_data_1_out.value.integer/256.0:.1f} (expect 40.0), writing 50.0, 51.0")
    # print(f"  loss: reading data_1={dut.ub_loss_data_1_out.value.integer/256.0:.1f} (expect 42.0), writing 52.0, 53.0")
    # print(f"  activation_derivative: reading data_1={dut.ub_activation_derivative_data_1_out.value.integer/256.0:.1f} (expect 44.0), writing 54.0, 55.0")
    
    await RisingEdge(dut.clk)
    
    # print(f"concurrent cycle 2:")
    # print(f"  main: reading data_2={dut.ub_data_2_out.value.integer/256.0:.1f} (expect 37.0)")
    # print(f"  bias: reading data_2={dut.ub_bias_data_2_out.value.integer/256.0:.1f} (expect 39.0)")
    # print(f"  activation: reading data_2={dut.ub_activation_data_2_out.value.integer/256.0:.1f} (expect 41.0)")
    # print(f"  loss: reading data_2={dut.ub_loss_data_2_out.value.integer/256.0:.1f} (expect 43.0)")
    # print(f"  activation_derivative: reading data_2={dut.ub_activation_derivative_data_2_out.value.integer/256.0:.1f} (expect 45.0)")
    
    # stop writing on all ports
    dut.ub_write_start_in.value = 0
    dut.ub_write_valid_1_in.value = 0
    dut.ub_write_valid_2_in.value = 0
    
    dut.ub_bias_read_start_in.value = 0
    
    dut.ub_activation_read_start_in.value = 0
    
    dut.ub_loss_read_start_in.value = 0
    
    dut.ub_activation_derivative_read_start_in.value = 0
    
    await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 2)
    print("concurrent multi-port operations completed")

    print("\n=== all tests complete ===")