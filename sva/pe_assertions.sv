// ============================================================
// pe_assertions.sv
// SVA bind module for pe.sv
//
// Bind with:
//   bind pe pe_assertions u_pe_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module pe_assertions (
    input logic clk,
    input logic rst,

    input logic signed [15:0] pe_psum_in,
    input logic signed [15:0] pe_weight_in,
    input logic               pe_accept_w_in,
    input logic signed [15:0] pe_input_in,
    input logic               pe_valid_in,
    input logic               pe_switch_in,
    input logic               pe_enabled,

    // DUT outputs — must be 'input' direction in the bind module so the
    // assertions observe (not drive) these registered signals.
    input logic signed [15:0] pe_psum_out,
    input logic signed [15:0] pe_weight_out,
    input logic signed [15:0] pe_input_out,
    input logic               pe_valid_out,
    input logic               pe_switch_out,
    input logic               pe_overflow_out   // BUG-OVF-1 sticky MAC overflow flag
);

    // ------------------------------------------------------------------
    // Internal signal references (accessible because bind is in DUT scope)
    // ------------------------------------------------------------------
    wire signed [15:0] _weight_reg_active   = weight_reg_active;
    wire signed [15:0] _weight_reg_inactive = weight_reg_inactive;

    // ------------------------------------------------------------------
    // PE-A1 to PE-A5: Reset clears all registered outputs
    //
    // BUG-PE-1 fix note: pe_psum_out was previously missing from the reset
    // block.  It is now explicitly cleared in the if (rst || !pe_enabled)
    // branch of pe.sv, so PE_A1 and PE_A6a no longer expose a known bug —
    // they assert the correct post-fix behaviour.
    // ------------------------------------------------------------------
    property p_rst_clears_psum;
        @(posedge clk) rst |=> (pe_psum_out == 16'b0);
    endproperty

    property p_rst_clears_valid;
        @(posedge clk) rst |=> !pe_valid_out;
    endproperty

    property p_rst_clears_switch;
        @(posedge clk) rst |=> !pe_switch_out;
    endproperty

    property p_rst_clears_weight_out;
        @(posedge clk) rst |=> (pe_weight_out == 16'b0);
    endproperty

    property p_rst_clears_input_out;
        @(posedge clk) rst |=> (pe_input_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A6: pe_enabled=0 acts like reset — clears psum and valid
    // RTL: if (rst || !pe_enabled) begin ... identical reset block
    // (BUG-PE-1 fix included pe_psum_out and pe_overflow_out here too)
    // ------------------------------------------------------------------
    property p_disabled_clears_psum;
        @(posedge clk) !pe_enabled |=> (pe_psum_out == 16'b0);
    endproperty

    property p_disabled_clears_valid;
        @(posedge clk) !pe_enabled |=> !pe_valid_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A7: pe_valid_out is the registered version of pe_valid_in.
    // RTL analysis: the always_ff block assigns pe_valid_out <= pe_valid_in
    // first, then the else-branch of the if(pe_valid_in) block overrides
    // pe_valid_out <= 0 when pe_valid_in==0.  Net result: pe_valid_out
    // always equals $past(pe_valid_in) for the cycle after capture.
    // ------------------------------------------------------------------
    property p_valid_out_registered;
        @(posedge clk) disable iff (rst || !pe_enabled)
        1'b1 |=> (pe_valid_out == $past(pe_valid_in));
    endproperty

    // ------------------------------------------------------------------
    // PE-A8: pe_switch_out is the registered version of pe_switch_in.
    // ------------------------------------------------------------------
    property p_switch_out_registered;
        @(posedge clk) disable iff (rst || !pe_enabled)
        1'b1 |=> (pe_switch_out == $past(pe_switch_in));
    endproperty

    // ------------------------------------------------------------------
    // PE-A9: When pe_accept_w_in is high, pe_weight_out equals
    //        the pe_weight_in from the previous cycle.
    // ------------------------------------------------------------------
    property p_weight_out_when_accepting;
        @(posedge clk) disable iff (rst || !pe_enabled)
        pe_accept_w_in |=> (pe_weight_out == $past(pe_weight_in));
    endproperty

    // ------------------------------------------------------------------
    // PE-A10: When pe_accept_w_in is low, pe_weight_out == 0.
    // ------------------------------------------------------------------
    property p_weight_out_zero_when_not_accepting;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_accept_w_in |=> (pe_weight_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A11: When pe_valid_in is high, pe_input_out captures pe_input_in.
    // ------------------------------------------------------------------
    property p_input_out_captured_on_valid;
        @(posedge clk) disable iff (rst || !pe_enabled)
        pe_valid_in |=> (pe_input_out == $past(pe_input_in));
    endproperty

    // ------------------------------------------------------------------
    // PE-A12: When pe_valid_in is low, pe_psum_out == 0.
    // RTL: else branch explicitly assigns pe_psum_out <= 16'b0.
    // ------------------------------------------------------------------
    property p_psum_zero_when_invalid;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_valid_in |=> (pe_psum_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A13: When pe_valid_in is low, pe_valid_out is low.
    // (Derived from A7 but stated explicitly for clarity.)
    // ------------------------------------------------------------------
    property p_valid_out_low_when_in_low;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_valid_in |=> !pe_valid_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A14: Shadow weight registers clear on reset / disabled.
    // RTL: weight_reg_active <= 16'b0 and weight_reg_inactive <= 16'b0
    //      are explicitly in the if (rst || !pe_enabled) block.
    // These internal signals are accessed via the bind-scope wire refs above.
    // ------------------------------------------------------------------
    property p_rst_clears_weight_reg_active;
        @(posedge clk) (rst || !pe_enabled) |=> (_weight_reg_active == 16'b0);
    endproperty

    property p_rst_clears_weight_reg_inactive;
        @(posedge clk) (rst || !pe_enabled) |=> (_weight_reg_inactive == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    PE_A1:   assert property (p_rst_clears_psum)               else $error("PE-A1  FAIL: rst did not clear pe_psum_out");
    PE_A2:   assert property (p_rst_clears_valid)              else $error("PE-A2  FAIL: rst did not clear pe_valid_out");
    PE_A3:   assert property (p_rst_clears_switch)             else $error("PE-A3  FAIL: rst did not clear pe_switch_out");
    PE_A4:   assert property (p_rst_clears_weight_out)         else $error("PE-A4  FAIL: rst did not clear pe_weight_out");
    PE_A5:   assert property (p_rst_clears_input_out)          else $error("PE-A5  FAIL: rst did not clear pe_input_out");
    PE_A6a:  assert property (p_disabled_clears_psum)          else $error("PE-A6a FAIL: pe_enabled=0 did not clear psum");
    PE_A6b:  assert property (p_disabled_clears_valid)         else $error("PE-A6b FAIL: pe_enabled=0 did not clear valid_out");
    PE_A7:   assert property (p_valid_out_registered)          else $error("PE-A7  FAIL: pe_valid_out != registered(pe_valid_in)");
    PE_A8:   assert property (p_switch_out_registered)         else $error("PE-A8  FAIL: pe_switch_out != registered(pe_switch_in)");
    PE_A9:   assert property (p_weight_out_when_accepting)     else $error("PE-A9  FAIL: pe_weight_out != pe_weight_in when accepting");
    PE_A10:  assert property (p_weight_out_zero_when_not_accepting) else $error("PE-A10 FAIL: pe_weight_out != 0 when not accepting");
    PE_A11:  assert property (p_input_out_captured_on_valid)   else $error("PE-A11 FAIL: pe_input_out != pe_input_in when valid");
    PE_A12:  assert property (p_psum_zero_when_invalid)        else $error("PE-A12 FAIL: pe_psum_out != 0 when pe_valid_in=0");
    PE_A13:  assert property (p_valid_out_low_when_in_low)     else $error("PE-A13 FAIL: pe_valid_out != 0 when pe_valid_in=0");
    PE_A14a: assert property (p_rst_clears_weight_reg_active)   else $error("PE-A14a FAIL: rst/disabled did not clear weight_reg_active");
    PE_A14b: assert property (p_rst_clears_weight_reg_inactive) else $error("PE-A14b FAIL: rst/disabled did not clear weight_reg_inactive");

    // ------------------------------------------------------------------
    // Assumptions (formal constraints) — Verification Plan Section 8
    // ------------------------------------------------------------------
    // PE-ASM-01: Once pe_enabled is asserted it stays high until rst.
    //            Prevents mid-computation disable which is illegal in
    //            normal operation (PE enable is configuration, not control).
    PE_ASM_01: assume property (@(posedge clk) disable iff (rst)
        pe_enabled |=> pe_enabled);

    // PE-ASM-02: pe_psum_in is 0 for row-1 PEs (pe11 / pe12 — top cells).
    //            The systolic array ties pe_psum_in = 16'b0 structurally
    //            for the first row; this constraint makes that explicit.
    //            NOTE: Remove this assume when verifying pe21 / pe22
    //                  where a non-zero psum chain is expected.
    PE_ASM_02: assume property (@(posedge clk) pe_psum_in == 16'b0);

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    PE_C1: cover property (@(posedge clk) pe_valid_in && pe_switch_in);          // compute with fresh weight
    PE_C2: cover property (@(posedge clk) pe_accept_w_in ##1 !pe_accept_w_in ##1 pe_switch_in); // load then switch
    PE_C3: cover property (@(posedge clk) pe_valid_in ##1 !pe_enabled);          // disabled mid computation

endmodule
