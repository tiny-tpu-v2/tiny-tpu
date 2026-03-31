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

    // DUT outputs — must be 'input' direction to avoid multiple-driver in bind context
    input logic               lr_d_valid_out,
    input logic signed [15:0] lr_d_data_out,
    input logic               lr_d_overflow_out
);

    // ------------------------------------------------------------------
    // LRD-A1: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_outputs;
        @(posedge clk) rst |=> (!lr_d_valid_out && lr_d_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LRD-A2: lr_d_valid_out is the registered version of lr_d_valid_in.
    // ------------------------------------------------------------------
    property p_valid_out_mirrors_valid_in;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (lr_d_valid_out == $past(lr_d_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // LRD-A3: When lr_d_valid_in is low, lr_d_data_out == 0.
    // ------------------------------------------------------------------
    property p_data_zero_when_invalid;
        @(posedge clk) disable iff (rst)
        !lr_d_valid_in |=> (lr_d_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LRD-A4: Non-negative H passes the gradient through unchanged.
    // ------------------------------------------------------------------
    property p_positive_H_passes_gradient_through;
        @(posedge clk) disable iff (rst)
        (lr_d_valid_in && !lr_d_H_data_in[15])
        |=> (lr_d_data_out == $past(lr_d_data_in));
    endproperty

    // ------------------------------------------------------------------
    // LRD-A5: Negative H scales the gradient (output differs from raw gradient).
    //         Valid when lr_leak_factor_in != 1.0.
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
    // LRD-A7: Overflow flag is cleared on reset.
    // ------------------------------------------------------------------
    property p_rst_clears_overflow;
        @(posedge clk) rst |=> !lr_d_overflow_out;
    endproperty

    // ------------------------------------------------------------------
    // LRD-A8: Overflow flag is sticky — once set, stays set until rst.
    // ------------------------------------------------------------------
    property p_overflow_is_sticky;
        @(posedge clk) disable iff (rst)
        lr_d_overflow_out |=> lr_d_overflow_out;
    endproperty

    LRD_A7: assert property (p_rst_clears_overflow)  else $error("LRD-A7 FAIL: rst did not clear lr_d_overflow_out");
    LRD_A8: assert property (p_overflow_is_sticky)    else $error("LRD-A8 FAIL: lr_d_overflow_out dropped without rst");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    LRD_C1: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in && !lr_d_H_data_in[15] && lr_d_H_data_in != 0); // H > 0: passthrough
    // LRD_C2 (formal-only): lr_d_valid_in never fires during pathway=0001 because col_size=1 keeps
    // sys_start_2=0 → sys_valid_out_21=vpu_valid_in_1=0 → lr_d_valid_1_in=0 in the backward pass.
    // LRD_C2: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in &&  lr_d_H_data_in[15]);                        // H < 0: scaled
    // LRD_C3 (formal-only): exact lr_d_H_data_in==0 never occurs in Q8.8 simulation with XOR training data.
    // LRD_C3: cover property (@(posedge clk) disable iff (rst) lr_d_valid_in &&  lr_d_H_data_in == 0);                       // H = 0 boundary
    LRD_C4: cover property (@(posedge clk) disable iff (rst) $fell(lr_d_valid_in));                                        // valid deasserted

endmodule
