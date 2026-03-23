`timescale 1ns/1ps
`default_nettype none

module tpu #(
    parameter SYSTOLIC_ARRAY_WIDTH = 2
)(
    input wire clk,
    input wire rst,

    // UB wires (writing from host to UB)
    input wire [15:0] ub_wr_host_data_in_0,
    input wire [15:0] ub_wr_host_data_in_1,
    input wire ub_wr_host_valid_in_0,
    input wire ub_wr_host_valid_in_1,

    // UB wires (inputting reading instructions from host)
    input wire ub_rd_start_in,
    input wire ub_rd_transpose,
    input wire [8:0] ub_ptr_select,
    input wire [15:0] ub_rd_addr_in,
    input wire [15:0] ub_rd_row_size,
    input wire [15:0] ub_rd_col_size,

    // Learning rate
    input wire [15:0] learning_rate_in,

    // VPU data pathway
    input wire [3:0] vpu_data_pathway,

    input wire sys_switch_in,
    input wire [15:0] vpu_leak_factor_in,
    input wire [15:0] inv_batch_size_times_two_in,

    // Outputs - Systolic Array Results
    output wire [15:0] sys_data_out_21,
    output wire [15:0] sys_data_out_22,
    output wire sys_valid_out_21,
    output wire sys_valid_out_22,

    // Outputs - VPU Results
    output wire [15:0] vpu_data_out_1,
    output wire [15:0] vpu_data_out_2,
    output wire vpu_valid_out_1,
    output wire vpu_valid_out_2,

    // Outputs - Unified Buffer Read Ports (for debugging/monitoring)
    output wire [15:0] ub_rd_input_data_out_0,
    output wire [15:0] ub_rd_input_data_out_1,
    output wire ub_rd_input_valid_out_0,
    output wire ub_rd_input_valid_out_1,
    output wire [15:0] ub_rd_weight_data_out_0,
    output wire [15:0] ub_rd_weight_data_out_1,
    output wire ub_rd_weight_valid_out_0,
    output wire ub_rd_weight_valid_out_1,
    output wire [15:0] ub_rd_bias_data_out_0,
    output wire [15:0] ub_rd_bias_data_out_1,
    output wire [15:0] ub_rd_Y_data_out_0,
    output wire [15:0] ub_rd_Y_data_out_1,
    output wire [15:0] ub_rd_H_data_out_0,
    output wire [15:0] ub_rd_H_data_out_1,
    output wire [15:0] ub_rd_col_size_out,
    output wire ub_rd_col_size_valid_out
);
    // UB internal wires (feedback from VPU to UB)
    wire [15:0] ub_wr_data_in_0;
    wire [15:0] ub_wr_data_in_1;
    wire ub_wr_valid_in_0;
    wire ub_wr_valid_in_1;

    assign ub_wr_data_in_0 = vpu_data_out_1;
    assign ub_wr_data_in_1 = vpu_data_out_2;
    assign ub_wr_valid_in_0 = vpu_valid_out_1;
    assign ub_wr_valid_in_1 = vpu_valid_out_2;

    unified_buffer #(
        .SYSTOLIC_ARRAY_WIDTH(SYSTOLIC_ARRAY_WIDTH)
    ) ub_inst(
        .clk(clk),
        .rst(rst),

        .ub_wr_data_in_0(ub_wr_data_in_0),
        .ub_wr_data_in_1(ub_wr_data_in_1),
        .ub_wr_valid_in_0(ub_wr_valid_in_0),
        .ub_wr_valid_in_1(ub_wr_valid_in_1),

        // Write ports from host to UB (for loading in parameters)
        .ub_wr_host_data_in_0(ub_wr_host_data_in_0),
        .ub_wr_host_data_in_1(ub_wr_host_data_in_1),
        .ub_wr_host_valid_in_0(ub_wr_host_valid_in_0),
        .ub_wr_host_valid_in_1(ub_wr_host_valid_in_1),

        // Read instruction input from instruction memory
        .ub_rd_start_in(ub_rd_start_in),
        .ub_rd_transpose(ub_rd_transpose),
        .ub_ptr_select(ub_ptr_select),
        .ub_rd_addr_in(ub_rd_addr_in),
        .ub_rd_row_size(ub_rd_row_size),
        .ub_rd_col_size(ub_rd_col_size),

        // Learning rate input
        .learning_rate_in(learning_rate_in),

        // Read ports from UB to left side of systolic array
        .ub_rd_input_data_out_0(ub_rd_input_data_out_0),
        .ub_rd_input_data_out_1(ub_rd_input_data_out_1),
        .ub_rd_input_valid_out_0(ub_rd_input_valid_out_0),
        .ub_rd_input_valid_out_1(ub_rd_input_valid_out_1),

        // Read ports from UB to top of systolic array
        .ub_rd_weight_data_out_0(ub_rd_weight_data_out_0),
        .ub_rd_weight_data_out_1(ub_rd_weight_data_out_1),
        .ub_rd_weight_valid_out_0(ub_rd_weight_valid_out_0),
        .ub_rd_weight_valid_out_1(ub_rd_weight_valid_out_1),

        // Read ports from UB to bias modules in VPU
        .ub_rd_bias_data_out_0(ub_rd_bias_data_out_0),
        .ub_rd_bias_data_out_1(ub_rd_bias_data_out_1),

        // Read ports from UB to loss modules (Y matrices) in VPU
        .ub_rd_Y_data_out_0(ub_rd_Y_data_out_0),
        .ub_rd_Y_data_out_1(ub_rd_Y_data_out_1),

        // Read ports from UB to activation derivative modules (H matrices) in VPU
        .ub_rd_H_data_out_0(ub_rd_H_data_out_0),
        .ub_rd_H_data_out_1(ub_rd_H_data_out_1),

        // Outputs to send number of columns to systolic array
        .ub_rd_col_size_out(ub_rd_col_size_out),
        .ub_rd_col_size_valid_out(ub_rd_col_size_valid_out)
    );

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),

        // input signals from left side of systolic array
        .sys_data_in_11(ub_rd_input_data_out_0),
        .sys_data_in_21(ub_rd_input_data_out_1),
        .sys_start(ub_rd_input_valid_out_0),    // start signal

        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),
        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22),

        // input signals from top of systolic array
        .sys_weight_in_11(ub_rd_weight_data_out_0),
        .sys_weight_in_12(ub_rd_weight_data_out_1),
        .sys_accept_w_1(ub_rd_weight_valid_out_0),       // accept weight signal propagates only from top to bottom in column 1
        .sys_accept_w_2(ub_rd_weight_valid_out_1),       // accept weight signal propagates only from top to bottom in column 2

        .sys_switch_in(sys_switch_in),          // switch signal copies weight from shadow buffer to active buffer. propagates from top left to bottom right

        .ub_rd_col_size_in(ub_rd_col_size_out),
        .ub_rd_col_size_valid_in(ub_rd_col_size_valid_out)
    );

    vpu vpu_inst (
        .clk(clk),
        .rst(rst),

        .vpu_data_pathway(vpu_data_pathway), // 4-bits to signify which modules to route the inputs to (1 bit for each module)

        // Inputs from systolic array
        .vpu_data_in_1(sys_data_out_21),
        .vpu_data_in_2(sys_data_out_22),
        .vpu_valid_in_1(sys_valid_out_21),
        .vpu_valid_in_2(sys_valid_out_22),

        // Inputs from UB
        .bias_scalar_in_1(ub_rd_bias_data_out_0),               // For bias modules
        .bias_scalar_in_2(ub_rd_bias_data_out_1),               // For bias modules
        .lr_leak_factor_in(vpu_leak_factor_in),                 // For leaky relu modules
        .Y_in_1(ub_rd_Y_data_out_0),                                  // For loss modules
        .Y_in_2(ub_rd_Y_data_out_1),                                  // For loss modules
        .inv_batch_size_times_two_in(inv_batch_size_times_two_in),             // For loss modules
        .H_in_1(ub_rd_H_data_out_0),                                  // For leaky relu derivative modules (WE ONLY NEED THIS PORT FOR EVERY dL/dH after the first node)
        .H_in_2(ub_rd_H_data_out_1),                                  // For leaky relu derivative modules (WE ONLY NEED THIS PORT FOR EVERY dL/dH after the first node)

        // Outputs to UB
        .vpu_data_out_1(vpu_data_out_1),
        .vpu_data_out_2(vpu_data_out_2),
        .vpu_valid_out_1(vpu_valid_out_1),
        .vpu_valid_out_2(vpu_valid_out_2)
    );
endmodule
