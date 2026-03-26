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
    // LC-A4: gradient_out cleared to 0 when valid_in=0.
    //        Corrected plan (v1.1): the RTL DOES gate gradient_out on
    //        valid_in — the else-branch sets gradient_out <= '0.
    //        This is a Data Path (DP) assertion, not a VP assertion.
    //        The previous property (p_valid_out_low_when_in_low) only
    //        checked valid_out; this replaces it with the data check.
    // ------------------------------------------------------------------
    property p_data_zero_when_invalid;
        @(posedge clk) disable iff (rst)
        !valid_in |=> (gradient_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // LC-A5: When H_in > Y_in and valid_in=1, gradient is positive
    //        (MSE gradient 2/N*(H-Y) > 0 when H > Y).
    //        In Q8.8 signed: positive means bit[15]=0.
    // ------------------------------------------------------------------
    property p_positive_gradient_when_H_gt_Y;
        @(posedge clk) disable iff (rst)
        (valid_in && $signed(H_in) > $signed(Y_in)
         && inv_batch_size_times_two_in != 16'b0)     // 2/N=0 scales any diff to zero
        |=> !gradient_out[15];
    endproperty

    // ------------------------------------------------------------------
    // LC-A6: When H_in < Y_in and valid_in=1, gradient is negative.
    // ------------------------------------------------------------------
    property p_negative_gradient_when_H_lt_Y;
        @(posedge clk) disable iff (rst)
        (valid_in && $signed(H_in) < $signed(Y_in)
         && inv_batch_size_times_two_in != 16'b0)     // 2/N=0 would give zero gradient
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
    LC_A4: assert property (p_data_zero_when_invalid)        else $error("LC-A4 FAIL: gradient_out != 0 when valid_in=0");
    LC_A5: assert property (p_positive_gradient_when_H_gt_Y)  else $error("LC-A5 FAIL: gradient not positive when H > Y");
    LC_A6: assert property (p_negative_gradient_when_H_lt_Y)  else $error("LC-A6 FAIL: gradient not negative when H < Y");
    LC_A7: assert property (p_zero_gradient_when_H_eq_Y)      else $error("LC-A7 FAIL: gradient not zero when H == Y");

    // ------------------------------------------------------------------
    // LC-A8: Overflow flag is cleared on reset.
    // RTL: if (rst) loss_overflow_out <= '0;
    // ------------------------------------------------------------------
    property p_rst_clears_overflow;
        @(posedge clk) rst |=> !loss_overflow_out;
    endproperty

    // ------------------------------------------------------------------
    // LC-A9: Overflow flag is sticky — once set, stays set until rst.
    // RTL: loss_overflow_out <= loss_overflow_out | sub_overflow | mul_overflow;
    // ------------------------------------------------------------------
    property p_overflow_is_sticky;
        @(posedge clk) disable iff (rst)
        loss_overflow_out |=> loss_overflow_out;
    endproperty

    LC_A8: assert property (p_rst_clears_overflow)  else $error("LC-A8 FAIL: rst did not clear loss_overflow_out");
    LC_A9: assert property (p_overflow_is_sticky)    else $error("LC-A9 FAIL: loss_overflow_out dropped without rst");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    LC_C1: cover property (@(posedge clk) disable iff (rst) valid_in && $signed(H_in) > $signed(Y_in));  // positive gradient exercised
    LC_C2: cover property (@(posedge clk) disable iff (rst) valid_in && $signed(H_in) < $signed(Y_in));  // negative gradient exercised
    LC_C3: cover property (@(posedge clk) disable iff (rst) valid_in && H_in == Y_in);                   // zero gradient boundary
    LC_C4: cover property (@(posedge clk) disable iff (rst) $fell(valid_in));                            // valid deasserted

endmodule
