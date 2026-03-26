// ============================================================
// control_unit_assertions.sv
// SVA bind module for control_unit.sv
//
// control_unit is PURELY COMBINATIONAL — all outputs are
// continuous assign statements.  All assertions below are
// concurrent properties clocked at $global_clock but checking
// the same-cycle combinational relationship.
//
// BUG-CU-1 fix update: instruction word is now 130 bits [129:0],
// port widths widened, and ub_ptr_sel renamed to ub_ptr_select.
// Old encoding (88 bits) has been replaced in full.
//
// Bind with:
//   bind control_unit control_unit_assertions u_cu_assert (.*);
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module control_unit_assertions (
    // NOTE: control_unit has no clock port (purely combinational RTL).
    // clk is declared here so that the cover properties compile correctly.
    // When using:
    //   bind control_unit control_unit_assertions u_cu_assert (.*);
    // the formal tool must be told to drive clk from the primary clock via
    // its TCL configuration (e.g. JasperGold: clock create clk -period 10).
    // For simulation, instantiate control_unit_assertions manually with the
    // testbench clock connected to this port.
    input logic         clk,

    input logic [129:0] instruction,   // BUG-CU-1 fix: widened from 88→130 bits

    // decoded outputs — widths match RTL after BUG-CU-1 fix
    input logic         sys_switch_in,
    input logic         ub_rd_start_in,
    input logic         ub_rd_transpose,
    input logic         ub_wr_host_valid_in_1,
    input logic         ub_wr_host_valid_in_2,
    input logic [15:0]  ub_rd_col_size,              // was [1:0];  now [15:0]
    input logic [15:0]  ub_rd_row_size,              // was [7:0];  now [15:0]
    input logic [15:0]  ub_rd_addr_in,               // was [1:0];  now [15:0]
    input logic [8:0]   ub_ptr_select,               // was ub_ptr_sel [2:0]; renamed + widened [8:0]
    input logic [15:0]  ub_wr_host_data_in_1,
    input logic [15:0]  ub_wr_host_data_in_2,
    input logic [3:0]   vpu_data_pathway,
    input logic [15:0]  inv_batch_size_times_two_in,
    input logic [15:0]  vpu_leak_factor_in
);

    // ------------------------------------------------------------------
    // CU-A1 to CU-A14: Each decoded output exactly equals the
    //                   corresponding instruction slice.
    // Pure combinational — checked at every $global_clock edge.
    //
    // Bit assignments match control_unit.sv after BUG-CU-1 fix:
    //   [0]       sys_switch_in
    //   [1]       ub_rd_start_in
    //   [2]       ub_rd_transpose
    //   [3]       ub_wr_host_valid_in_1
    //   [4]       ub_wr_host_valid_in_2
    //   [20:5]    ub_rd_col_size   [15:0]
    //   [36:21]   ub_rd_row_size   [15:0]
    //   [52:37]   ub_rd_addr_in    [15:0]
    //   [61:53]   ub_ptr_select    [8:0]
    //   [77:62]   ub_wr_host_data_in_1 [15:0]
    //   [93:78]   ub_wr_host_data_in_2 [15:0]
    //   [97:94]   vpu_data_pathway [3:0]
    //   [113:98]  inv_batch_size_times_two_in [15:0]
    //   [129:114] vpu_leak_factor_in  [15:0]
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // Immediate assertions — checked continuously for combinational logic
    // ------------------------------------------------------------------
    always_comb begin
        CU_A1:  assert (sys_switch_in                === instruction[0])       else $error("CU-A1  FAIL: sys_switch_in != instruction[0]");
        CU_A2:  assert (ub_rd_start_in               === instruction[1])       else $error("CU-A2  FAIL: ub_rd_start_in != instruction[1]");
        CU_A3:  assert (ub_rd_transpose               === instruction[2])       else $error("CU-A3  FAIL: ub_rd_transpose != instruction[2]");
        CU_A4:  assert (ub_wr_host_valid_in_1         === instruction[3])       else $error("CU-A4  FAIL: ub_wr_host_valid_in_1 != instruction[3]");
        CU_A5:  assert (ub_wr_host_valid_in_2         === instruction[4])       else $error("CU-A5  FAIL: ub_wr_host_valid_in_2 != instruction[4]");
        CU_A6:  assert (ub_rd_col_size                === instruction[20:5])    else $error("CU-A6  FAIL: ub_rd_col_size != instruction[20:5]");
        CU_A7:  assert (ub_rd_row_size                === instruction[36:21])   else $error("CU-A7  FAIL: ub_rd_row_size != instruction[36:21]");
        CU_A8:  assert (ub_rd_addr_in                 === instruction[52:37])   else $error("CU-A8  FAIL: ub_rd_addr_in != instruction[52:37]");
        CU_A9:  assert (ub_ptr_select                 === instruction[61:53])   else $error("CU-A9  FAIL: ub_ptr_select != instruction[61:53]");
        CU_A10: assert (ub_wr_host_data_in_1          === instruction[77:62])   else $error("CU-A10 FAIL: ub_wr_host_data_in_1 != instruction[77:62]");
        CU_A11: assert (ub_wr_host_data_in_2          === instruction[93:78])   else $error("CU-A11 FAIL: ub_wr_host_data_in_2 != instruction[93:78]");
        CU_A12: assert (vpu_data_pathway               === instruction[97:94])   else $error("CU-A12 FAIL: vpu_data_pathway != instruction[97:94]");
        CU_A13: assert (inv_batch_size_times_two_in    === instruction[113:98])  else $error("CU-A13 FAIL: inv_batch_size_times_two_in != instruction[113:98]");
        CU_A14: assert (vpu_leak_factor_in             === instruction[129:114]) else $error("CU-A14 FAIL: vpu_leak_factor_in != instruction[129:114]");
    end

    // ------------------------------------------------------------------
    // CU-A15: All 14 bit-fields exactly tile instruction[129:0] with no
    //         gaps and no overlaps.  Verified by reassembling all named
    //         output ports via concatenation and comparing to instruction.
    //
    //         Concatenation order (MSB→LSB):
    //           [129:114] vpu_leak_factor_in
    //           [113: 98] inv_batch_size_times_two_in
    //           [ 97: 94] vpu_data_pathway
    //           [ 93: 78] ub_wr_host_data_in_2
    //           [ 77: 62] ub_wr_host_data_in_1
    //           [ 61: 53] ub_ptr_select
    //           [ 52: 37] ub_rd_addr_in
    //           [ 36: 21] ub_rd_row_size
    //           [ 20:  5] ub_rd_col_size
    //           [  4]     ub_wr_host_valid_in_2
    //           [  3]     ub_wr_host_valid_in_1
    //           [  2]     ub_rd_transpose
    //           [  1]     ub_rd_start_in
    //           [  0]     sys_switch_in
    // ------------------------------------------------------------------
    always_comb begin
        CU_A15: assert (instruction === {vpu_leak_factor_in,
                                         inv_batch_size_times_two_in,
                                         vpu_data_pathway,
                                         ub_wr_host_data_in_2,
                                         ub_wr_host_data_in_1,
                                         ub_ptr_select,
                                         ub_rd_addr_in,
                                         ub_rd_row_size,
                                         ub_rd_col_size,
                                         ub_wr_host_valid_in_2,
                                         ub_wr_host_valid_in_1,
                                         ub_rd_transpose,
                                         ub_rd_start_in,
                                         sys_switch_in})
            else $error("CU-A15 FAIL: instruction bit-field layout has gap or overlap — reassembled word != instruction");
    end

    // ------------------------------------------------------------------
    // Cover properties — exercise each architecturally meaningful encoding
    // ------------------------------------------------------------------
    CU_C1: cover property (@(posedge clk) vpu_data_pathway == 4'b1100);                     // forward pass instructed
    CU_C2: cover property (@(posedge clk) vpu_data_pathway == 4'b1111);                     // transition pass instructed
    CU_C3: cover property (@(posedge clk) vpu_data_pathway == 4'b0001);                     // backward pass instructed
    CU_C4: cover property (@(posedge clk) ub_rd_start_in  && ub_rd_transpose);              // transposed read issued
    CU_C5: cover property (@(posedge clk) ub_rd_start_in  && !ub_rd_transpose);             // non-transposed read issued
    CU_C6: cover property (@(posedge clk) ub_wr_host_valid_in_1 && ub_wr_host_valid_in_2); // dual-channel host write
    CU_C7: cover property (@(posedge clk) sys_switch_in);                                   // weight switch issued

endmodule
