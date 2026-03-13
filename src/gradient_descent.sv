`timescale 1ns/1ps
`default_nettype none

module gradient_descent (
    input logic clk,
    input logic rst,

    // learning rate
    input logic signed [15:0] lr_in,

    // old weight
    input logic signed [15:0] value_old_in,

    // gradient
    input logic signed [15:0] grad_in,

    // start signal
    input logic grad_descent_valid_in,

    // bias or weight
    input logic grad_bias_or_weight,

    // updated weight and done signal
    output logic signed [15:0] value_updated_out,
    output logic grad_descent_done_out,
    output logic grad_overflow_out  // BUG-OVF-1 fix: sticky arithmetic overflow flag
);

    logic signed [15:0] sub_value_out;
    logic grad_descent_in_reg;
    logic signed [15:0] sub_in_a;
    logic signed [15:0] mul_out;
    logic mul_overflow, sub_overflow;  // BUG-OVF-1 fix

    fxp_mul mul_inst (
        .ina(grad_in),
        .inb(lr_in),
        .out(mul_out),
        .overflow(mul_overflow)
    );

    fxp_addsub sub_inst (
        .ina(sub_in_a),
        .inb(mul_out),
        .sub(1'b1),
        .out(sub_value_out),
        .overflow(sub_overflow)
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
            value_updated_out   <= '0;
            grad_descent_done_out <= '0;
            grad_overflow_out   <= '0;
        end else begin
            grad_descent_done_out <= grad_descent_valid_in;
            if(grad_descent_valid_in) begin
                value_updated_out <= sub_value_out;
                grad_overflow_out <= grad_overflow_out | mul_overflow | sub_overflow; // sticky
            end
            // BUG-GD-1 fix: hold value_updated_out when not updating so the
            // accumulated bias result is not lost before writeback completes
        end
    end


endmodule