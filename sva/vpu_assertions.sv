// ============================================================
// vpu_assertions.sv
// SVA bind module for vpu.sv
//
// Bind with:
//   bind vpu vpu_assertions u_vpu_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module vpu_assertions (
    input logic clk,
    input logic rst,

    input logic [3:0]          vpu_data_pathway,

    input logic signed [15:0]  vpu_data_in_1,
    input logic signed [15:0]  vpu_data_in_2,
    input logic                vpu_valid_in_1,
    input logic                vpu_valid_in_2,

    input logic signed [15:0]  bias_scalar_in_1,
    input logic signed [15:0]  bias_scalar_in_2,
    input logic signed [15:0]  lr_leak_factor_in,
    input logic signed [15:0]  Y_in_1,
    input logic signed [15:0]  Y_in_2,
    input logic signed [15:0]  inv_batch_size_times_two_in,
    input logic signed [15:0]  H_in_1,
    input logic signed [15:0]  H_in_2,

    // DUT outputs — must be 'input' direction to avoid multiple-driver in bind context
    input logic signed [15:0] vpu_data_out_1,
    input logic signed [15:0] vpu_data_out_2,
    input logic               vpu_valid_out_1,
    input logic               vpu_valid_out_2,

    // Internal signals (connected via bind)
    input logic signed [15:0] last_H_data_1_out,
    input logic signed [15:0] last_H_data_2_out
);

    // Aliases for readability
    wire signed [15:0] _last_H_data_1_out = last_H_data_1_out;
    wire signed [15:0] _last_H_data_2_out = last_H_data_2_out;

    // ------------------------------------------------------------------
    // VPU-A1 / VPU-A2: Reset clears all outputs
    // ------------------------------------------------------------------
    property p_rst_clears_valid_out;
        @(posedge clk) rst |=> (!vpu_valid_out_1 && !vpu_valid_out_2);
    endproperty

    property p_rst_clears_data_out;
        @(posedge clk) rst |=> (vpu_data_out_1 == 16'b0 && vpu_data_out_2 == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // VPU-A3 / VPU-A4: Zero pathway — passthrough with 1-cycle registered delay.
    // ------------------------------------------------------------------
    property p_zero_pathway_valid_passthrough;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000)
        |=> (vpu_valid_out_1 == $past(vpu_valid_in_1) && vpu_valid_out_2 == $past(vpu_valid_in_2));
    endproperty

    property p_zero_pathway_data_passthrough;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000)
        |=> (vpu_data_out_1 == $past(vpu_data_in_1) && vpu_data_out_2 == $past(vpu_data_in_2));
    endproperty

    // ------------------------------------------------------------------
    // VPU-A5: Forward pass pathway (1100 = bias + leaky_relu only).
    //         Pipeline latency = 3 cycles.
    // ------------------------------------------------------------------
    property p_forward_path_two_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b1100 && vpu_valid_in_1)
        |=> ##2 vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A6: Backward pass pathway (0001 = lr_derivative only).
    //         Pipeline latency = 2 cycles.
    // ------------------------------------------------------------------
    property p_backward_path_one_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0001 && vpu_valid_in_1)
        |=> ##1 vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A7: Transition pathway (1111 = all four stages).
    //         Pipeline latency = 5 cycles.
    // ------------------------------------------------------------------
    property p_transition_path_four_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b1111 && vpu_valid_in_1)
        |=> ##4 vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A8: No valid output when pathway=0000 and no valid input.
    // ------------------------------------------------------------------
    property p_no_valid_out_zero_path_no_valid_in;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000 && !vpu_valid_in_1)
        |=> !vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A9: Column symmetry — both channels produce equal valid timing
    //         during steady-state pipeline flow.
    // ------------------------------------------------------------------
    property p_both_columns_valid_together;
        @(posedge clk) disable iff (rst)
        (vpu_valid_in_1 && vpu_valid_in_2 && vpu_data_pathway != 4'b0000) [*3]
        |=> (vpu_valid_out_1 == vpu_valid_out_2);  // steady-state symmetry
    endproperty

    // ------------------------------------------------------------------
    // VPU-A10: Forward pass valid deasserts after input deasserts.
    //          When valid_in drops, valid_out must drop within (latency+1) cycles.
    // ------------------------------------------------------------------
    property p_valid_out_deasserts_after_in_drops_fwd;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b1100 && $fell(vpu_valid_in_1))
        |=> ##[0:3] $fell(vpu_valid_out_1);
    endproperty

    // ------------------------------------------------------------------
    // VPU-A11: Reset clears the last-H cache output registers.
    // ------------------------------------------------------------------
    property p_rst_clears_last_H_cache;
        @(posedge clk) rst
        |=> (_last_H_data_1_out == 16'b0 && _last_H_data_2_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // VPU-A12: When the loss stage is inactive (pathway[1]=0), the
    //          last-H cache outputs are forced to 0 on the next cycle.
    // ------------------------------------------------------------------
    property p_last_H_clears_when_loss_inactive;
        @(posedge clk) disable iff (rst)
        !vpu_data_pathway[1]
        |=> (_last_H_data_1_out == 16'b0 && _last_H_data_2_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // VPU-A13: When the loss stage is active (pathway[1]=1), the
    //          last-H cache captures lr_data_out each cycle.
    //          Guard: positive non-zero input + non-negative bias guarantees
    //          a positive (non-zero) H after leaky_relu.
    // ------------------------------------------------------------------
    property p_last_H_registers_when_loss_active;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway[1] && vpu_valid_in_1
         && !vpu_data_in_1[15] && vpu_data_in_1 != 16'b0  // positive non-zero input
         && !bias_scalar_in_1[15])                          // non-negative bias: sum stays positive
        |=> ##2 _last_H_data_1_out != 16'b0;               // H-cache captures non-zero ReLU output
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    VPU_A1:  assert property (p_rst_clears_valid_out)                  else $error("VPU-A1  FAIL: rst did not clear vpu_valid_out");
    VPU_A2:  assert property (p_rst_clears_data_out)                   else $error("VPU-A2  FAIL: rst did not clear vpu_data_out");
    VPU_A3:  assert property (p_zero_pathway_valid_passthrough)        else $error("VPU-A3  FAIL: zero pathway valid not passed through combinationally");
    VPU_A4:  assert property (p_zero_pathway_data_passthrough)         else $error("VPU-A4  FAIL: zero pathway data not passed through combinationally");
    VPU_A5:  assert property (p_forward_path_two_cycle_latency)        else $error("VPU-A5  FAIL: forward path (1100) valid_out not asserted 3 cycles after valid_in (|=> ##2 = T+3)");
    VPU_A6:  assert property (p_backward_path_one_cycle_latency)       else $error("VPU-A6  FAIL: backward path (0001) valid_out not asserted 2 cycles after valid_in (|=> ##1 = T+2)");
    VPU_A7:  assert property (p_transition_path_four_cycle_latency)    else $error("VPU-A7  FAIL: transition path (1111) latency != 5 cycles");
    VPU_A8:  assert property (p_no_valid_out_zero_path_no_valid_in)    else $error("VPU-A8  FAIL: valid_out asserted with zero pathway and no valid_in");
    VPU_A9:  assert property (p_both_columns_valid_together)           else $error("VPU-A9  FAIL: columns did not produce equal valid timing (plan v1.1: BMC k=4)");
    VPU_A10: assert property (p_valid_out_deasserts_after_in_drops_fwd) else $error("VPU-A10 FAIL: valid_out did not deassert after valid_in fell (fwd path)");
    VPU_A11: assert property (p_rst_clears_last_H_cache)               else $error("VPU-A11 FAIL: rst did not clear last_H cache outputs");
    VPU_A12: assert property (p_last_H_clears_when_loss_inactive)      else $error("VPU-A12 FAIL: last_H did not clear when pathway[1]=0");
    VPU_A13: assert property (p_last_H_registers_when_loss_active)     else $error("VPU-A13 FAIL: last_H not updated when pathway[1]=1 with valid input");

    // ------------------------------------------------------------------
    // Assumptions (formal constraints) — Verification Plan Section 8
    // ------------------------------------------------------------------
    // VPU-ASM-01: vpu_data_pathway is constrained to one of the four
    //             architecturally defined values.
    VPU_ASM_01: assume property (@(posedge clk) disable iff (rst)
        vpu_data_pathway inside {4'b0000, 4'b1100, 4'b1111, 4'b0001});

    // VPU-ASM-02: The pathway register is stable for the duration of a burst.
    VPU_ASM_02: assume property (@(posedge clk) disable iff (rst)
        (vpu_valid_in_1 || vpu_valid_out_1) |=> $stable(vpu_data_pathway));

    // VPU-ASM-03 (formal-only): valid_in held high for pipeline latency proof runs.

    // VPU-ASM-04: Bias scalars are only non-zero when the bias stage is active.
    VPU_ASM_04: assume property (@(posedge clk) disable iff (rst)
        !vpu_data_pathway[3] |-> (bias_scalar_in_1 == 16'b0 && bias_scalar_in_2 == 16'b0));

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    VPU_C1: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b1100 && vpu_valid_out_1); // forward path completes
    VPU_C2: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b1111 && vpu_valid_out_1); // transition path completes
    // VPU_C3 (formal-only): pathway=0001 always uses col_size=1 in this TB (dL/dZ2 is a 4×1 vector).
    // ub_rd_input_valid_out[1]=sys_start_2 never fires for col_size=1 → sys_valid_out_21=vpu_valid_in_1 always 0.
    // VPU_C3: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b0001 && vpu_valid_in_1);  // backward path active
    VPU_C4: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b0000 && vpu_valid_in_1);  // zero pathway passthrough
    VPU_C5: cover property (@(posedge clk) disable iff (rst) vpu_valid_out_1 && vpu_valid_out_2);             // both channels active

endmodule
