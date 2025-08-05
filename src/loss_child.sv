
`timescale 1ns/1ps
`default_nettype none

// child loss module for MSE backward pass (gradient computation)
module loss_child (
    input logic clk,
    input logic rst,
    
    input logic signed [15:0] H_in,
    input logic signed [15:0] Y_in,
    input logic valid_in,
    input logic signed [15:0] inv_batch_size_times_two_in,  // 2/N as fixed-point input
    
    output logic signed [15:0] gradient_out,
    output logic valid_out
);
    
    // pipeline stages for MSE backward pass: (2/N) * (H - Y)
    logic signed [15:0] diff_stage1;
    logic signed [15:0] final_gradient;
    

    // stage 1 - compute difference (H - Y)
    fxp_addsub subtractor (
        .ina(H_in),
        .inb(Y_in),
        .sub(1'b1), // Subtraction
        .out(diff_stage1),
        .overflow()
    );
    
    // stage 2 - multiply by 2/N
    fxp_mul multiplier (
        .ina(diff_stage1),
        .inb(inv_batch_size_times_two_in),
        .out(final_gradient),
        .overflow()
    );
    
    // pipeline valid signals
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            gradient_out <= '0;
            valid_out <= '0;
        end else begin
            valid_out <= valid_in;
            gradient_out <= final_gradient;
        end
    end

endmodule


