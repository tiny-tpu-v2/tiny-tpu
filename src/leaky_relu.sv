`timescale 1ns/1ps
`default_nettype none

module leaky_relu (
    input logic clk,
    input logic rst,
    input logic signed [15:0] input_in,
    input logic [15:0] leak_factor,
    output logic [15:0] out
);

    always @(posedge clk) begin
        if (rst) begin
            out <= 0;
        
        end else if (input_in > 0) begin
            out <= input_in;
        end else begin
            out <= input_in * leak_factor;
        end
    end

endmodule