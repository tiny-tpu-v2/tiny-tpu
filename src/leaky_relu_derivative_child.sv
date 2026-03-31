`timescale 1ns/1ps
`default_nettype none

module leaky_relu_derivative_child(
    input logic clk,
    input logic rst,

    input logic lr_d_valid_in,
    input logic signed [15:0] lr_d_data_in,
    input logic signed [15:0] lr_leak_factor_in,
    input logic signed [15:0] lr_d_H_data_in, // H data coming through

    output logic lr_d_valid_out,
    output logic signed [15:0] lr_d_data_out,
    output logic lr_d_overflow_out
);
    logic signed [15:0] mul_out;
    logic mul_overflow;
    fxp_mul mul_inst(
        .ina(lr_d_data_in),
        .inb(lr_leak_factor_in),
        .out(mul_out),
        .overflow(mul_overflow)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            lr_d_data_out    <= 16'b0;
            lr_d_valid_out   <= 0;
            lr_d_overflow_out <= 1'b0;
        end else begin
            lr_d_valid_out <= lr_d_valid_in;
            if (lr_d_valid_in) begin
                if (lr_d_H_data_in >= 0) begin
                    lr_d_data_out <= lr_d_data_in;
                end else begin
                    lr_d_data_out <= mul_out;
                end
                lr_d_overflow_out <= lr_d_overflow_out | mul_overflow; // sticky
            end else begin
                lr_d_data_out <= 16'b0;
            end
        end
    end


endmodule