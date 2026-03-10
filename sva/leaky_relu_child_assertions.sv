// ============================================================
// leaky_relu_child_assertions.sv
// SVA bind module for leaky_relu_child.sv
//
// Bind with:
//   bind leaky_relu_child leaky_relu_child_assertions u_lr_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module leaky_relu_child_assertions (
    input logic clk,
    input logic rst,

    input logic               lr_valid_in,
    input logic signed [15:0] lr_data_in,
    input logic signed [15:0] lr_leak_factor_in,

    output logic signed [15:0] lr_data_out,
    output logic               lr_valid_out
);

    // ------------------------------------------------------------------
    // LR-A1: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_outputs;
        @(posedge clk) rst |=> (!lr_valid_out && lr_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LR-A2: lr_valid_out is the registered version of lr_valid_in.
    // RTL:  if (lr_valid_in) valid_out <= 1 ; else valid_out <= 0
    // ------------------------------------------------------------------
    property p_valid_out_mirrors_valid_in;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (lr_valid_out == $past(lr_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // LR-A3: When lr_valid_in is low, lr_data_out == 0.
    // RTL:  else branch assigns lr_data_out <= 16'b0 explicitly.
    // ------------------------------------------------------------------
    property p_data_zero_when_invalid;
        @(posedge clk) disable iff (rst)
        !lr_valid_in |=> (lr_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LR-A4: Non-negative inputs pass through unchanged.
    // RTL:  if (lr_data_in >= 0) lr_data_out <= lr_data_in
    //       In Q8.8 signed 16-bit: bit[15]=0 means non-negative.
    // ------------------------------------------------------------------
    property p_positive_input_passes_through;
        @(posedge clk) disable iff (rst)
        (lr_valid_in && !lr_data_in[15]) |=> (lr_data_out == $past(lr_data_in));
    endproperty

    // ------------------------------------------------------------------
    // LR-A5: Negative inputs are scaled (not passed through unchanged).
    // RTL:  else lr_data_out <= mul_out  (mul_out = lr_data_in * lr_leak_factor_in)
    //       Asserts that the output differs from the raw negative input,
    //       which is true as long as lr_leak_factor_in != 1.0 (0x0100).
    // ------------------------------------------------------------------
    property p_negative_input_is_scaled;
        @(posedge clk) disable iff (rst)
        (lr_valid_in && lr_data_in[15] && lr_leak_factor_in != 16'h0100)
        |=> (lr_data_out != $past(lr_data_in));
    endproperty

    // ------------------------------------------------------------------
    // LR-A6: Output sign matches input sign for non-negative inputs.
    //        Positive input → positive output.
    // ------------------------------------------------------------------
    property p_nonneg_output_for_nonneg_input;
        @(posedge clk) disable iff (rst)
        (lr_valid_in && !lr_data_in[15]) |=> !lr_data_out[15];
    endproperty

    // ------------------------------------------------------------------
    // LR-A7: Zero input produces zero output (0 is a fixed point of ReLU).
    // ------------------------------------------------------------------
    property p_zero_input_zero_output;
        @(posedge clk) disable iff (rst)
        (lr_valid_in && lr_data_in == 16'b0) |=> (lr_data_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    LR_A1: assert property (p_rst_clears_outputs)            else $error("LR-A1 FAIL: rst did not clear lr_relu outputs");
    LR_A2: assert property (p_valid_out_mirrors_valid_in)    else $error("LR-A2 FAIL: lr_valid_out != registered(lr_valid_in)");
    LR_A3: assert property (p_data_zero_when_invalid)        else $error("LR-A3 FAIL: lr_data_out != 0 when lr_valid_in=0");
    LR_A4: assert property (p_positive_input_passes_through) else $error("LR-A4 FAIL: positive input not passed through unchanged");
    LR_A5: assert property (p_negative_input_is_scaled)      else $error("LR-A5 FAIL: negative input not scaled (equals raw input)");
    LR_A6: assert property (p_nonneg_output_for_nonneg_input) else $error("LR-A6 FAIL: positive input produced negative output");
    LR_A7: assert property (p_zero_input_zero_output)        else $error("LR-A7 FAIL: zero input did not produce zero output");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    LR_C1: cover property (@(posedge clk) disable iff (rst) lr_valid_in && !lr_data_in[15] && lr_data_in != 0); // positive path
    LR_C2: cover property (@(posedge clk) disable iff (rst) lr_valid_in &&  lr_data_in[15]);                    // negative path (scaled)
    LR_C3: cover property (@(posedge clk) disable iff (rst) lr_valid_in && lr_data_in == 0);                    // zero boundary
    LR_C4: cover property (@(posedge clk) disable iff (rst) $fell(lr_valid_in));                                // valid deasserted

endmodule
