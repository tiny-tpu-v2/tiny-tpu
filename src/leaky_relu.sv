`timescale 1ns/1ps
`default_nettype none

module leaky_relu (
    input logic clk,
    input logic rst,
    input logic signed [15:0] input_in,
    input logic [15:0] leak_factor,
    output logic [15:0] out
);

    logic [15:0] mul_out;

    fxp_mul mul_inst(
        .ina(input_in),
        .inb(leak_factor),
        .out(mul_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            out <= 16'b0;
        end else if (input_in > 0) begin
            out <= input_in;
        end else begin
            out <= mul_out;
        end
    end

endmodule