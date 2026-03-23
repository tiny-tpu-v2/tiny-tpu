`timescale 1ns/1ps
`default_nettype none

module tpu #(
    parameter int SYSTOLIC_ARRAY_WIDTH = 2
)(
    input logic clk,
    input logic rst,

    // UB wires (writing from host to UB)
    input logic [15:0] ub_wr_host_data_in [0:SYSTOLIC_ARRAY_WIDTH-1],
    input logic ub_wr_host_valid_in [0:SYSTOLIC_ARRAY_WIDTH-1],

    // UB wires (inputting reading instructions from host)
    input logic ub_rd_start_in,
    input logic ub_rd_transpose,
    input logic [8:0] ub_ptr_select,
    input logic [15:0] ub_rd_addr_in,
    input logic [15:0] ub_rd_row_size,
    input logic [15:0] ub_rd_col_size,

    // Learning rate
    input logic [15:0] learning_rate_in,

    // VPU data pathway
    input logic [3:0] vpu_data_pathway,

    input logic sys_switch_in,
    input logic [15:0] vpu_leak_factor_in,
    input logic [15:0] inv_batch_size_times_two_in
);
    // UB internal output wires
    logic [15:0] ub_wr_data_in [0:SYSTOLIC_ARRAY_WIDTH-1];
    logic ub_wr_valid_in [0:SYSTOLIC_ARRAY_WIDTH-1];

    // Number of columns in the matrix to send to systolic array to disable columns of PEs
    logic [15:0] ub_rd_col_size_out;
    logic ub_rd_col_size_valid_out;
    
    // Array wires for connection to unified_buffer
    logic [15:0] ub_rd_input_data_out_0;
    logic [15:0] ub_rd_input_data_out_1;
    logic ub_rd_input_valid_out_0;
    logic ub_rd_input_valid_out_1;

    logic [15:0] ub_rd_weight_data_out_0;
    logic [15:0] ub_rd_weight_data_out_1;
    logic ub_rd_weight_valid_out_0;
    logic ub_rd_weight_valid_out_1;

    logic [15:0] ub_rd_bias_data_out_0;
    logic [15:0] ub_rd_bias_data_out_1;
    
    logic [15:0] ub_rd_Y_data_out_0;
    logic [15:0] ub_rd_Y_data_out_1;

    logic [15:0] ub_rd_H_data_out_0;
    logic [15:0] ub_rd_H_data_out_1;

    // Systolic array internal output wires
    logic [15:0] sys_data_out_21;
    logic [15:0] sys_data_out_22;
    logic sys_valid_out_21;
    logic sys_valid_out_22;

    // VPU internal output wires
    logic [15:0] vpu_data_out_1;
    logic [15:0] vpu_data_out_2;
    logic vpu_valid_out_1;
    logic vpu_valid_out_2;

    assign ub_wr_data_in[0] = vpu_data_out_1;
    assign ub_wr_data_in[1] = vpu_data_out_2;
    assign ub_wr_valid_in[0] = vpu_valid_out_1;
    assign ub_wr_valid_in[1] = vpu_valid_out_2;
    
    unified_buffer #(
        .SYSTOLIC_ARRAY_WIDTH(SYSTOLIC_ARRAY_WIDTH)
    ) ub_inst(
        .clk(clk),
        .rst(rst),

        .ub_wr_data_in(ub_wr_data_in),
        .ub_wr_valid_in(ub_wr_valid_in),

        // Write ports from host to UB (for loading in parameters)
        .ub_wr_host_data_in(ub_wr_host_data_in),
        .ub_wr_host_valid_in(ub_wr_host_valid_in),

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
        // .sys_start_2(ub_rd_input_valid_out_1),    // start signal propagates only from left to right in row 2

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