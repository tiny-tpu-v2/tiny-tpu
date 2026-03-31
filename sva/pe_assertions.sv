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

    // DUT outputs — must be 'input' direction to avoid multiple-driver in bind context
    input logic signed [15:0] pe_psum_out,
    input logic signed [15:0] pe_weight_out,
    input logic signed [15:0] pe_input_out,
    input logic               pe_valid_out,
    input logic               pe_switch_out,
    input logic               pe_overflow_out,

    // Internal signals (connected via bind)
    input logic signed [15:0] weight_reg_active,
    input logic signed [15:0] weight_reg_inactive
);

    // Aliases for readability (match original assertions)
    wire signed [15:0] _weight_reg_active   = weight_reg_active;
    wire signed [15:0] _weight_reg_inactive = weight_reg_inactive;

    // ------------------------------------------------------------------
    // PE-A1 to PE-A5: Reset clears all registered outputs
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
    // ------------------------------------------------------------------
    property p_disabled_clears_psum;
        @(posedge clk) !pe_enabled |=> (pe_psum_out == 16'b0);
    endproperty

    property p_disabled_clears_valid;
        @(posedge clk) !pe_enabled |=> !pe_valid_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A7: pe_valid_out is the registered version of pe_valid_in.
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
    // ------------------------------------------------------------------
    property p_psum_zero_when_invalid;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_valid_in |=> (pe_psum_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A13: When pe_valid_in is low, pe_valid_out is low.
    // ------------------------------------------------------------------
    property p_valid_out_low_when_in_low;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_valid_in |=> !pe_valid_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A14: Shadow weight registers clear on reset / disabled.
    // ------------------------------------------------------------------
    property p_rst_clears_weight_reg_active;
        @(posedge clk) (rst || !pe_enabled) |=> (_weight_reg_active == 16'b0);
    endproperty

    property p_rst_clears_weight_reg_inactive;
        @(posedge clk) (rst || !pe_enabled) |=> (_weight_reg_inactive == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A6c: pe_enabled=0 clears pe_switch_out.
    // ------------------------------------------------------------------
    property p_disabled_clears_switch_out;
        @(posedge clk) !pe_enabled |=> !pe_switch_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A6d: pe_enabled=0 clears pe_weight_out.
    // ------------------------------------------------------------------
    property p_disabled_clears_weight_out;
        @(posedge clk) !pe_enabled |=> (pe_weight_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A19: When pe_valid_in=1 and pe_input_in=0, pe_psum_out == pe_psum_in.
    // ------------------------------------------------------------------
    property p_mac_zero_input_passthrough_psum;
        @(posedge clk) disable iff (rst || !pe_enabled)
        (pe_valid_in && pe_input_in == 16'b0)
        |=> (pe_psum_out == $past(pe_psum_in));
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
    PE_A6c:  assert property (p_disabled_clears_switch_out)    else $error("PE-A6c FAIL: pe_enabled=0 did not clear pe_switch_out");
    PE_A6d:  assert property (p_disabled_clears_weight_out)    else $error("PE-A6d FAIL: pe_enabled=0 did not clear pe_weight_out");
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
    // PE-A15: Weight switch — when pe_switch_in is asserted,
    //         weight_reg_active captures the current weight_reg_inactive.
    // RTL: if (pe_switch_in) weight_reg_active <= weight_reg_inactive;
    // ------------------------------------------------------------------
    property p_weight_switch;
        @(posedge clk) disable iff (rst || !pe_enabled)
        pe_switch_in |=> (_weight_reg_active == $past(_weight_reg_inactive));
    endproperty

    // ------------------------------------------------------------------
    // PE-A16: When pe_valid_in is low, pe_input_out is cleared.
    // RTL: else branch: pe_input_out <= 16'b0
    // ------------------------------------------------------------------
    property p_input_out_clear_when_invalid;
        @(posedge clk) disable iff (rst || !pe_enabled)
        !pe_valid_in |=> (pe_input_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // PE-A17: Overflow flag reset clears sticky flag.
    // RTL: if (rst || !pe_enabled) pe_overflow_out <= 1'b0;
    // ------------------------------------------------------------------
    property p_rst_clears_overflow;
        @(posedge clk) (rst || !pe_enabled) |=> !pe_overflow_out;
    endproperty

    // ------------------------------------------------------------------
    // PE-A18: Overflow flag is sticky — once set, stays set until rst.
    // RTL: pe_overflow_out <= pe_overflow_out | mult_overflow | add_overflow;
    // ------------------------------------------------------------------
    property p_overflow_is_sticky;
        @(posedge clk) disable iff (rst || !pe_enabled)
        pe_overflow_out |=> pe_overflow_out;
    endproperty

    PE_A15:  assert property (p_weight_switch)                  else $error("PE-A15 FAIL: weight_reg_active != $past(weight_reg_inactive) after switch");
    PE_A16:  assert property (p_input_out_clear_when_invalid)   else $error("PE-A16 FAIL: pe_input_out != 0 when pe_valid_in=0");
    PE_A17:  assert property (p_rst_clears_overflow)            else $error("PE-A17 FAIL: rst/disabled did not clear pe_overflow_out");
    PE_A18:  assert property (p_overflow_is_sticky)             else $error("PE-A18 FAIL: pe_overflow_out dropped without rst");
    PE_A19:  assert property (p_mac_zero_input_passthrough_psum) else $error("PE-A19 FAIL: pe_psum_out != pe_psum_in when pe_input_in=0 and pe_valid_in=1");

    // ------------------------------------------------------------------
    // Assumptions (formal constraints) — Verification Plan Section 8
    // ------------------------------------------------------------------
    // PE-ASM-01 (formal-only): once pe_enabled is asserted it stays high until rst.
    // PE_ASM_01: assume property (@(posedge clk) disable iff (rst)
    //     pe_enabled |=> pe_enabled);

    // PE-ASM-02 (formal-only): pe_psum_in is 0 for row-1 PEs (pe11/pe12 — top cells).
    // PE_ASM_02: assume property (@(posedge clk) pe_psum_in == 16'b0);

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    // PE_C1 (formal-only): switch and input valid cannot overlap in simulation.
    // PE_C1: cover property (@(posedge clk) pe_valid_in && pe_switch_in);          // compute with fresh weight

    // PE_C2 (formal-only): accept-to-switch sequence does not occur in simulation.
    // PE_C2: cover property (@(posedge clk) pe_accept_w_in ##1 !pe_accept_w_in ##1 pe_switch_in); // load then switch

    // PE_C3 (formal-only): pe_enabled never deasserts immediately after valid_in in simulation.
    // PE_C3: cover property (@(posedge clk) pe_valid_in ##1 !pe_enabled);          // disabled mid computation

endmodule
