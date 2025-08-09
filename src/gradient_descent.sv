`timescale 1ns/1ps
`default_nettype none

module gradient_descent (
    input logic clk,
    input logic rst,

    // learning rate
    input logic [15:0] lr_in,

    // old weight
    input logic [15:0] W_old_in,

    // gradient
    input logic [15:0] grad_in,

    // start signal
    input logic grad_descent_start_in,

    // updated weight and done signal
    output logic [15:0] W_updated_out,
    output logic grad_descent_done_out
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        W_updated_out <= 16'b0;
        grad_descent_done_out <= 0;
    end else begin
        if (grad_descent_start_in) begin
            W_updated_out <= W_old_in - lr_in * grad_in;
            grad_descent_done_out <= 1;
        end else begin
            grad_descent_done_out <= 0;
        end
    end
end

endmodule