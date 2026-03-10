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

    output logic signed [15:0] vpu_data_out_1,
    output logic signed [15:0] vpu_data_out_2,
    output logic               vpu_valid_out_1,
    output logic               vpu_valid_out_2
);

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
    // VPU-A3 / VPU-A4: Zero pathway = combinational passthrough.
    // RTL: when all 4 pathway bits are 0, every stage is bypassed via the
    //      combinational mux chain, so output equals input immediately
    //      (same-cycle, no register involved).
    // ------------------------------------------------------------------
    property p_zero_pathway_valid_passthrough;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000)
        |-> (vpu_valid_out_1 == vpu_valid_in_1 && vpu_valid_out_2 == vpu_valid_in_2);
    endproperty

    property p_zero_pathway_data_passthrough;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000)
        |-> (vpu_data_out_1 == vpu_data_in_1 && vpu_data_out_2 == vpu_data_in_2);
    endproperty

    // ------------------------------------------------------------------
    // VPU-A5: Forward pass pathway (1100 = bias + leaky_relu only).
    //         Pipeline latency = 2 cycles.
    //         Assertion: valid_in_1 → valid_out_1 arrives 2 cycles later.
    //
    //         Path: vpu_valid_in_1
    //               → bias_child (register, +1 cycle) → bias_valid_1_out
    //               → leaky_relu_child (register, +1 cycle) → lr_valid_1_out
    //               → combinational mux to vpu_valid_out_1
    // ------------------------------------------------------------------
    property p_forward_path_two_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b1100 && vpu_valid_in_1)
        |=> ##1 vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A6: Backward pass pathway (0001 = lr_derivative only).
    //         Pipeline latency = 1 cycle.
    // ------------------------------------------------------------------
    property p_backward_path_one_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0001 && vpu_valid_in_1)
        |=> vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A7: Transition pathway (1111 = all four stages).
    //         Pipeline latency = 4 cycles.
    // ------------------------------------------------------------------
    property p_transition_path_four_cycle_latency;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b1111 && vpu_valid_in_1)
        |=> ##3 vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A8: No valid output when pathway=0000 and no valid input.
    //         Zero pathway is combinational — if input invalid, output invalid.
    // ------------------------------------------------------------------
    property p_no_valid_out_zero_path_no_valid_in;
        @(posedge clk) disable iff (rst)
        (vpu_data_pathway == 4'b0000 && !vpu_valid_in_1)
        |-> !vpu_valid_out_1;
    endproperty

    // ------------------------------------------------------------------
    // VPU-A9: Column symmetry — both channels produce equal valid timing.
    //         When both inputs are driven simultaneously, both outputs
    //         become valid at the same cycle.
    // ------------------------------------------------------------------
    property p_both_columns_valid_together;
        @(posedge clk) disable iff (rst)
        (vpu_valid_in_1 && vpu_valid_in_2 && vpu_data_pathway != 4'b0000)
        |=> (vpu_valid_out_1 == vpu_valid_out_2);  // both fire at same relative offset
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
    // Instantiate assertions
    // ------------------------------------------------------------------
    VPU_A1:  assert property (p_rst_clears_valid_out)                  else $error("VPU-A1  FAIL: rst did not clear vpu_valid_out");
    VPU_A2:  assert property (p_rst_clears_data_out)                   else $error("VPU-A2  FAIL: rst did not clear vpu_data_out");
    VPU_A3:  assert property (p_zero_pathway_valid_passthrough)        else $error("VPU-A3  FAIL: zero pathway valid not passed through combinationally");
    VPU_A4:  assert property (p_zero_pathway_data_passthrough)         else $error("VPU-A4  FAIL: zero pathway data not passed through combinationally");
    VPU_A5:  assert property (p_forward_path_two_cycle_latency)        else $error("VPU-A5  FAIL: forward path (1100) latency != 2 cycles");
    VPU_A6:  assert property (p_backward_path_one_cycle_latency)       else $error("VPU-A6  FAIL: backward path (0001) latency != 1 cycle");
    VPU_A7:  assert property (p_transition_path_four_cycle_latency)    else $error("VPU-A7  FAIL: transition path (1111) latency != 4 cycles");
    VPU_A8:  assert property (p_no_valid_out_zero_path_no_valid_in)    else $error("VPU-A8  FAIL: valid_out asserted with zero pathway and no valid_in");
    VPU_A9:  assert property (p_both_columns_valid_together)           else $error("VPU-A9  FAIL: columns did not become valid at the same cycle");
    VPU_A10: assert property (p_valid_out_deasserts_after_in_drops_fwd) else $error("VPU-A10 FAIL: valid_out did not deassert after valid_in fell (fwd path)");

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    VPU_C1: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b1100 && vpu_valid_out_1); // forward path completes
    VPU_C2: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b1111 && vpu_valid_out_1); // transition path completes
    VPU_C3: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b0001 && vpu_valid_out_1); // backward path completes
    VPU_C4: cover property (@(posedge clk) disable iff (rst) vpu_data_pathway == 4'b0000 && vpu_valid_in_1);  // zero pathway passthrough
    VPU_C5: cover property (@(posedge clk) disable iff (rst) vpu_valid_out_1 && vpu_valid_out_2);             // both channels active

endmodule
