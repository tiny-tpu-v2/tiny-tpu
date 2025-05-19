module layer1 (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weights,
    input logic [15:0] input_11,
    input logic [15:0] input_21,
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
    output logic [15:0] out_33
);

    logic [15:0] out_31_preact;
    logic [15:0] out_32_preact;
    logic [15:0] out_33_preact;

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .load_weights(load_weights),
        .input_11(16'b0),
        .input_21(input_11),
        .input_31(input_21),
        .weight_11(16'b0),
        .weight_12(16'b0),
        .weight_13(16'b0),
        .weight_21(weight_21),
        .weight_22(weight_22),
        .weight_23(weight_23),
        .weight_31(weight_31),
        .weight_32(weight_32),
        .weight_33(weight_33),
        .out_31(out_31_preact),
        .out_32(out_32_preact),
        .out_33(out_33_preact)
    );

    leaky_relu leaky_relu_31 (
        .clk(clk),
        .rst(rst),
        .input_in(out_31_preact),
        .leak_factor(16'b0000000000000010),
        .out(out_31)
    );

    leaky_relu leaky_relu_32 (
        .clk(clk),
        .rst(rst),
        .input_in(out_32_preact),
        .leak_factor(16'b0000000000000010),
        .out(out_32)
    );

    leaky_relu leaky_relu_33 (
        .clk(clk),
        .rst(rst),
        .input_in(out_33_preact),
        .leak_factor(16'b0000000000000010),
        .out(out_33)
    );

endmodule

