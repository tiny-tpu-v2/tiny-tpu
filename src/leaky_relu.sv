`timescale 1ns/1ps
`default_nettype none

module leaky_relu (
    input logic clk,
    input logic rst,
    input logic lr_valid_in,
    input logic signed [15:0] input_in,
    input logic signed [15:0] leak_factor,
    output logic signed [15:0] out,
    output logic lr_valid_out
);
    logic signed[15:0] mul_out;

    fxp_mul mul_inst(
        .ina(input_in),
        .inb(leak_factor),
        .out(mul_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            out <= 16'b0;
            lr_valid_out <= 0;
        end else if (lr_valid_in && lr_valid_out == 0) begin
            if (input_in > 0) begin
                out <= input_in;
            end else begin
                out <= mul_out;
            end
            lr_valid_out <= 1;
        end else begin
            lr_valid_out <= 0;
            out <= 0;
        end
    end

endmodule