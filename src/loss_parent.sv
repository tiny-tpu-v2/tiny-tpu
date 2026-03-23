`timescale 1ns/1ps
`default_nettype none

module loss_parent (
    input logic clk,
    input logic rst,
    
    input logic signed [15:0] H_1_in,
    input logic signed [15:0] Y_1_in,
    input logic signed [15:0] H_2_in,
    input logic signed [15:0] Y_2_in,
    
    input logic valid_1_in,
    input logic valid_2_in,
    
    input logic signed [15:0] inv_batch_size_times_two_in,  // 2/N as fixed-point input
    output logic signed [15:0] gradient_1_out,
    output logic signed [15:0] gradient_2_out,
    output logic valid_1_out,
    output logic valid_2_out
);

// loss child #1 instantiation
loss_child first_column (
    .clk(clk),
    .rst(rst),
    .H_in(H_1_in),
    .Y_in(Y_1_in),
    .valid_in(valid_1_in),
    .inv_batch_size_times_two_in(inv_batch_size_times_two_in),
    .gradient_out(gradient_1_out), 
    .valid_out(valid_1_out)
);

// loss child #2 instantiation
loss_child second_column (
    .clk(clk),
    .rst(rst),
    .H_in(H_2_in),
    .Y_in(Y_2_in),
    .valid_in(valid_2_in),
    .inv_batch_size_times_two_in(inv_batch_size_times_two_in),
    .gradient_out(gradient_2_out),
    .valid_out(valid_2_out)
);


endmodule