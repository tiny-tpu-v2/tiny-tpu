`timescale 1ns/1ps
`default_nettype none


// 3x3 systolic array
module systolic (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weights,
    
    input logic [15:0] input_11,
    input logic [15:0] input_21,

    input logic [15:0] weight_11,
    input logic [15:0] weight_12,
    input logic [15:0] weight_21,
    input logic [15:0] weight_22,


    output logic [15:0] out_21,
    output logic [15:0] out_22,
    output logic done
);
    // Zero signals
    wire [15:0] zero_wire_inputs;
    wire [15:0] zero_wire_outputs;

    assign zero_wire_inputs = 16'b0;
    assign zero_wire_outputs = 16'b0;

    // input_out for each PE
    logic [15:0] input_11_out;
    logic [15:0] input_21_out;

    // psum_out for each PE
    logic [15:0] psum_11;
    logic [15:0] psum_12;

    // Done signal logic
    assign done = 1'b0; // You'll need to implement proper done logic based on your requirements

    pe pe11 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_11),
        .psum_in(zero_wire_inputs),
        .weight(weight_11),
        .load_weight(load_weights),
        .input_out(input_11_out),
        .psum_out(psum_11)
    );

    pe pe12 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_11_out),
        .psum_in(zero_wire_inputs),
        .weight(weight_12),
        .load_weight(load_weights),
        .input_out(zero_wire_outputs),
        .psum_out(psum_12)
    );

    pe pe21 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_21),
        .psum_in(psum_11),
        .weight(weight_21),
        .load_weight(load_weights),
        .input_out(input_21_out),
        .psum_out(out_21)
    );

    pe pe22 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_21_out),
        .psum_in(psum_12),
        .weight(weight_22),
        .load_weight(load_weights),
        .input_out(zero_wire_outputs),
        .psum_out(out_22)
    );

endmodule
