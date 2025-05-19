`timescale 1ns/1ps
`default_nettype none

module pe (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weight,
    input logic [15:0] input_in,
    input logic [15:0] psum_in,
    input logic [15:0] weight,
    output logic [15:0] input_out,
    output logic [15:0] psum_out
    );

    logic [15:0] weight_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            input_out <= 0;
            psum_out <= 0;
            weight_reg <= 0;
        end else if (load_weight) begin
            weight_reg <= weight;
        end else if (start) begin
            input_out <= input_in;
            psum_out <= (input_in * weight_reg) + psum_in;
        end
    end

endmodule
