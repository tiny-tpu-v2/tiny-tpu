`timescale 1ns/1ps
`default_nettype none

// goal of this module is to verify that the systolic array works. 

module tpu (
    input  logic        clk,
    input  logic        rst,

    // write signals from VPU to UB
    input  logic        ub_wr_addr_valid_in,
    input  logic [5:0]  ub_wr_addr_in, // address to start at
    
    // write interface to UB
    input  logic [15:0] ub_wr_data_1_in,
    input  logic [15:0] ub_wr_data_2_in,
    input  logic        ub_wr_valid_data_in_1,
    input  logic        ub_wr_valid_data_in_2,

    // model data from host to UB (put in weights, inputs, biases, and outputs Y) THERE IS DATA CONTENTION HERE IF WE HAVE DRAM BUT FOR SIMPLICITY OF DESIGN WE WILL ALL NECESSARY VALUES
    input  logic [15:0] ub_wr_host_data_in_1, 
    input  logic [15:0] ub_wr_host_data_in_2, 
    input  logic        ub_wr_host_valid_in_1, 
    input  logic        ub_wr_host_valid_in_2, 
    
    // read interface to systolic array for left inputs (X's, H's, or dL/dZ^T) from UB to systolic array
    input  logic        ub_rd_input_transpose,         // FLAG EXCLUSIVE TO LEFT SIDE OF SYSTOLIC ARRAY
    input  logic        ub_rd_input_start_in,
    input  logic [5:0]  ub_rd_input_addr_in,
    input  logic [5:0]  ub_rd_input_loc_in,

    // read interface to systolic array for weights (W^T, W or H aka top inputs) from UB to systolic array
    input  logic        ub_rd_weight_transpose,
    input  logic        ub_rd_weight_start_in,
    input  logic [5:0]  ub_rd_weight_addr_in,
    input  logic [5:0]  ub_rd_weight_loc_in,

    // read interface for bias from UB to systolic array
    input  logic        ub_rd_bias_start_in,
    input  logic [5:0]  ub_rd_bias_addr_in,
    input  logic [5:0]  ub_rd_bias_loc_in,

    // // loss read interface for Y's from UB to VPU loss module
    // input  logic        ub_rd_Y_start_in,
    // input  logic [5:0]  ub_rd_Y_addr_in,
    // input  logic [5:0]  ub_rd_Y_loc_in,

    // // activation derivative read interface for H's from UB to VPU activation derivative module
    // input  logic        ub_rd_H_start_in,
    // input  logic [5:0]  ub_rd_H_addr_in,
    // input  logic [5:0]  ub_rd_H_loc_in,

    // extra   
    input logic [15:0] vpu_inv_batch_size_times_two_in,
    input logic [15:0] vpu_leak_factor_in,
    
    input logic [3:0] vpu_data_pathway, // 4-bits to signify which modules to route the inputs to (1 bit for each module)

    // systolic array data to feed into VPU (controlled by testbench for now)
    input logic [15:0] sys_data_out_21,
    input logic [15:0] sys_data_out_22,
    input logic sys_valid_out_21,
    input logic sys_valid_out_22
);



    // outputs for bias from UB to systolic arr
    // bias values goings module to VPU bias module
    logic [15:0] ub_rd_bias_data_1_out;
    logic [15:0] ub_rd_bias_data_2_out;
    logic        ub_rd_bias_valid_1_out;
    logic        ub_rd_bias_valid_2_out;

    // Y labels going from UB to VPU loss module
    logic [15:0] ub_rd_Y_data_1_out;
    logic [15:0] ub_rd_Y_data_2_out;
    logic        ub_rd_Y_valid_1_out;
    logic        ub_rd_Y_valid_2_out;

    // outputs for H's from UB to VPU lekay relu derivative module
    logic [15:0] ub_rd_H_data_1_out;
    logic [15:0] ub_rd_H_data_2_out;
    logic        ub_rd_H_valid_1_out;
    logic        ub_rd_H_valid_2_out;

    // outputs for weights (W^T or H aka top inputs) from UB to systolic array
    logic [15:0] ub_rd_weight_data_1_out;
    logic [15:0] ub_rd_weight_data_2_out;
    logic        ub_rd_weight_valid_1_out;
    logic        ub_rd_weight_valid_2_out;

    

    // output of the vpu    
    logic [15:0] vpu_data_1_out;
    logic [15:0] vpu_data_2_out;
    logic        vpu_valid_1_out;
    logic        vpu_valid_2_out;


    
    
    unified_buffer ub (
        .clk(clk),
        .rst(rst),
        .ub_wr_addr_valid_in(ub_wr_addr_valid_in),
        .ub_wr_addr_in(ub_wr_addr_in),
        .ub_wr_data_in_1(vpu_data_1_out),
        .ub_wr_data_in_2(vpu_data_2_out),
        .ub_wr_valid_data_in_1(vpu_valid_1_out),
        .ub_wr_valid_data_in_2(vpu_valid_2_out),
        .ub_wr_host_data_in_1(ub_wr_host_data_in_1),
        .ub_wr_host_data_in_2(ub_wr_host_data_in_2),
        .ub_wr_host_valid_in_1(ub_wr_host_valid_in_1),
        .ub_wr_host_valid_in_2(ub_wr_host_valid_in_2),
        
        .ub_rd_input_transpose(),
        .ub_rd_input_start_in(),
        .ub_rd_input_addr_in(),
        .ub_rd_input_loc_in(),
        .ub_rd_input_data_1_out(),
        .ub_rd_input_data_2_out(),
        .ub_rd_input_valid_1_out(),
        .ub_rd_input_valid_2_out(),
        .ub_rd_weight_transpose(),
        .ub_rd_weight_start_in(),
        .ub_rd_weight_addr_in(),
        .ub_rd_weight_loc_in(),
        .ub_rd_weight_data_1_out(),
        .ub_rd_weight_data_2_out(),
        .ub_rd_weight_valid_1_out(),
        .ub_rd_weight_valid_2_out(),

        .ub_rd_bias_start_in(ub_rd_bias_start_in),
        .ub_rd_bias_addr_in(ub_rd_bias_addr_in),
        .ub_rd_bias_loc_in(ub_rd_bias_loc_in),
        .ub_rd_bias_data_1_out(ub_rd_bias_data_1_out),
        .ub_rd_bias_data_2_out(ub_rd_bias_data_2_out),
        .ub_rd_bias_valid_1_out(ub_rd_bias_valid_1_out),
        .ub_rd_bias_valid_2_out(ub_rd_bias_valid_2_out),

        .ub_rd_Y_start_in(),
        .ub_rd_Y_addr_in(),
        .ub_rd_Y_loc_in(),
        .ub_rd_Y_data_1_out(),
        .ub_rd_Y_data_2_out(),
        .ub_rd_Y_valid_1_out(),
        .ub_rd_Y_valid_2_out(),

        .ub_rd_H_start_in(),
        .ub_rd_H_addr_in(),
        .ub_rd_H_loc_in(),
        .ub_rd_H_data_1_out(),
        .ub_rd_H_data_2_out(),
        .ub_rd_H_valid_1_out(),
        .ub_rd_H_valid_2_out()

    );

    vpu vpu (
        .clk(clk),
        .rst(rst),
        .data_pathway(vpu_data_pathway),
        .vpu_data_in_1(sys_data_out_21),
        .vpu_data_in_2(sys_data_out_22),
        .vpu_valid_in_1(sys_valid_out_21),
        .vpu_valid_in_2(sys_valid_out_22),
        .bias_scalar_in_1(ub_rd_bias_data_1_out),
        .lr_leak_factor_in(vpu_leak_factor_in),
        .Y_in_1(ub_rd_Y_data_1_out),    
        .Y_in_2(ub_rd_Y_data_2_out),
        .inv_batch_size_times_two_in(vpu_inv_batch_size_times_two_in),
        .H_in_1(ub_rd_H_data_1_out),
        .H_in_2(ub_rd_H_data_2_out),
        .vpu_data_out_1(vpu_data_1_out),
        .vpu_data_out_2(vpu_data_2_out),
        .vpu_valid_out_1(vpu_valid_1_out),
        .vpu_valid_out_2(vpu_valid_2_out)
    );
endmodule