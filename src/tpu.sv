`timescale 1ns/1ps
`default_nettype none

// goal of this module is to verify that the systolic array works. 

module tpu (
    // wires n shit
    input logic clk,
    input logic rst,

    // UB wires
    input logic [15:0] ub_wr_addr_in,
    input logic ub_wr_addr_valid_in,

    input logic [15:0] ub_wr_host_data_in_1,
    input logic [15:0] ub_wr_host_data_in_2,
    input logic ub_wr_host_valid_in_1,
    input logic ub_wr_host_valid_in_2,

    // UB to left side of systolic array
    input logic ub_rd_input_transpose,
    input logic ub_rd_input_start_in,
    input logic [15:0] ub_rd_input_addr_in,
    input logic [15:0] ub_rd_input_loc_in,

    // UB to top of systolic array
    input logic ub_rd_weight_transpose,
    input logic ub_rd_weight_start_in,
    input logic [15:0] ub_rd_weight_addr_in,
    input logic [15:0] ub_rd_weight_loc_in,

    // UB to bias modules in VPU
    input logic ub_rd_bias_start_in,
    input logic [15:0] ub_rd_bias_addr_in,
    input logic [15:0] ub_rd_bias_loc_in,

    // UB to loss modules in VPU
    input logic ub_rd_Y_start_in,
    input logic [15:0] ub_rd_Y_addr_in,
    input logic [15:0] ub_rd_Y_loc_in,

    // UB to activation derivative modules in VPU
    input logic ub_rd_H_start_in,
    input logic [15:0] ub_rd_H_addr_in,
    input logic [15:0] ub_rd_H_loc_in,

    input logic [3:0] vpu_data_pathway,

    input logic sys_switch_in,
    input logic [15:0] vpu_leak_factor_in,        // use an input port for now
    input logic [15:0] inv_batch_size_times_two_in
);
    // UB internal output wires
    logic [15:0] ub_rd_input_data_1_out;
    logic [15:0] ub_rd_input_data_2_out;
    logic ub_rd_input_valid_1_out;
    logic ub_rd_input_valid_2_out;

    logic [15:0] ub_rd_weight_data_1_out;
    logic [15:0] ub_rd_weight_data_2_out;
    logic ub_rd_weight_valid_1_out;
    logic ub_rd_weight_valid_2_out;

    logic [15:0] ub_rd_bias_data_1_out; 
    logic [15:0] ub_rd_bias_data_2_out; 
    

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
    
    logic [15:0] ub_rd_Y_data_1_out; 
    logic [15:0] ub_rd_Y_data_2_out; 
    logic ub_rd_Y_valid_1_out;
    logic ub_rd_Y_valid_2_out;

    logic [15:0] ub_rd_H_data_1_out; 
    logic [15:0] ub_rd_H_data_2_out; 
    logic ub_rd_H_valid_1_out;
    logic ub_rd_H_valid_2_out;
    

