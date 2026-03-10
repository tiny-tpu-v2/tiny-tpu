// ============================================================
// leaky_relu_derivative_child_assertions.sv
// SVA bind module for leaky_relu_derivative_child.sv
//
// Bind with:
//   bind leaky_relu_derivative_child
//     leaky_relu_derivative_child_assertions u_lrd_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module leaky_relu_derivative_child_assertions (
    input logic clk,
    input logic rst,

    input logic               lr_d_valid_in,
    input logic signed [15:0] lr_d_data_in,
    input logic signed [15:0] lr_leak_factor_in,
    input logic signed [15:0] lr_d_H_data_in,

    output logic               lr_d_valid_out,
    output logic signed [15:0] lr_d_data_out
);

    // ------------------------------------------------------------------
    // LRD-A1: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_outputs;
        @(posedge clk) rst |=> (!lr_d_valid_out && lr_d_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LRD-A2: lr_d_valid_out is the registered version of lr_d_valid_in.
    // KEY DIFFERENCE from leaky_relu_child: there is NO override in the
    // else branch — lr_d_valid_out <= lr_d_valid_in executes unconditionally.
    // ------------------------------------------------------------------
    property p_valid_out_mirrors_valid_in;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (lr_d_valid_out == $past(lr_d_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // LRD-A3: When lr_d_valid_in is low, lr_d_data_out == 0.
    // RTL:  else branch assigns lr_d_data_out <= 16'b0 explicitly.
    // ------------------------------------------------------------------
    property p_data_zero_when_invalid;
        @(posedge clk) disable iff (rst)
        !lr_d_valid_in |=> (lr_d_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LRD-A4: Non-negative H passes the gradient through unchanged.
    // RTL:  if (lr_d_H_data_in >= 0) lr_d_data_out <= lr_d_data_in
    //       Sign is determined by lr_d_H_data_in[15] (0 = non-negative).
    // ------------------------------------------------------------------
    property p_positive_H_passes_gradient_through;
        @(posedge clk) disable iff (rst)
        (lr_d_valid_in && !lr_d_H_data_in[15])
        |=> (lr_d_data_out == $past(lr_d_data_in));
    endproperty

    // ------------------------------------------------------------------
    // LRD-A5: Negative H scales the gradient (output differs from raw gradient).
    // RTL:  else lr_d_data_out <= mul_out = lr_d_data_in * lr_leak_factor_in.
    //       Asserts output != raw input (valid when leak_factor != 1.0).
    // ------------------------------------------------------------------
    property p_negative_H_scales_gradient;
        @(posedge clk) disable iff (rst)
        (lr_d_valid_in && lr_d_H_data_in[15] && lr_leak_factor_in != 16'h0100)
        |=> (lr_d_data_out != $past(lr_d_data_in));
    endproperty

    // ------------------------------------------------------------------
    // LRD-A6: Zero H (exactly 0x0000) is non-negative → gradient passes through.
    // ------------------------------------------------------------------
    property p_zero_H_passes_gradient_through;
        @(posedge clk) disable iff (rst)
        (lr_d_valid_in && lr_d_H_data_in == 16'b0)
        |=> (lr_d_data_out == $past(lr_d_data_in));
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    LRD_A1: assert property (p_rst_clears_outputs)               else $error("LRD-A1 FAIL: rst did not clear lr_d outputs");
    LRD_A2: assert property (p_valid_out_mirrors_valid_in)       else $error("LRD-A2 FAIL: lr_d_valid_out != registered(lr_d_valid_in)");
    LRD_A3: assert property (p_data_zero_when_invalid)           else $error("LRD-A3 FAIL: lr_d_data_out != 0 when lr_d_valid_in=0");
    LRD_A4: assert property (p_positive_H_passes_gradient_through) else $error("LRD-A4 FAIL: positive H did not pass gradient through");
    LRD_A5: assert property (p_negative_H_scales_gradient)       else $error("LRD-A5 FAIL: negative H did not scale gradient");
    LRD_A6: assert property (p_zero_H_passes_gradient_through)   else $error("LRD-A6 FAIL: zero H did not pass gradient through");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    LRD_C1: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in && !lr_d_H_data_in[15] && lr_d_H_data_in != 0); // H > 0: passthrough
    LRD_C2: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in &&  lr_d_H_data_in[15]);                        // H < 0: scaled
    LRD_C3: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in &&  lr_d_H_data_in == 0);                       // H = 0 boundary
    LRD_C4: cover property (@(posedge clk) disable iff (rst) $fell(lr_d_valid_in));                                        // valid deasserted

endmodule
