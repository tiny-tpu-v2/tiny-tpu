`timescale 1ns/1ps
`default_nettype none

module gradient_descent (
    input logic clk,
    input logic rst,

    // learning rate
    input logic [15:0] lr_in,

    // old weight
    input logic [15:0] value_old_in,

    // gradient
    input logic [15:0] grad_in,

    // start signal
    input logic grad_descent_valid_in,

    // bias or weight
    input logic grad_bias_or_weight,

    // updated weight and done signal
    output logic [15:0] value_updated_out,
    output logic grad_descent_done_out
);

    logic [15:0] sub_value_out;
    logic grad_descent_in_reg;
    logic [15:0] sub_in_a;
    logic [15:0] mul_out;

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

    always_comb begin
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

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            sub_in_a <= '0;
            value_updated_out <= '0;
            grad_descent_done_out <= '0;
        end else begin
            grad_descent_done_out <= grad_descent_valid_in;
            if(grad_descent_valid_in) begin
                value_updated_out <= sub_value_out;
            end else begin
                value_updated_out <= '0;
            end
        end
    end


endmodule