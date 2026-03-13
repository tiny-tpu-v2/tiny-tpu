// ============================================================
// loss_child_assertions.sv
// SVA bind module for loss_child.sv
//
// Bind with:
//   bind loss_child loss_child_assertions u_lc_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module loss_child_assertions (
    input logic clk,
    input logic rst,

    input logic signed [15:0] H_in,
    input logic signed [15:0] Y_in,
    input logic               valid_in,
    input logic signed [15:0] inv_batch_size_times_two_in,

    // DUT outputs — must be 'input' direction to avoid multiple-driver in bind context
    input logic signed [15:0] gradient_out,
    input logic               valid_out,
    input logic               loss_overflow_out  // BUG-OVF-1 sticky overflow flag
);

    // ------------------------------------------------------------------
    // LC-A1 / LC-A2: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_gradient;
        @(posedge clk) rst |=> (gradient_out == 16'b0);
    endproperty

    property p_rst_clears_valid;
        @(posedge clk) rst |=> !valid_out;
    endproperty

    // ------------------------------------------------------------------
    // LC-A3: valid_out is the registered version of valid_in.
    // RTL:  valid_out <= valid_in  (unconditional — no gating).
    // ------------------------------------------------------------------
    property p_valid_out_mirrors_valid_in;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (valid_out == $past(valid_in));
    endproperty

    // ------------------------------------------------------------------
    // LC-A4: gradient_out is ALWAYS the registered version of
    //        the combinational result (2/N)*(H - Y).
    // IMPORTANT: this fires even when valid_in=0 — the output is computed
    //            from whatever H_in and Y_in are on that cycle.
    //            Consumers must check valid_out before using gradient_out.
    // This assertion requires the internal wire diff_stage1 and final_gradient.
    // In a bind context, reference them as:
    //   dut.diff_stage1, dut.final_gradient
    // or declare them as local vars in the bind module.
    //
    // Here we assert the observable property: valid_out accurately tracks
    // whether the gradient should be trusted.
    // ------------------------------------------------------------------
    property p_valid_out_low_when_in_low;
        @(posedge clk) disable iff (rst)
        !valid_in |=> !valid_out;
    endproperty

    // ------------------------------------------------------------------
    // LC-A5: When H_in > Y_in and valid_in=1, gradient is positive
    //        (MSE gradient 2/N*(H-Y) > 0 when H > Y).
    //        In Q8.8 signed: positive means bit[15]=0.
    // ------------------------------------------------------------------
    property p_positive_gradient_when_H_gt_Y;
        @(posedge clk) disable iff (rst)
        (valid_in && $signed(H_in) > $signed(Y_in))
        |=> !gradient_out[15];
    endproperty

    // ------------------------------------------------------------------
    // LC-A6: When H_in < Y_in and valid_in=1, gradient is negative.
    // ------------------------------------------------------------------
    property p_negative_gradient_when_H_lt_Y;
        @(posedge clk) disable iff (rst)
        (valid_in && $signed(H_in) < $signed(Y_in))
        |=> gradient_out[15];
    endproperty

    // ------------------------------------------------------------------
    // LC-A7: When H_in == Y_in, gradient should be zero.
    //        (2/N) * 0 = 0
    // ------------------------------------------------------------------
    property p_zero_gradient_when_H_eq_Y;
        @(posedge clk) disable iff (rst)
        (valid_in && H_in == Y_in)
        |=> (gradient_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    LC_A1: assert property (p_rst_clears_gradient)            else $error("LC-A1 FAIL: rst did not clear gradient_out");
    LC_A2: assert property (p_rst_clears_valid)               else $error("LC-A2 FAIL: rst did not clear valid_out");
    LC_A3: assert property (p_valid_out_mirrors_valid_in)     else $error("LC-A3 FAIL: valid_out != registered(valid_in)");
    LC_A4: assert property (p_valid_out_low_when_in_low)      else $error("LC-A4 FAIL: valid_out != 0 when valid_in=0");
    LC_A5: assert property (p_positive_gradient_when_H_gt_Y)  else $error("LC-A5 FAIL: gradient not positive when H > Y");
    LC_A6: assert property (p_negative_gradient_when_H_lt_Y)  else $error("LC-A6 FAIL: gradient not negative when H < Y");
    LC_A7: assert property (p_zero_gradient_when_H_eq_Y)      else $error("LC-A7 FAIL: gradient not zero when H == Y");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    LC_C1: cover property (@(posedge clk) disable iff (rst) valid_in && $signed(H_in) > $signed(Y_in));  // positive gradient exercised
    LC_C2: cover property (@(posedge clk) disable iff (rst) valid_in && $signed(H_in) < $signed(Y_in));  // negative gradient exercised
    LC_C3: cover property (@(posedge clk) disable iff (rst) valid_in && H_in == Y_in);                   // zero gradient boundary
    LC_C4: cover property (@(posedge clk) disable iff (rst) $fell(valid_in));                            // valid deasserted

endmodule
