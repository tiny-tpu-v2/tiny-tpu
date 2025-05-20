`timescale 1ns/1ps
`default_nettype none

module pe #(
    parameter int DATA_WIDTH = 16
) (
    input logic clk,
    input logic rst,


    input logic pe_valid_in, // valid in signal for the PE
    output logic pe_valid_out, // valid out sig... 


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
            input_out <= 16'b0;
            psum_out <= 16'b0;
            weight_reg <= 16'b0;
        end else if (load_weight) begin
            weight_reg <= weight;
        end else if (pe_valid_in) begin
            input_out <= input_in;
            psum_out <= psum_reg;

            pe_valid_out <= 1; // ensure that in the testbench for this, we only assert pe_valid_in for one clock cycle
            // so that valid pe_valid_out becomes zero after that. 
        end else if (!pe_valid_in) begin
            pe_valid_out <= 0; // we can probably refactor this into a FSM 
            psum_out <= 0;

        end
    end

endmodule
