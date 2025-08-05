`timescale 1ns/1ps
`default_nettype none

module leaky_relu_derivative_parent (
    input logic clk,
    input logic rst,
    input logic signed [15:0] lr_leak_factor_in,

    input logic lr_d_valid_1_in,
    input logic lr_d_valid_2_in,

    input logic signed [15:0] lr_d_data_1_in,
    input logic signed [15:0] lr_d_data_2_in,

    input logic signed [15:0] lr_d_H_1_in,
    input logic signed [15:0] lr_d_H_2_in,
    
    output logic signed [15:0] lr_d_data_1_out,
    output logic signed [15:0] lr_d_data_2_out,
    
    output logic lr_d_valid_1_out,
    output logic lr_d_valid_2_out
);

    leaky_relu_derivative_child lr_d_col_1 (
        .clk(clk),
        .rst(rst),
        .lr_d_valid_in(lr_d_valid_1_in),
        .lr_d_data_in(lr_d_data_1_in),
        .lr_leak_factor_in(lr_leak_factor_in),
        .lr_d_data_out(lr_d_data_1_out),
        .lr_d_valid_out(lr_d_valid_1_out),
        .lr_d_H_data_in(lr_d_H_1_in) // H data for col 1 
    );

    leaky_relu_derivative_child lr_d_col_2 (
        .clk(clk),
        .rst(rst),
        .lr_d_valid_in(lr_d_valid_2_in),
        .lr_d_data_in(lr_d_data_2_in),
        .lr_leak_factor_in(lr_leak_factor_in),
        .lr_d_data_out(lr_d_data_2_out),
        .lr_d_valid_out(lr_d_valid_2_out),
        .lr_d_H_data_in(lr_d_H_2_in) // H data for col 2
    );

endmodule