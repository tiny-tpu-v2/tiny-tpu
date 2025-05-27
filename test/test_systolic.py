# import cocotb
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

def to_fixed(val, frac_bits=8):
    """Convert a float to 16-bit fixed point with 8 fractional bits."""
    scaled = int(round(val * (1 << frac_bits)))
    return scaled & 0xFFFF

@cocotb.test()
async def test_systolic_array(dut): 

    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst.value = 1
    dut.sys_start.value = 0 # this would enable the PE to start processing the inputs. but it doesnt here
    dut.sys_accept_w_in.value = 0
    dut.sys_switch_in.value = 0

    # for inputs
    dut.sys_data_in_11.value = to_fixed(0.0)
    dut.sys_data_in_21.value = to_fixed(0.0)

    # for weights
    dut.sys_weight_in_11.value = to_fixed(0.0)
    dut.sys_weight_in_12.value = to_fixed(0.0)
    await RisingEdge(dut.clk)

    # Release reset
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # t = 0: Stage the weights
    dut.sys_accept_w_in.value = 1; # THIS IS THE "A" in xander's drawing!
    dut.sys_weight_in_11.value = to_fixed(2.0) # in next cycle, gets latched in background buffer of pe11!
    await RisingEdge(dut.clk)

    # t = 1: Weight should now be loaded in background buffer
    dut.sys_accept_w_in.value = 1 # on next clock cycle 10 should be latched in background buffer of pe21, 20 should be latched in background buffer of pe 11!
    dut.sys_weight_in_11.value = to_fixed(1.0)
    dut.sys_weight_in_12.value = to_fixed(4.0)
    await RisingEdge(dut.clk)

    # t = 2: Assert the pe_switch_out signal to bring weight from bb to fb (foreground buffer) in next cycle
    dut.sys_accept_w_in.value = 0 # stop loading weights into background buffer. 
    dut.sys_switch_in.value = 1 # bring weight from bb to fb in next cc
    dut.sys_start.value = 1 # we want inputs to start moving in next cc, so we assert this flag here. 
    dut.sys_weight_in_12.value = to_fixed(3.0) # SINCE accept_is still 1, this will be latched in next cc of bb buffer of pe 12!
    dut.sys_data_in_11.value = to_fixed(5.0)
    dut.sys_data_in_21.value = to_fixed(0.0)
    await RisingEdge(dut.clk)
    dut.sys_data_in_11.value = to_fixed(0.0)

    
    # t = 3: 
    # in this clock cycle, pe_valid_in and pe_switch_in are latched into pe11, now they are asserted to the outside of pe12 and pe21
    # pe11 should also output a psum here, and pass its input to pe12
    
    # pe_switch_in and pe_valid_in should also be zero here 
    # I HAVE MANUALLY DEFINED pe_switch_in AND pe_valid_in ZERO here. This is decided by the compiler.

    # dut.sys_accept_w_in.value = 0 # stays zero
    dut.sys_switch_in.value = 0 # changed to zero
    dut.sys_start.value = 0 # changed to zero

    dut.sys_data_in_11.value = to_fixed(0.0)
    dut.sys_data_in_21.value = to_fixed(6.0)

    # await RisingEdge(dut.clk)

    # dut.sys_data_in_11.value = to_fixed(0.0)
    # dut.sys_data_in_21.value = to_fixed(0.0)
    await ClockCycles(dut.clk, 5)
