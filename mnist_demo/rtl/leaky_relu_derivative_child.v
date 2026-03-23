`timescale 1ns/1ps
`default_nettype none

module leaky_relu_derivative_child(
    input wire clk,
    input wire rst,

    input wire lr_d_valid_in,
    input wire signed [15:0] lr_d_data_in,
    input wire signed [15:0] lr_leak_factor_in,
    input wire signed [15:0] lr_d_H_data_in, // H data coming through

    output reg lr_d_valid_out,
    output reg signed [15:0] lr_d_data_out
);
    // fixed point module and storage
    wire signed [15:0] mul_out;
    fxp_mul mul_inst(
        .ina(lr_d_data_in),
        .inb(lr_leak_factor_in),
        .out(mul_out)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lr_d_data_out <= 16'b0;
            lr_d_valid_out <= 0;
        end else begin
            lr_d_valid_out <= lr_d_valid_in;
            if (lr_d_valid_in) begin
                if (lr_d_H_data_in >= 0) begin      // if derivative is positive, then pass through
                    lr_d_data_out <= lr_d_data_in;
                end else begin                  // if negative,
                    lr_d_data_out <= mul_out;
                end
            end else begin
                lr_d_data_out <= 16'b0;
            end
        end
    end


endmodule
