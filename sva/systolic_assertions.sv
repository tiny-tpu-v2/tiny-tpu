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
    input logic        sys_start_1,
    input logic        sys_start_2,   // independent start for row-2 PEs (pe21)

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
    input logic        ub_rd_col_size_valid_in,

    // Internal signal (connected via bind)
    input logic [1:0]  pe_enabled
);

    // Alias for readability
    wire [1:0] _pe_enabled = pe_enabled;

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
    // S-A5: sys_valid_out_21 appears exactly 1 clock cycle after
    //       sys_start_2 is asserted.
    // ------------------------------------------------------------------
    property p_valid_21_one_cycle_delay;
        @(posedge clk) disable iff (rst)
        sys_start_2 |=> sys_valid_out_21;
    endproperty

    // ------------------------------------------------------------------
    // S-A6: sys_valid_out_22 appears exactly 3 clock cycles after
    //       sys_start_1 is asserted.
    // ------------------------------------------------------------------
    property p_valid_22_three_cycles_after_start1;
        @(posedge clk) disable iff (rst || !_pe_enabled[1])
        sys_start_1 |=> ##2 sys_valid_out_22;
    endproperty

    // ------------------------------------------------------------------
    // S-A7: When sys_start_2 deasserts, sys_valid_out_21 deasserts within
    //       1 cycle (the pipeline drains in 1 stage for row-2 path).
    // ------------------------------------------------------------------
    property p_valid_21_deasserts_after_start2;
        @(posedge clk) disable iff (rst)
        ($fell(sys_start_2) && !$past(rst)) |=> ##[0:1] $fell(sys_valid_out_21);
    endproperty

    // ------------------------------------------------------------------
    // S-A8: With col_size == 1, only column 1 PE rows are enabled.
    //       sys_valid_out_22 must be 0 because pe22 is disabled.
    // ------------------------------------------------------------------
    property p_col_size_1_disables_col2_valid;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd1)
        |=> ##1 !sys_valid_out_22;
    endproperty

    // ------------------------------------------------------------------
    // S-A9: With col_size == 2, both columns can produce valid output —
    //       after sys_start_1 and sys_start_2, both outputs eventually fire.
    //       (coverage/liveness property; range allows for pipeline fill time)
    // ------------------------------------------------------------------
    property p_col_size_2_both_outputs_reachable;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd2 && sys_start_1 && sys_start_2)
        |=> ##[1:6] (sys_valid_out_21 && sys_valid_out_22);
    endproperty

    // ------------------------------------------------------------------
    // S-A10: pe_enabled resets to 2'b11 (all columns enabled by default).
    // ------------------------------------------------------------------
    property p_rst_sets_pe_enabled_default;
        @(posedge clk) rst |=> (_pe_enabled == 2'b11);
    endproperty

    // ------------------------------------------------------------------
    // S-A11 / S-A12: pe_enabled bit-mask encoding.
    //   col_size=1 → pe_enabled = 2'b01  (only column 1 PEs active)
    //   col_size=2 → pe_enabled = 2'b11  (both columns active)
    // ------------------------------------------------------------------
    property p_pe_enabled_mask_col_size_1;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd1)
        |=> (_pe_enabled == 2'b01);
    endproperty

    property p_pe_enabled_mask_col_size_2;
        @(posedge clk) disable iff (rst)
        (ub_rd_col_size_valid_in && ub_rd_col_size_in == 16'd2)
        |=> (_pe_enabled == 2'b11);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    S_A1:  assert property (p_rst_clears_valid_out_21)              else $error("S-A1  FAIL: rst did not clear sys_valid_out_21");
    S_A2:  assert property (p_rst_clears_valid_out_22)              else $error("S-A2  FAIL: rst did not clear sys_valid_out_22");
    S_A3:  assert property (p_rst_clears_data_out_21)               else $error("S-A3  FAIL: rst did not clear sys_data_out_21");
    S_A4:  assert property (p_rst_clears_data_out_22)               else $error("S-A4  FAIL: rst did not clear sys_data_out_22");
    S_A5:  assert property (p_valid_21_one_cycle_delay)             else $error("S-A5  FAIL: sys_valid_out_21 did not appear 1 cycle after sys_start_2");
    S_A6:  assert property (p_valid_22_three_cycles_after_start1)   else $error("S-A6  FAIL: sys_valid_out_22 did not appear 3 cycles after sys_start_1");
    S_A7:  assert property (p_valid_21_deasserts_after_start2)      else $error("S-A7  FAIL: sys_valid_out_21 did not deassert after sys_start_2 fell");
    S_A8:  assert property (p_col_size_1_disables_col2_valid)       else $error("S-A8  FAIL: col_size=1 but sys_valid_out_22 was asserted");
    S_A9:  assert property (p_col_size_2_both_outputs_reachable)    else $error("S-A9  FAIL: both outputs did not become valid with col_size=2");
    S_A10: assert property (p_rst_sets_pe_enabled_default)          else $error("S-A10 FAIL: rst did not set pe_enabled to 2'b11");
    S_A11: assert property (p_pe_enabled_mask_col_size_1)           else $error("S-A11 FAIL: pe_enabled != 2'b01 after col_size=1");
    S_A12: assert property (p_pe_enabled_mask_col_size_2)           else $error("S-A12 FAIL: pe_enabled != 2'b11 after col_size=2");

    // ------------------------------------------------------------------
    // S-A13: Column weight-load independence.
    //        When only col1 is being loaded (sys_accept_w_1=1, sys_accept_w_2=0)
    //        and neither start signal is asserted, col2 valid output must stay low.
    // ------------------------------------------------------------------
    property p_col1_weight_load_no_col2_valid;
        @(posedge clk) disable iff (rst)
        (sys_accept_w_1 && !sys_accept_w_2 && !sys_start_1 && !sys_start_2)
        |=> !sys_valid_out_22;
    endproperty

    S_A13: assert property (p_col1_weight_load_no_col2_valid) else $error("S-A13 FAIL: col1 weight load spuriously triggered sys_valid_out_22");

    // ------------------------------------------------------------------
    // Assumptions (formal constraints) — Verification Plan Section 8
    // ------------------------------------------------------------------
    // SYS-ASM-01: ub_rd_col_size_in must be 1 or 2 when valid.
    //             Values outside {1,2} are undefined behaviour for a
    //             2-wide array; constraining the formal engine's search space.
    SYS_ASM_01: assume property (@(posedge clk) disable iff (rst)
        ub_rd_col_size_valid_in
        |-> (ub_rd_col_size_in == 16'd1 || ub_rd_col_size_in == 16'd2));

    // SYS-ASM-02: sys_start_1 and sys_start_2 must each be deasserted for at
    //             least 1 clock cycle between consecutive batches to prevent
    //             overlapping valid chains.
    SYS_ASM_02: assume property (@(posedge clk) disable iff (rst)
        $fell(sys_start_1) |=> !sys_start_1);
    SYS_ASM_02b: assume property (@(posedge clk) disable iff (rst)
        $fell(sys_start_2) |=> !sys_start_2);

    // SYS-ASM-03 (formal-only): weight accept signals are never both asserted together.
    // SYS_ASM_03: assume property (@(posedge clk) disable iff (rst)
    //     !(sys_accept_w_1 && sys_accept_w_2));

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    S_C1: cover property (@(posedge clk) sys_valid_out_21 && sys_valid_out_22);              // both columns active
    // S_C2 (formal-only): sys_switch_in is de-asserted ~3 cycles before sys_valid_out_21
    // first fires (TB sets switch=1 for one cycle, then UB+PE pipeline produces valid
    // output after an extra 3-cycle delay). The two signals never overlap in simulation.
    // S_C2: cover property (@(posedge clk) sys_switch_in && sys_valid_out_21);                 // switch during computation
    S_C3: cover property (@(posedge clk) (ub_rd_col_size_valid_in && ub_rd_col_size_in == 1)); // col_size used
    S_C4: cover property (@(posedge clk) sys_accept_w_1 && !sys_accept_w_2);                // column 1 weight load only
    S_C5: cover property (@(posedge clk) !sys_accept_w_1 && sys_accept_w_2);                // column 2 weight load only
    S_C6: cover property (@(posedge clk) sys_start_1 && sys_start_2);                       // both rows started together
    S_C7: cover property (@(posedge clk) sys_start_1 && !sys_start_2);                      // row-1 only start (col-2 computation)

endmodule
