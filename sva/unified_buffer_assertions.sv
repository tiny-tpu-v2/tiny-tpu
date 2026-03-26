// ============================================================
// unified_buffer_assertions.sv
// SVA bind module for unified_buffer.sv
//
// Bind with:
//   bind unified_buffer unified_buffer_assertions #(
//       .UNIFIED_BUFFER_WIDTH(128),
//       .SYSTOLIC_ARRAY_WIDTH(2)
//   ) u_ub_assert (.*);
//
// Internal signals (wr_ptr, rd_*_ptr) are accessed directly
// because a bind module is scoped inside the DUT instance.
// ============================================================
`timescale 1ns/1ps
`default_nettype none

module unified_buffer_assertions #(
    parameter int UNIFIED_BUFFER_WIDTH = 128,
    parameter int SYSTOLIC_ARRAY_WIDTH = 2
)(
    input  logic        clk,
    input  logic        rst,

    // VPU write ports
    input  logic [15:0] ub_wr_data_in   [SYSTOLIC_ARRAY_WIDTH],
    input  logic        ub_wr_valid_in  [SYSTOLIC_ARRAY_WIDTH],

    // Host write ports
    input  logic [15:0] ub_wr_host_data_in  [SYSTOLIC_ARRAY_WIDTH],
    input  logic        ub_wr_host_valid_in [SYSTOLIC_ARRAY_WIDTH],

    // Read instruction inputs
    input  logic        ub_rd_start_in,
    input  logic        ub_rd_transpose,
    input  logic [8:0]  ub_ptr_select,
    input  logic [15:0] ub_rd_addr_in,
    input  logic [15:0] ub_rd_row_size,
    input  logic [15:0] ub_rd_col_size,

    // Learning rate
    input  logic [15:0] learning_rate_in,

    // Read outputs — input data
    input  logic [15:0] ub_rd_input_data_out_0,
    input  logic [15:0] ub_rd_input_data_out_1,
    input  logic        ub_rd_input_valid_out_0,
    input  logic        ub_rd_input_valid_out_1,

    // Read outputs — weight data
    input  logic [15:0] ub_rd_weight_data_out_0,
    input  logic [15:0] ub_rd_weight_data_out_1,
    input  logic        ub_rd_weight_valid_out_0,
    input  logic        ub_rd_weight_valid_out_1,

    // Read outputs — bias, Y, H
    input  logic [15:0] ub_rd_bias_data_out_0,
    input  logic [15:0] ub_rd_bias_data_out_1,
    input  logic [15:0] ub_rd_Y_data_out_0,
    input  logic [15:0] ub_rd_Y_data_out_1,
    input  logic [15:0] ub_rd_H_data_out_0,
    input  logic [15:0] ub_rd_H_data_out_1,

    // Column size output to systolic array
    input  logic [15:0] ub_rd_col_size_out,
    input  logic        ub_rd_col_size_valid_out,

    // Internal signals (connected via bind)
    input  logic [15:0] wr_ptr,
    input  logic [15:0] rd_input_ptr,
    input  logic [15:0] rd_weight_ptr,
    input  logic [15:0] rd_bias_ptr,
    input  logic [15:0] rd_Y_ptr,
    input  logic [15:0] rd_H_ptr,
    input  logic [15:0] rd_grad_bias_ptr,
    input  logic [15:0] rd_grad_weight_ptr,
    input  logic [15:0] grad_descent_ptr
);

    // Aliases for readability
    wire [15:0] _wr_ptr             = wr_ptr;
    wire [15:0] _rd_input_ptr       = rd_input_ptr;
    wire [15:0] _rd_weight_ptr      = rd_weight_ptr;
    wire [15:0] _rd_bias_ptr        = rd_bias_ptr;
    wire [15:0] _rd_Y_ptr           = rd_Y_ptr;
    wire [15:0] _rd_H_ptr           = rd_H_ptr;
    wire [15:0] _rd_grad_bias_ptr   = rd_grad_bias_ptr;
    wire [15:0] _rd_grad_weight_ptr = rd_grad_weight_ptr;
    wire [15:0] _grad_descent_ptr   = grad_descent_ptr;

    // ------------------------------------------------------------------
    // UB-A01: Reset clears the write pointer
    // RTL:  wr_ptr <= '0 in the rst block
    // ------------------------------------------------------------------
    property p_rst_clears_wr_ptr;
        @(posedge clk) rst |=> (_wr_ptr == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // UB-A02: Reset deasserts the column-size valid output register.
    // RTL (BUG-UB-3 fix): ub_rd_col_size_valid_out is now a registered
    //       signal driven in always_ff.  On rst, it is explicitly cleared
    //       to 1'b0.  The |=> (next-cycle) assertion correctly captures
    //       that the register output is 0 one cycle after rst is seen.
    // ------------------------------------------------------------------
    property p_rst_deasserts_col_size_valid;
        @(posedge clk) rst |=> !ub_rd_col_size_valid_out;
    endproperty

    // ------------------------------------------------------------------
    // UB-A03: Reset clears input-data valid output registers
    // RTL:  ub_rd_input_valid_out[i] <= '0 in rst block
    // ------------------------------------------------------------------
    property p_rst_clears_input_valid;
        @(posedge clk) rst
        |=> (!ub_rd_input_valid_out_0 && !ub_rd_input_valid_out_1);
    endproperty

    // ------------------------------------------------------------------
    // UB-A04: Reset clears weight-data valid output registers
    // RTL:  ub_rd_weight_valid_out[i] <= '0 in rst block
    // ------------------------------------------------------------------
    property p_rst_clears_weight_valid;
        @(posedge clk) rst
        |=> (!ub_rd_weight_valid_out_0 && !ub_rd_weight_valid_out_1);
    endproperty

    // ------------------------------------------------------------------
    // UB-A05: Column-size valid is REGISTERED (not combinational).
    //         BUG-UB-3 fix changed these from pure assign to always_ff:
    //           ub_rd_col_size_valid_out <= (ub_rd_start_in && ptr_select==9'd1)
    //
    //         The correct relationship is one cycle delayed:
    //         On the cycle when ub_rd_start_in=1 and ptr_select=1, the
    //         output becomes 1 on the NEXT posedge.
    //
    //         We assert: at every clock, the current valid_out equals what
    //         the condition was last cycle (i.e., $past of the condition).
    // ------------------------------------------------------------------
    property p_col_size_valid_reg_decode;
        @(posedge clk) disable iff (rst)
        1'b1 |=> (ub_rd_col_size_valid_out == ($past(ub_rd_start_in) && ($past(ub_ptr_select) == 9'd1)));
    endproperty

    // ------------------------------------------------------------------
    // UB-A06: Write pointer increments exactly by 1 on each VPU write.
    //         RTL writes both ub_wr_data_in[0] and [1] to wr_ptr and wr_ptr+1
    //         in the same cycle, then increments wr_ptr by 2.
    //         Assert that wr_ptr advances by 2 when both channels write.
    // ------------------------------------------------------------------
    property p_wr_ptr_increments_on_vpu_write;
        @(posedge clk) disable iff (rst)
        (ub_wr_valid_in[0] && ub_wr_valid_in[1])
        |=> (_wr_ptr == $past(_wr_ptr) + 16'd2);
    endproperty

    // ------------------------------------------------------------------
    // UB-A07: Read pointers never exceed the buffer size.
    //         Prevents out-of-bounds memory access.
    // ------------------------------------------------------------------
    property p_rd_input_ptr_in_range;
        @(posedge clk) disable iff (rst)
        _rd_input_ptr < UNIFIED_BUFFER_WIDTH;
    endproperty

    property p_rd_weight_ptr_in_range;
        @(posedge clk) disable iff (rst)
        $signed(_rd_weight_ptr) >= 0 && _rd_weight_ptr < UNIFIED_BUFFER_WIDTH;
    endproperty

    property p_wr_ptr_in_range;
        @(posedge clk) disable iff (rst)
        _wr_ptr < UNIFIED_BUFFER_WIDTH;
    endproperty

    // ------------------------------------------------------------------
    // UB-A08: VPU write does not happen simultaneously with host write
    //         on the same port (protocol mutual-exclusion guarantee).
    //         This is an ASSERT here (verifying the protocol holds); it
    //         is also listed as UB-ASM-02 as an assumption for sub-module
    //         proofs where it is a given.
    // ------------------------------------------------------------------
    property p_no_vpu_host_write_collision_ch0;
        @(posedge clk) disable iff (rst)
        !(ub_wr_valid_in[0] && ub_wr_host_valid_in[0]);
    endproperty

    property p_no_vpu_host_write_collision_ch1;
        @(posedge clk) disable iff (rst)
        !(ub_wr_valid_in[1] && ub_wr_host_valid_in[1]);
    endproperty

    // ------------------------------------------------------------------
    // UB-A09: When col_size_valid_out is asserted, col_size_out must
    //         match the appropriate dimension (transposed or direct read).
    // RTL (BUG-UB-3 fix): BOTH col_size_valid_out AND col_size_out are
    //         registered in always_ff.  They reflect T-1 inputs. Therefore
    //         we must compare col_size_out against $past(inputs) — i.e.,
    //         the values present when the registration happened.
    //
    //   always_ff: ub_rd_col_size_valid_out <= (ub_rd_start_in && ptr==1)
    //              ub_rd_col_size_out       <= cond ? (transpose ? row : col) : 0
    // ------------------------------------------------------------------
    property p_col_size_out_correct_non_transpose;
        @(posedge clk) disable iff (rst || $past(rst))
        (ub_rd_col_size_valid_out && !$past(ub_rd_transpose))
        |-> (ub_rd_col_size_out == $past(ub_rd_col_size));
    endproperty

    property p_col_size_out_correct_transpose;
        @(posedge clk) disable iff (rst || $past(rst))
        (ub_rd_col_size_valid_out && $past(ub_rd_transpose))
        |-> (ub_rd_col_size_out == $past(ub_rd_row_size));
    endproperty

    // ------------------------------------------------------------------
    // UB-A10: col_size_out is zero when col_size_valid_out is deasserted.
    //         Both are registered from the same condition, so when valid=0,
    //         the ternary else-branch produced 16'b0.
    // ------------------------------------------------------------------
    property p_col_size_out_zero_when_not_valid;
        @(posedge clk) disable iff (rst)
        !ub_rd_col_size_valid_out |-> (ub_rd_col_size_out == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // UB-A11 to UB-A16: Reset clears all read and gradient-descent pointers.
    // RTL: every pointer listed below is explicitly set to '0 inside the
    //      if (rst) block in unified_buffer.sv.
    // ------------------------------------------------------------------
    property p_rst_clears_rd_bias_ptr;
        @(posedge clk) rst |=> (_rd_bias_ptr == 16'b0);
    endproperty

    property p_rst_clears_rd_Y_ptr;
        @(posedge clk) rst |=> (_rd_Y_ptr == 16'b0);
    endproperty

    property p_rst_clears_rd_H_ptr;
        @(posedge clk) rst |=> (_rd_H_ptr == 16'b0);
    endproperty

    property p_rst_clears_rd_grad_bias_ptr;
        @(posedge clk) rst |=> (_rd_grad_bias_ptr == 16'b0);
    endproperty

    property p_rst_clears_rd_grad_weight_ptr;
        @(posedge clk) rst |=> (_rd_grad_weight_ptr == 16'b0);
    endproperty

    property p_rst_clears_grad_descent_ptr;
        @(posedge clk) rst |=> (_grad_descent_ptr == 16'b0);
    endproperty

    // ------------------------------------------------------------------
    // Instantiate assertions
    // ------------------------------------------------------------------
    UB_A01: assert property (p_rst_clears_wr_ptr)
        else $error("UB-A01 FAIL: rst did not clear wr_ptr");

    UB_A02: assert property (p_rst_deasserts_col_size_valid)
        else $error("UB-A02 FAIL: rst did not deassert ub_rd_col_size_valid_out");

    UB_A03: assert property (p_rst_clears_input_valid)
        else $error("UB-A03 FAIL: rst did not clear ub_rd_input_valid_out");

    UB_A04: assert property (p_rst_clears_weight_valid)
        else $error("UB-A04 FAIL: rst did not clear ub_rd_weight_valid_out");

    UB_A05: assert property (p_col_size_valid_reg_decode)
        else $error("UB-A05 FAIL: ub_rd_col_size_valid_out registered decode incorrect");

    UB_A06: assert property (p_wr_ptr_increments_on_vpu_write)
        else $error("UB-A06 FAIL: wr_ptr did not increment by 2 on dual VPU write");

    UB_A07a: assert property (p_rd_input_ptr_in_range)
        else $error("UB-A07a FAIL: rd_input_ptr out of range");

    UB_A07b: assert property (p_rd_weight_ptr_in_range)
        else $error("UB-A07b FAIL: rd_weight_ptr out of range");

    UB_A07c: assert property (p_wr_ptr_in_range)
        else $error("UB-A07c FAIL: wr_ptr out of range");

    UB_A08a: assert property (p_no_vpu_host_write_collision_ch0)
        else $error("UB-A08a FAIL: VPU and host write collision on channel 0");

    UB_A08b: assert property (p_no_vpu_host_write_collision_ch1)
        else $error("UB-A08b FAIL: VPU and host write collision on channel 1");

    UB_A09a: assert property (p_col_size_out_correct_non_transpose)
        else $error("UB-A09a FAIL: col_size_out does not match col_size in non-transpose mode");

    UB_A09b: assert property (p_col_size_out_correct_transpose)
        else $error("UB-A09b FAIL: col_size_out does not match row_size in transpose mode");

    UB_A10:  assert property (p_col_size_out_zero_when_not_valid)
        else $error("UB-A10 FAIL: col_size_out non-zero when col_size_valid_out=0");

    // ------------------------------------------------------------------
    // UB-A17: Gradient-descent write-back (plan UB-A09) — ptr advances by
    //         at most SYSTOLIC_ARRAY_WIDTH (2) per cycle.
    //         RTL: for-loop iterates over 2 GD instances; at most 2 done
    //              signals can fire in a single cycle, so ptr += at most 2.
    // ------------------------------------------------------------------
    UB_A17: assert property (
        @(posedge clk) disable iff (rst)
        _grad_descent_ptr <= $past(_grad_descent_ptr) + 16'd2)
        else $error("UB-A17 FAIL: grad_descent_ptr advanced by more than 2 in one cycle");

    // ------------------------------------------------------------------
    // UB-A18: Gradient-descent ptr is monotonically non-decreasing.
    //         Once weights are written back, old addresses are not revisited
    //         within the same run (no decrement without reset).
    // ------------------------------------------------------------------
    UB_A18: assert property (
        @(posedge clk) disable iff (rst)
        _grad_descent_ptr >= $past(_grad_descent_ptr))
        else $error("UB-A18 FAIL: grad_descent_ptr decreased without reset");

    UB_A11: assert property (p_rst_clears_rd_bias_ptr)
        else $error("UB-A11 FAIL: rst did not clear rd_bias_ptr");

    UB_A12: assert property (p_rst_clears_rd_Y_ptr)
        else $error("UB-A12 FAIL: rst did not clear rd_Y_ptr");

    UB_A13: assert property (p_rst_clears_rd_H_ptr)
        else $error("UB-A13 FAIL: rst did not clear rd_H_ptr");

    UB_A14: assert property (p_rst_clears_rd_grad_bias_ptr)
        else $error("UB-A14 FAIL: rst did not clear rd_grad_bias_ptr");

    UB_A15: assert property (p_rst_clears_rd_grad_weight_ptr)
        else $error("UB-A15 FAIL: rst did not clear rd_grad_weight_ptr");

    UB_A16: assert property (p_rst_clears_grad_descent_ptr)
        else $error("UB-A16 FAIL: rst did not clear grad_descent_ptr");

    // ------------------------------------------------------------------
    // Assumptions (formal constraints) — Verification Plan Section 8
    // ------------------------------------------------------------------
    // UB-ASM-01: ub_ptr_select is constrained to the valid pointer range.
    //            Pointer values 0-7 are defined; others are undefined behaviour.
    //            Adjust the upper bound if additional pointers are added.
    UB_ASM_01: assume property (@(posedge clk) disable iff (rst)
        ub_ptr_select < 9'd8);

    // UB-ASM-02: Host writes and VPU writes are mutually exclusive.
    //            The system guarantees that the host does not write while
    //            the VPU is writing back results.
    UB_ASM_02a: assume property (@(posedge clk) disable iff (rst)
        !(ub_wr_valid_in[0] && ub_wr_host_valid_in[0]));

    UB_ASM_02b: assume property (@(posedge clk) disable iff (rst)
        !(ub_wr_valid_in[1] && ub_wr_host_valid_in[1]));

    // UB-ASM-03: ub_rd_row_size and ub_rd_col_size are non-zero and
    //            within the systolic array's physical dimension.
    //            DISABLED UB_ASM_03a for simulation: row_size represents the
    //            batch dimension (number of data rows to read), which can
    //            exceed SYSTOLIC_ARRAY_WIDTH (e.g. row_size=4 for XOR training).
    // UB_ASM_03a: assume property (@(posedge clk) disable iff (rst)
    //     ub_rd_start_in
    //     |-> (ub_rd_row_size >= 16'd1 && ub_rd_row_size <= SYSTOLIC_ARRAY_WIDTH));

    UB_ASM_03b: assume property (@(posedge clk) disable iff (rst)
        ub_rd_start_in
        |-> (ub_rd_col_size >= 16'd1 && ub_rd_col_size <= SYSTOLIC_ARRAY_WIDTH));

    // UB-ASM-04: Learning rate is always positive.
    //            DISABLED for simulation: fires before learning rate is loaded
    //            by the testbench (learning_rate_in = 0 right after reset).
    // UB_ASM_04: assume property (@(posedge clk) disable iff (rst)
    //     !learning_rate_in[15] && learning_rate_in != 16'b0);

    // UB-ASM-05: On the first active clock cycle after reset deasserts,
    //            ub_rd_start_in must be 0.
    //            Required because ub_rd_col_size_valid_out is registered
    //            (BUG-UB-3 fix) from (ub_rd_start_in && ub_ptr_select==1).
    //            Normal operation always gates reads until after the reset
    //            sequence completes, so this assumption is architecturally
    //            sound.
    UB_ASM_05: assume property (@(posedge clk)
        $fell(rst) |=> !ub_rd_start_in);

    // ------------------------------------------------------------------
    // Cover properties
    // ------------------------------------------------------------------
    // UB-COV-01: Full input read burst (row_size=2, col_size=2) completes.
    UB_COV_01: cover property (
        @(posedge clk) disable iff (rst)
        ub_rd_input_valid_out_0 && ub_rd_input_valid_out_1
    );

    // UB-COV-02: Full weight read burst completes.
    UB_COV_02: cover property (
        @(posedge clk) disable iff (rst)
        ub_rd_weight_valid_out_0 && ub_rd_weight_valid_out_1
    );

    // UB-COV-03: Host write on port 0 followed by VPU write-back on port 0.
    UB_COV_03: cover property (
        @(posedge clk) disable iff (rst)
        ub_wr_host_valid_in[0] ##[1:16] ub_wr_valid_in[0]
    );

    // UB-COV-04: Transpose read exercised.
    UB_COV_04: cover property (
        @(posedge clk) disable iff (rst)
        ub_rd_start_in && ub_rd_transpose
    );

    // UB-COV-05: Non-transpose read exercised.
    UB_COV_05: cover property (
        @(posedge clk) disable iff (rst)
        ub_rd_start_in && !ub_rd_transpose
    );

    // UB-COV-06: Column-size valid output asserted (weight pointer selected).
    UB_COV_06: cover property (
        @(posedge clk) disable iff (rst)
        ub_rd_col_size_valid_out
    );

    // UB-COV-07: wr_ptr reaches value 4 (2 full 2-column write-back cycles).
    UB_COV_07: cover property (
        @(posedge clk) disable iff (rst)
        _wr_ptr >= 16'd4
    );

    // UB-COV-08: Grad-descent write-back chain triggered (both channels done).
    UB_COV_08: cover property (
        @(posedge clk) disable iff (rst)
        ub_wr_valid_in[0] && ub_wr_valid_in[1]
    );

    // UB-COV-09: grad_descent_ptr advances past zero (write-back chain exercised).
    UB_COV_09: cover property (
        @(posedge clk) disable iff (rst)
        _grad_descent_ptr > 16'd0
    );

endmodule
