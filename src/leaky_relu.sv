`timescale 1ns/1ps
`default_nettype none

module leaky_relu (
    input logic clk,
    input logic rst,
    input logic lr_valid_in,
    input logic signed [15:0] lr_data_in,
    input logic signed [15:0] lr_temp_leak_factor,
    output logic signed [15:0] lr_data_out,
    output logic lr_valid_out
);
    logic signed[15:0] mul_out;

    fxp_mul mul_inst(
        .ina(lr_data_in),
        .inb(lr_temp_leak_factor),
        .out(mul_out)
    );


    always @(posedge clk) begin
        if (rst) begin
            lr_data_out <= 16'b0;
            lr_valid_out <= 0;
        end else if (lr_valid_in) begin     // removed lr_valid_in && lr_valid_out == 0 to allow for batching
            if (lr_data_in > 0) begin
                lr_data_out <= lr_data_in;
            end else begin
                lr_data_out <= mul_out;
            end
            lr_valid_out <= 1;
        end else begin
            lr_valid_out <= 0;
            lr_data_out <= 0;
        end
    end

endmodule