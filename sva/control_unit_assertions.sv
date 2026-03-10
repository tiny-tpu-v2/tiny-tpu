// ============================================================
// control_unit_assertions.sv
// SVA bind module for control_unit.sv
//
// control_unit is PURELY COMBINATIONAL — all outputs are
// continuous assign statements.  All assertions below are
// concurrent properties clocked at posedge clk but checking
// the same-cycle combinational relationship.
//
// Bind with:
//   bind control_unit control_unit_assertions u_cu_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module control_unit_assertions (
    input logic [87:0] instruction,

    // decoded outputs
    input logic        sys_switch_in,
    input logic        ub_rd_start_in,
    input logic        ub_rd_transpose,
    input logic        ub_wr_host_valid_in_1,
    input logic        ub_wr_host_valid_in_2,
    input logic [1:0]  ub_rd_col_size,
    input logic [7:0]  ub_rd_row_size,
    input logic [1:0]  ub_rd_addr_in,
    input logic [2:0]  ub_ptr_sel,
    input logic [15:0] ub_wr_host_data_in_1,
    input logic [15:0] ub_wr_host_data_in_2,
    input logic [3:0]  vpu_data_pathway,
    input logic [15:0] inv_batch_size_times_two_in,
    input logic [15:0] vpu_leak_factor_in
);

    // We need a clock for concurrent properties — tie to the parent's clk.
    // Since control_unit has no clock port, the bind context provides it
    // through the parent's port list.  If unavailable, use $bits checks instead.
    // Here we use a free-running internal clock reference.

    // ------------------------------------------------------------------
    // CU-A1 to CU-A14: Each decoded output exactly equals the
    //                   corresponding instruction slice.
    // These are immediate checks that must hold at ALL times
    // (no clock dependency — purely combinational).
    // ------------------------------------------------------------------

    CU_A1:  assert property (@($global_clock) sys_switch_in            === instruction[0])    else $error("CU-A1  FAIL: sys_switch_in != instruction[0]");
    CU_A2:  assert property (@($global_clock) ub_rd_start_in           === instruction[1])    else $error("CU-A2  FAIL: ub_rd_start_in != instruction[1]");
    CU_A3:  assert property (@($global_clock) ub_rd_transpose          === instruction[2])    else $error("CU-A3  FAIL: ub_rd_transpose != instruction[2]");
    CU_A4:  assert property (@($global_clock) ub_wr_host_valid_in_1    === instruction[3])    else $error("CU-A4  FAIL: ub_wr_host_valid_in_1 != instruction[3]");
    CU_A5:  assert property (@($global_clock) ub_wr_host_valid_in_2    === instruction[4])    else $error("CU-A5  FAIL: ub_wr_host_valid_in_2 != instruction[4]");
    CU_A6:  assert property (@($global_clock) ub_rd_col_size            === instruction[6:5]) else $error("CU-A6  FAIL: ub_rd_col_size != instruction[6:5]");
    CU_A7:  assert property (@($global_clock) ub_rd_row_size            === instruction[14:7]) else $error("CU-A7  FAIL: ub_rd_row_size != instruction[14:7]");
    CU_A8:  assert property (@($global_clock) ub_rd_addr_in             === instruction[16:15]) else $error("CU-A8  FAIL: ub_rd_addr_in != instruction[16:15]");
    CU_A9:  assert property (@($global_clock) ub_ptr_sel                === instruction[19:17]) else $error("CU-A9  FAIL: ub_ptr_sel != instruction[19:17]");
    CU_A10: assert property (@($global_clock) ub_wr_host_data_in_1      === instruction[35:20]) else $error("CU-A10 FAIL: ub_wr_host_data_in_1 != instruction[35:20]");
    CU_A11: assert property (@($global_clock) ub_wr_host_data_in_2      === instruction[51:36]) else $error("CU-A11 FAIL: ub_wr_host_data_in_2 != instruction[51:36]");
    CU_A12: assert property (@($global_clock) vpu_data_pathway           === instruction[55:52]) else $error("CU-A12 FAIL: vpu_data_pathway != instruction[55:52]");
    CU_A13: assert property (@($global_clock) inv_batch_size_times_two_in === instruction[71:56]) else $error("CU-A13 FAIL: inv_batch_size_times_two_in != instruction[71:56]");
    CU_A14: assert property (@($global_clock) vpu_leak_factor_in          === instruction[87:72]) else $error("CU-A14 FAIL: vpu_leak_factor_in != instruction[87:72]");

    // ------------------------------------------------------------------
    // Cover properties — ensure all major instruction patterns are exercised
    // ------------------------------------------------------------------
    CU_C1: cover property (@($global_clock) vpu_data_pathway == 4'b1100); // forward pass
    CU_C2: cover property (@($global_clock) vpu_data_pathway == 4'b1111); // transition
    CU_C3: cover property (@($global_clock) vpu_data_pathway == 4'b0001); // backward pass
    CU_C4: cover property (@($global_clock) vpu_data_pathway == 4'b0000); // passthrough
    CU_C5: cover property (@($global_clock) sys_switch_in);
    CU_C6: cover property (@($global_clock) ub_rd_transpose);
    CU_C7: cover property (@($global_clock) ub_rd_start_in && ub_rd_transpose);  // transposed read
    CU_C8: cover property (@($global_clock) ub_ptr_sel == 3'd5);  // gradient descent bias pointer
    CU_C9: cover property (@($global_clock) ub_ptr_sel == 3'd6);  // gradient descent weight pointer

endmodule
