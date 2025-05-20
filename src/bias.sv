`timescale 1ns/1ps
`default_nettype none

module bias (
    input logic clk,
    input logic rst,
    input logic signed [15:0] input_in,
    input logic signed [15:0] bias_in,
    output logic signed [15:0] output_out
);

    always @(posedge clk) begin
        if (rst) begin
            output_out <= 0;
        end else begin
            if (input_in != 0) begin
                output_out <= input_in + bias_in;
            end
        end
    end

endmodule