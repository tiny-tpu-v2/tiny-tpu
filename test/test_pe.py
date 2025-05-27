import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

def to_fixed(val, frac_bits=8):
    return int(round(val * (1 << frac_bits))) & 0xFFFF

def from_fixed(val, frac_bits=8):
    if val >= (1 << 15):
        val -= (1 << 16)
    return float(val) / (1 << frac_bits)

@cocotb.test()
async def test_pe(dut):
    """Test the PE module with a variety of fixed-point inputs."""

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst.value = 1
    dut.pe_valid_in.value = 0 # this would enable the PE to start processing the inputs. but it doesnt here

    dut.pe_accept_w_in.value = 0
    dut.pe_input_in.value = to_fixed(0.0)
    dut.pe_weight_in.value = to_fixed(0.0)
    dut.pe_psum_in.value = to_fixed(0.0)
    await RisingEdge(dut.clk)

    # Release reset
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # t = 0: Stage the weights
    dut.pe_accept_w_in.value = 1; # THIS IS THE "A" in xander's drawing!
    dut.pe_weight_in.value = to_fixed(69.0) # in next cycle, gets latched in background buffer of pe11!
    await RisingEdge(dut.clk)


    # t = 1: Weight should now be loaded in background buffer
    dut.pe_accept_w_in.value = 1 # on next clock cycle 10 should be latched in background buffer of pe21, 20 should be latched in background buffer of pe 11!
    dut.pe_weight_in.value = to_fixed(10.0)
    await RisingEdge(dut.clk)

    # t = 2: Assert the pe_switch_out signal to bring weight from bb to fb (foreground buffer) in next cycle
    dut.pe_accept_w_in.value = 0 # stop loading weights into background buffer. 
    dut.pe_switch_in.value = 1 # bring weight from bb to fb in next cc
    dut.pe_valid_in.value = 1 # we want inputs to start moving in next cc, so we assert this flag here. 
    dut.pe_input_in.value = to_fixed(2.0)
    dut.pe_psum_in.value = to_fixed(50.0) 
    await RisingEdge(dut.clk)

    dut.pe_valid_in.value = 1
    await RisingEdge(dut.clk)

    dut.pe_valid_in.value = 0
    await RisingEdge(dut.clk)

    # t = 3: 
    # in this clock cycle, pe_valid_in and pe_switch_in are latched into pe11, now they are asserted to the outside of pe12 and pe21
    # pe11 should also output a psum here, and pass its input to pe12
    
    # pe_switch_in and pe_valid_in should also be zero here 
    # I HAVE MANUALLY DEFINED pe_switch_in AND pe_valid_in ZERO here. This is decided by the compiler.

    dut.pe_switch_in.value = 0 # bring weight from bb to fb in next cc
    dut.pe_valid_in.value = 0 # we want inputs to start moving in next cc, so we assert this flag here. 


    await ClockCycles(dut.clk, 3)

    