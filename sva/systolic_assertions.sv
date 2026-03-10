// ============================================================
// systolic_assertions.sv
// SVA bind module for systolic.sv
//
// Bind with:
//   bind systolic systolic_assertions u_sys_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module systolic_assertions #(
    parameter int SYSTOLIC_ARRAY_WIDTH = 2
)(
    input logic clk,
    input logic rst,

    input logic [15:0] sys_data_in_11,
    input logic [15:0] sys_data_in_21,
    input logic        sys_start,

    input logic [15:0] sys_data_out_21,
    input logic [15:0] sys_data_out_22,
    input logic        sys_valid_out_21,
    input logic        sys_valid_out_22,

    input logic [15:0] sys_weight_in_11,
    input logic [15:0] sys_weight_in_12,
    input logic        sys_accept_w_1,
    input logic        sys_accept_w_2,
    input logic        sys_switch_in,

    input logic [15:0] ub_rd_col_size_in,
    input logic        ub_rd_col_size_valid_in
);

    // ------------------------------------------------------------------
    // S-A1 to S-A4: Reset clears all outputs
    // ------------------------------------------------------------------
    property p_rst_clears_valid_out_21;
        @(posedge clk) rst |=> !sys_valid_out_21;
    endproperty

    property p_rst_clears_valid_out_22;
        @(posedge clk) rst |=> !sys_valid_out_22;
    endproperty

    property p_rst_clears_data_out_21;
        @(posedge clk) rst |=> (sys_data_out_21 == 16'b0);
    endproperty

    property p_rst_clears_data_out_22;
        @(posedge clk) rst |=> (sys_data_out_22 == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // S-A5: sys_valid_out_21 appears exactly 2 clock cycles after
    //       sys_start is asserted.
    //
    // Path: sys_start -> pe11 (register, 1 cycle) -> pe_valid_out_11
    //       pe_valid_out_11 -> pe21 (register, 1 cycle) -> sys_valid_out_21
    // Total: 2 cycles.
    // ------------------------------------------------------------------
    property p_valid_21_two_cycle_delay;
        @(posedge clk) disable iff (rst)
        sys_start |=> ##1 sys_valid_out_21;
    endproperty

    // ------------------------------------------------------------------
    // S-A6: sys_valid_out_22 appears exactly 1 cycle after sys_valid_out_21.
    //
    // Path: pe_valid_out_11 -> pe12 (register, 1 cycle) -> pe_valid_out_12
    //       pe_valid_out_12 -> pe22 (register, 1 cycle) -> sys_valid_out_22
    //
    // Since pe_valid_out_11 also drives pe21 (giving sys_valid_out_21),
    // sys_valid_out_22 = registered(pe_valid_out_12)
    //                   = registered(registered(pe_valid_out_11))
    //                   = sys_valid_out_21 delayed by 1 more cycle.
    // ------------------------------------------------------------------
    property p_valid_22_one_cycle_after_21;
        @(posedge clk) disable iff (rst)
        sys_valid_out_21 |=> sys_valid_out_22;
    endproperty

    // ------------------------------------------------------------------
    // S-A7: When sys_start deasserts, sys_valid_out_21 deasserts within
    //       2 cycles (the pipeline drains).
    // ------------------------------------------------------------------
    property p_valid_21_deasserts_after_start;
        @(posedge clk) disable iff (rst)
        $fell(sys_start) |=> ##[0:2] $fell(sys_valid_out_21);
    endproperty

    // ------------------------------------------------------------------
    // S-A8: With col_size == 1, only column 1 PE rows are enabled.
    //       sys_valid_out_22 must stay 0 because pe22 is disabled.
    //
    //       The pe_enabled register is set combinationally then clocked:
    //       pe_enabled <= (1 << ub_rd_col_size_in) - 1
    //       col_size=1 → pe_enabled = 01 → pe_enabled[1] = 0 → pe12, pe22 disabled.
    // ------------------------------------------------------------------
    property p_col_size_1_disables_col2_valid;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd1)
        |=> !sys_valid_out_22;
    endproperty

    // ------------------------------------------------------------------
    // S-A9: With col_size == 2, both columns can produce valid output —
    //       after start, sys_valid_out_22 eventually becomes 1.
    //       (coverage/liveness property)
    // ------------------------------------------------------------------
    property p_col_size_2_both_outputs_reachable;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd2 && sys_start)
        |=> ##[2:6] (sys_valid_out_21 && sys_valid_out_22);
    endproperty

    // ------------------------------------------------------------------
    // S-A10: The two weight accept signals are independent.
    //        Asserting accept_w_1 alone does not require accept_w_2.
    //        This is a cover-point confirming independent loading is tested.
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    S_A1: assert property (p_rst_clears_valid_out_21)       else $error("S-A1 FAIL: rst did not clear sys_valid_out_21");
    S_A2: assert property (p_rst_clears_valid_out_22)       else $error("S-A2 FAIL: rst did not clear sys_valid_out_22");
    S_A3: assert property (p_rst_clears_data_out_21)        else $error("S-A3 FAIL: rst did not clear sys_data_out_21");
    S_A4: assert property (p_rst_clears_data_out_22)        else $error("S-A4 FAIL: rst did not clear sys_data_out_22");
    S_A5: assert property (p_valid_21_two_cycle_delay)      else $error("S-A5 FAIL: sys_valid_out_21 did not appear 2 cycles after sys_start");
    S_A6: assert property (p_valid_22_one_cycle_after_21)   else $error("S-A6 FAIL: sys_valid_out_22 did not follow sys_valid_out_21 by 1 cycle");
    S_A7: assert property (p_valid_21_deasserts_after_start)      else $error("S-A7 FAIL: sys_valid_out_21 did not deassert after sys_start fell");
    S_A8: assert property (p_col_size_1_disables_col2_valid)      else $error("S-A8 FAIL: col_size=1 but sys_valid_out_22 was asserted");
    S_A9: assert property (p_col_size_2_both_outputs_reachable)   else $error("S-A9 FAIL: both outputs did not become valid with col_size=2");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    S_C1: cover property (@(posedge clk) sys_valid_out_21 && sys_valid_out_22);              // both columns active
    S_C2: cover property (@(posedge clk) sys_switch_in && sys_valid_out_21);                 // switch during computation
    S_C3: cover property (@(posedge clk) (ub_rd_col_size_valid_in && ub_rd_col_size_in == 1)); // col_size used
    S_C4: cover property (@(posedge clk) sys_accept_w_1 && !sys_accept_w_2);                // column 1 weight load only
    S_C5: cover property (@(posedge clk) !sys_accept_w_1 && sys_accept_w_2);                // column 2 weight load only

endmodule
