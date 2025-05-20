`timescale 1ns/1ps
`default_nettype none

module pe #(
    parameter int DATA_WIDTH = 16
) (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weight,
    input logic signed [15:0] input_in,
    input logic signed [15:0] psum_in,
    input logic signed [15:0] weight,
    output logic signed [15:0] input_out,
    output logic signed [15:0] psum_out
    );

    logic signed [15:0] weight_reg;
    logic signed [15:0] psum_reg;
    logic signed [15:0] mult_out;

    fxp_mul mult (
        .ina(input_in),
        .inb(weight_reg),
        .out(mult_out),
        .overflow()
    );

    fxp_add adder (
        .ina(mult_out),
        .inb(psum_in),
        .out(psum_reg),
        .overflow()
    );
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            input_out <= 0;
            psum_out <= 0;
            weight_reg <= 0;
        end else if (load_weight) begin
            weight_reg <= weight;
        end else if (start) begin
            input_out <= input_in;
            psum_out <= psum_reg;
        end
    end

endmodule
