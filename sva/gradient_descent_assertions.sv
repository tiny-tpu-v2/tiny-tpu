// ============================================================
// gradient_descent_assertions.sv
// SVA bind module for gradient_descent.sv
//
// Bind with:
//   bind gradient_descent gradient_descent_assertions u_gd_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module gradient_descent_assertions (
    input logic clk,
    input logic rst,

    input logic [15:0] lr_in,
    input logic [15:0] value_old_in,
    input logic [15:0] grad_in,
    input logic        grad_descent_valid_in,
    input logic        grad_bias_or_weight,

    output logic [15:0] value_updated_out,
    output logic        grad_descent_done_out
);

    // ------------------------------------------------------------------
    // GD-A1 / GD-A2: Reset clears both outputs
    // ------------------------------------------------------------------
    property p_rst_clears_output;
        @(posedge clk) rst |=> (value_updated_out == 16'b0);
    endproperty

    property p_rst_clears_done;
        @(posedge clk) rst |=> !grad_descent_done_out;
    endproperty

    // ------------------------------------------------------------------
    // GD-A3: grad_descent_done_out is the registered version of
    //        grad_descent_valid_in (plain 1-cycle delay, no gating).
    // RTL:  grad_descent_done_out <= grad_descent_valid_in  (unconditional)
    // ------------------------------------------------------------------
    property p_done_one_cycle_delay;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (grad_descent_done_out == $past(grad_descent_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // GD-A4: When grad_descent_valid_in is low, value_updated_out == 0.
    // RTL:  else branch assigns value_updated_out <= '0 explicitly.
    // ------------------------------------------------------------------
    property p_output_zero_when_not_valid;
        @(posedge clk) disable iff (rst)
        !grad_descent_valid_in |=> (value_updated_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // GD-A5: done implies valid was set last cycle.
    // (inverse implication from A3)
    // ------------------------------------------------------------------
    property p_done_implies_valid_was_set;
        @(posedge clk) disable iff (rst)
        grad_descent_done_out |-> $past(grad_descent_valid_in);
    endproperty

    // ------------------------------------------------------------------
    // GD-A6: not done implies valid was NOT set last cycle.
    // ------------------------------------------------------------------
    property p_not_done_implies_valid_was_clear;
        @(posedge clk) disable iff (rst)
        !grad_descent_done_out |-> !$past(grad_descent_valid_in);
    endproperty

    // ------------------------------------------------------------------
    // GD-A7: In weight mode (grad_bias_or_weight=1), the update formula
    //        is: value_updated = value_old - (grad * lr).
    //        We assert that value_updated_out is non-zero when all three
    //        inputs are non-zero (basic liveness — the subtractor is active).
    //        Exact numerical equality requires the fxp reference model.
    // ------------------------------------------------------------------
    property p_weight_mode_produces_output_when_valid;
        @(posedge clk) disable iff (rst)
        (grad_descent_valid_in && grad_bias_or_weight
         && value_old_in != 16'b0 && grad_in != 16'b0 && lr_in != 16'b0)
        |=> (value_updated_out != 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // GD-A8: In weight mode, output is always less than value_old when
    //        gradient and learning rate are positive (gradient descent
    //        decreases the weight).
    // ------------------------------------------------------------------
    property p_weight_mode_descent_direction;
        @(posedge clk) disable iff (rst)
        (grad_descent_valid_in && grad_bias_or_weight
         && !grad_in[15] && !lr_in[15])   // both positive
        |=> ($signed(value_updated_out) < $signed($past(value_old_in)));
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    GD_A1: assert property (p_rst_clears_output)                       else $error("GD-A1 FAIL: rst did not clear value_updated_out");
    GD_A2: assert property (p_rst_clears_done)                         else $error("GD-A2 FAIL: rst did not clear grad_descent_done_out");
    GD_A3: assert property (p_done_one_cycle_delay)                    else $error("GD-A3 FAIL: grad_descent_done_out != registered(valid_in)");
    GD_A4: assert property (p_output_zero_when_not_valid)              else $error("GD-A4 FAIL: value_updated_out != 0 when valid_in=0");
    GD_A5: assert property (p_done_implies_valid_was_set)              else $error("GD-A5 FAIL: done=1 but valid_in was 0 last cycle");
    GD_A6: assert property (p_not_done_implies_valid_was_clear)        else $error("GD-A6 FAIL: done=0 but valid_in was 1 last cycle");
    GD_A7: assert property (p_weight_mode_produces_output_when_valid)  else $error("GD-A7 FAIL: weight mode output is 0 with non-zero inputs");
    GD_A8: assert property (p_weight_mode_descent_direction)           else $error("GD-A8 FAIL: weight update did not decrease the weight (wrong direction)");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    GD_C1: cover property (@(posedge clk) disable iff (rst) grad_descent_valid_in &&  grad_bias_or_weight);  // weight mode
    GD_C2: cover property (@(posedge clk) disable iff (rst) grad_descent_valid_in && !grad_bias_or_weight);  // bias mode
    GD_C3: cover property (@(posedge clk) disable iff (rst) // bias mode accumulation (done cascades into next cycle)
                           !grad_bias_or_weight && grad_descent_done_out && grad_descent_valid_in);

endmodule
