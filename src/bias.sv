`timescale 1ns/1ps
`default_nettype none

module bias (
    input logic clk,
    input logic rst,
    input logic bias_valid_in,
    input logic signed [15:0] input_in,
    input logic signed [15:0] bias_in,
    output logic signed [15:0] output_out,
    output logic bias_valid_out
);

    always @(posedge clk) begin
        if (rst) begin
            output_out <= 0;
            bias_valid_out <= 0;
        end else if (bias_valid_in) begin
                output_out <= input_in + bias_in;
                bias_valid_out <= 1;
        end else begin
                bias_valid_out <= 0;
                output_out <= 0;
        end
    end

endmodule