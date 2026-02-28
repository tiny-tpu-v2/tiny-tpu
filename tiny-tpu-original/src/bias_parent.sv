`timescale 1ns/1ps
`default_nettype none

module bias_parent(
    input logic clk,
    input logic rst,

    input logic signed [15:0] bias_scalar_in_1,
    input logic signed [15:0] bias_scalar_in_2, // bias scalars fetched from the unified buffer (rename it to bias_scalar_ub_in)

    output logic bias_Z_valid_out_1,
    output logic bias_Z_valid_out_2,

    input wire signed [15:0] bias_sys_data_in_1,
    input wire signed [15:0] bias_sys_data_in_2,

    input wire bias_sys_valid_in_1,
    input wire bias_sys_valid_in_2,

    output logic signed [15:0] bias_z_data_out_1,
    output logic signed [15:0] bias_z_data_out_2

); 
    // Each bias module handles a feature column for a pre-activation matrix. 

    bias_child column_1 (
        .clk(clk),
        .rst(rst),
        .bias_scalar_in(bias_scalar_in_1),
        .bias_Z_valid_out(bias_Z_valid_out_1),
        .bias_sys_data_in(bias_sys_data_in_1),
        .bias_sys_valid_in(bias_sys_valid_in_1),
        .bias_z_data_out(bias_z_data_out_1)
    );

    bias_child column_2 (
        .clk(clk),
        .rst(rst),
        .bias_scalar_in(bias_scalar_in_2),
        .bias_Z_valid_out(bias_Z_valid_out_2),
        .bias_sys_data_in(bias_sys_data_in_2),
        .bias_sys_valid_in(bias_sys_valid_in_2),
        .bias_z_data_out(bias_z_data_out_2)
    );


endmodule