// TODO: add writing functionality from Host to UB to write X (input values) and W (weights) matrices into UB memory
unified_buffer unified_buffer_inst (
    .clk(clk),
    .rst(rst),

    .ub_wr_addr_in(ub_wr_addr_in),
    .ub_wr_addr_valid_in(ub_wr_addr_valid_in),

    .ub_wr_data_in_1(vpu_data_out_1), // VPU data to UB connection
    .ub_wr_data_in_2(vpu_data_out_2), // VPU data to UB connection
    .ub_wr_valid_data_in_1(vpu_valid_out_1), // VPU valid signal to UB 
    .ub_wr_valid_data_in_2(vpu_valid_out_2), // VPU valid signal to UB 

    .ub_wr_host_data_in_1(ub_wr_host_data_in_1),
    .ub_wr_host_data_in_2(ub_wr_host_data_in_2),
    .ub_wr_host_valid_in_1(ub_wr_host_valid_in_1),
    .ub_wr_host_valid_in_2(ub_wr_host_valid_in_2),

    // for left side input of systolic array
    .ub_rd_input_transpose(ub_rd_input_transpose),
    .ub_rd_input_start_in(ub_rd_input_start_in),
    .ub_rd_input_addr_in(ub_rd_input_addr_in),
    .ub_rd_input_loc_in(ub_rd_input_loc_in),

    .ub_rd_input_data_1_out(ub_rd_input_data_1_out),
    .ub_rd_input_data_2_out(ub_rd_input_data_2_out),
    .ub_rd_input_valid_1_out(ub_rd_input_valid_1_out),
    .ub_rd_input_valid_2_out(ub_rd_input_valid_2_out),

    // for top input of systolic array
    .ub_rd_weight_start_in(ub_rd_weight_start_in),
    .ub_rd_weight_transpose(ub_rd_weight_transpose),
    .ub_rd_weight_addr_in(ub_rd_weight_addr_in),
    .ub_rd_weight_loc_in(ub_rd_weight_loc_in),

    .ub_rd_weight_data_1_out(ub_rd_weight_data_1_out),
    .ub_rd_weight_data_2_out(ub_rd_weight_data_2_out),
    .ub_rd_weight_valid_1_out(ub_rd_weight_valid_1_out),
    .ub_rd_weight_valid_2_out(ub_rd_weight_valid_2_out),

    .ub_rd_bias_start_in(ub_rd_bias_start_in),
    .ub_rd_bias_addr_in(ub_rd_bias_addr_in),
    .ub_rd_bias_loc_in(ub_rd_bias_loc_in),

    .ub_rd_bias_data_1_out(ub_rd_bias_data_1_out),
    .ub_rd_bias_data_2_out(ub_rd_bias_data_2_out),
    .ub_rd_bias_valid_1_out(),
    .ub_rd_bias_valid_2_out(),

    .ub_rd_Y_start_in(ub_rd_Y_start_in),
    .ub_rd_Y_addr_in(ub_rd_Y_addr_in),
    .ub_rd_Y_loc_in(ub_rd_Y_loc_in),

    .ub_rd_Y_data_1_out(ub_rd_Y_data_1_out),
    .ub_rd_Y_data_2_out(ub_rd_Y_data_2_out),
    .ub_rd_Y_valid_1_out(ub_rd_Y_valid_1_out),
    .ub_rd_Y_valid_2_out(ub_rd_Y_valid_2_out),

    .ub_rd_H_start_in(ub_rd_H_start_in),
    .ub_rd_H_addr_in(ub_rd_H_addr_in),
    .ub_rd_H_loc_in(ub_rd_H_loc_in),

    .ub_rd_H_data_1_out(ub_rd_H_data_1_out),
    .ub_rd_H_data_2_out(ub_rd_H_data_2_out),
    .ub_rd_H_valid_1_out(ub_rd_H_valid_1_out),
    .ub_rd_H_valid_2_out(ub_rd_H_valid_2_out)
);

systolic systolic_inst (
    .clk(clk),
    .rst(rst),

    // input signals from left side of systolic array
    .sys_data_in_11(ub_rd_input_data_1_out),
    .sys_data_in_21(ub_rd_input_data_2_out),
    .sys_start_1(ub_rd_input_valid_1_out),    // start signal propagates only from left to right in row 1
    .sys_start_2(ub_rd_input_valid_2_out),    // start signal propagates only from left to right in row 2

    .sys_data_out_21(sys_data_out_21),
    .sys_data_out_22(sys_data_out_22),
    .sys_valid_out_21(sys_valid_out_21), 
    .sys_valid_out_22(sys_valid_out_22),

    // input signals from top of systolic array
    .sys_weight_in_11(ub_rd_weight_data_1_out), 
    .sys_weight_in_12(ub_rd_weight_data_2_out),
    .sys_accept_w_1(ub_rd_weight_valid_1_out),       // accept weight signal propagates only from top to bottom in column 1
    .sys_accept_w_2(ub_rd_weight_valid_2_out),       // accept weight signal propagates only from top to bottom in column 2

    .sys_switch_in(sys_switch_in)          // switch signal copies weight from shadow buffer to active buffer. propagates from top left to bottom right
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
    .bias_scalar_in_1(ub_rd_bias_data_1_out),               // For bias modules
    .bias_scalar_in_2(ub_rd_bias_data_2_out),               // For bias modules
    .lr_leak_factor_in(vpu_leak_factor_in),                 // For leaky relu modules
    .Y_in_1(ub_rd_Y_data_1_out),                                  // For loss modules
    .Y_in_2(ub_rd_Y_data_2_out),                                  // For loss modules
    .inv_batch_size_times_two_in(inv_batch_size_times_two_in),             // For loss modules
    .H_in_1(ub_rd_H_data_1_out),                                  // For leaky relu derivative modules (WE ONLY NEED THIS PORT FOR EVERY dL/dH after the first node)
    .H_in_2(ub_rd_H_data_2_out),                                  // For leaky relu derivative modules (WE ONLY NEED THIS PORT FOR EVERY dL/dH after the first node)

    // Outputs to UB
    .vpu_data_out_1(vpu_data_out_1),
    .vpu_data_out_2(vpu_data_out_2),
    .vpu_valid_out_1(vpu_valid_out_1),
    .vpu_valid_out_2(vpu_valid_out_2)

); 

endmodule