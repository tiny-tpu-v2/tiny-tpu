`timescale 1ns/1ps
`default_nettype none

module bias (
    input logic clk,
    input logic rst,
    input logic bias_valid_in,
    input logic signed [15:0] bias_data_in,
    input logic signed [15:0] bias_temp_bias,
    
    output logic signed [15:0] bias_data_out,
    output logic bias_valid_out
);

    logic signed [15:0] add_out;

    fxp_add add_inst(
        .ina(bias_data_in),
        .inb(bias_temp_bias),
        .out(add_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            bias_data_out <= 0;
            bias_valid_out <= 0;
        end else if (bias_valid_in) begin
            bias_data_out <= add_out;
            bias_valid_out <= 1;
        end else begin
            bias_valid_out <= 0;
                bias_data_out <= 0;
        end
    end

endmodule