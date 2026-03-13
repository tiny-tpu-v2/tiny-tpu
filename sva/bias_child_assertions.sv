// ============================================================
// bias_child_assertions.sv
// SVA bind module for bias_child.sv
//
// Bind with:
//   bind bias_child bias_child_assertions u_bc_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module bias_child_assertions (
    input logic clk,
    input logic rst,

    input logic signed [15:0] bias_scalar_in,
    input logic               bias_sys_valid_in,
    input logic signed [15:0] bias_sys_data_in,

// DUT outputs — must be 'input' direction to avoid multiple-driver in bind context
    input logic               bias_Z_valid_out,
    input logic signed [15:0] bias_z_data_out,
    input logic               bias_overflow_out  // BUG-OVF-1 sticky overflow flag
);

    // ------------------------------------------------------------------
    // BC-A1 / BC-A2: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_valid;
        @(posedge clk) rst |=> !bias_Z_valid_out;
    endproperty

    property p_rst_clears_data;
        @(posedge clk) rst |=> (bias_z_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // BC-A3: bias_Z_valid_out is the registered version of bias_sys_valid_in.
    // RTL:  if (bias_sys_valid_in) valid_out <= 1 ; else valid_out <= 0
    //       → valid_out always equals $past(bias_sys_valid_in).
    // ------------------------------------------------------------------
    property p_valid_out_mirrors_valid_in;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (bias_Z_valid_out == $past(bias_sys_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // BC-A4: When bias_sys_valid_in is low, bias_z_data_out == 0.
    // RTL:  else branch assigns bias_z_data_out <= 16'b0 explicitly.
    // ------------------------------------------------------------------
    property p_data_zero_when_invalid;
        @(posedge clk) disable iff (rst)
        !bias_sys_valid_in |=> (bias_z_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // BC-A5: When valid, output must be non-zero if both inputs are non-zero
    //        (basic liveness: the adder is doing something)
    // ------------------------------------------------------------------
    property p_data_nonzero_when_both_inputs_nonzero;
        @(posedge clk) disable iff (rst)
        (bias_sys_valid_in && bias_sys_data_in != 16'b0 && bias_scalar_in != 16'b0)
        |=> (bias_z_data_out != 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    BC_A1: assert property (p_rst_clears_valid)                      else $error("BC-A1 FAIL: rst did not clear bias_Z_valid_out");
    BC_A2: assert property (p_rst_clears_data)                       else $error("BC-A2 FAIL: rst did not clear bias_z_data_out");
    BC_A3: assert property (p_valid_out_mirrors_valid_in)            else $error("BC-A3 FAIL: bias_Z_valid_out != registered(bias_sys_valid_in)");
    BC_A4: assert property (p_data_zero_when_invalid)                else $error("BC-A4 FAIL: bias_z_data_out != 0 when valid_in=0");
    BC_A5: assert property (p_data_nonzero_when_both_inputs_nonzero) else $error("BC-A5 FAIL: output is 0 with non-zero inputs");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    BC_C1: cover property (@(posedge clk) disable iff (rst) bias_sys_valid_in && !bias_sys_data_in[15] && !bias_scalar_in[15]);  // positive + positive
    BC_C2: cover property (@(posedge clk) disable iff (rst) bias_sys_valid_in &&  bias_sys_data_in[15] && !bias_scalar_in[15]);  // negative input + positive bias
    BC_C3: cover property (@(posedge clk) disable iff (rst) $fell(bias_sys_valid_in));                                          // valid deasserted mid-stream

endmodule
