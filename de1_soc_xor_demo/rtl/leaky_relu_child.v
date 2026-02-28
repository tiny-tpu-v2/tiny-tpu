`timescale 1ns/1ps
`default_nettype none

module leaky_relu_child (
    input wire clk,
    input wire rst,
    input wire lr_valid_in,
    input wire signed [15:0] lr_data_in,
    input wire signed [15:0] lr_leak_factor_in,
    output reg signed [15:0] lr_data_out,
    output reg lr_valid_out
);

    // fixed point module and storage
    wire signed [15:0] mul_out;
    fxp_mul mul_inst(
        .ina(lr_data_in),
        .inb(lr_leak_factor_in),
        .out(mul_out)
    );


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lr_data_out <= 16'b0;
            lr_valid_out <= 0;
        end else begin
            // valid date coming through
            if (lr_valid_in) begin
                if (lr_data_in >= 0) begin // if positive, then pass through
                    lr_data_out <= lr_data_in;
                end
                else begin  // if negative,
                    lr_data_out <= mul_out;
                end
                lr_valid_out <= 1;
            end else begin
                lr_valid_out <= 0;
                lr_data_out <= 16'b0;
            end
        end
    end

endmodule
