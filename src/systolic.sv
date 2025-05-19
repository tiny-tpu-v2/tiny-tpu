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
    input logic [15:0] input_31,
    input logic [15:0] weight_11,
    input logic [15:0] weight_12,
    input logic [15:0] weight_13,
    input logic [15:0] weight_21,
    input logic [15:0] weight_22,
    input logic [15:0] weight_23,
    input logic [15:0] weight_31,
    input logic [15:0] weight_32,
    input logic [15:0] weight_33,
    output logic [15:0] out_31,
    output logic [15:0] out_32,
    output logic [15:0] out_33,
    output logic done
);

    // input_out for each PE
    logic [15:0] input_11_out;
    logic [15:0] input_12_out;
    logic [15:0] input_21_out;
    logic [15:0] input_22_out;
    logic [15:0] input_31_out;
    logic [15:0] input_32_out;

    // psum_out for each PE
    logic [15:0] psum_11;
    logic [15:0] psum_12;
    logic [15:0] psum_13;
    logic [15:0] psum_21;
    logic [15:0] psum_22;
    logic [15:0] psum_23;

    logic [15:0] zero_wire;
    logic [15:0] test_reg;
    assign zero_wire = 16'b0;

    pe pe11 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_11),
        .psum_in(zero_wire),
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
        .psum_in(zero_wire),
        .weight(weight_12),
        .load_weight(load_weights),
        .input_out(input_12_out),
        .psum_out(psum_12)
    );

    pe pe13 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_12_out),
        .psum_in(zero_wire),
        .weight(weight_13),
        .load_weight(load_weights),
        .input_out(),
        .psum_out(psum_13)
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
        .psum_out(psum_21)
    );

    pe pe22 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_21_out),
        .psum_in(psum_12),
        .weight(weight_22),
        .load_weight(load_weights),
        .input_out(input_22_out),
        .psum_out(psum_22)
    );

    pe pe23 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_22_out),
        .psum_in(psum_13),
        .weight(weight_23),
        .load_weight(load_weights),
        .input_out(),  
        .psum_out(psum_23)
    );

    pe pe31 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_31),
        .psum_in(psum_21),
        .weight(weight_31),
        .load_weight(load_weights),
        .input_out(input_31_out),
        .psum_out(out_31)
    );

    pe pe32 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_31_out),
        .psum_in(psum_22),
        .weight(weight_32),
        .load_weight(load_weights),
        .input_out(input_32_out),
        .psum_out(out_32)
    );

    pe pe33 (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_in(input_32_out),
        .psum_in(psum_23),
        .weight(weight_33),
        .load_weight(load_weights),
        .input_out(),
        .psum_out(out_33)
    );

endmodule
