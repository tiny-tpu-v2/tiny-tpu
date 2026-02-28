`timescale 1ns/1ps
`default_nettype none

module gradient_descent (
    input wire clk,
    input wire rst,

    // learning rate
    input wire [15:0] lr_in,

    // old weight
    input wire [15:0] value_old_in,

    // gradient
    input wire [15:0] grad_in,

    // start signal
    input wire grad_descent_valid_in,

    // bias or weight
    input wire grad_bias_or_weight,

    // updated weight and done signal
    output reg [15:0] value_updated_out,
    output reg grad_descent_done_out
);

    wire [15:0] sub_value_out;
    reg grad_descent_in_reg;
    reg [15:0] sub_in_a;
    wire [15:0] mul_out;

    fxp_mul mul_inst (
        .ina(grad_in),
        .inb(lr_in),
        .out(mul_out),
        .overflow()
    );

    fxp_addsub sub_inst (
        .ina(sub_in_a),
        .inb(mul_out),
        .sub(1'b1),
        .out(sub_value_out),
        .overflow()
    );

    always @(*) begin
        case(grad_bias_or_weight)
            1'b0: begin
                if(grad_descent_done_out) begin
                    sub_in_a = value_updated_out;
                end else begin
                    sub_in_a = value_old_in;
                end
            end

            1'b1: begin
                sub_in_a = value_old_in;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            value_updated_out <= 16'b0;
            grad_descent_done_out <= 1'b0;
        end else begin
            grad_descent_done_out <= grad_descent_valid_in;
            if(grad_descent_valid_in) begin
                value_updated_out <= sub_value_out;
            end else begin
                value_updated_out <= 16'b0;
            end
        end
    end


endmodule
