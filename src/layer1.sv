module layer1 (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weights,

    input logic signed [15:0] input_11,
    input logic signed [15:0] input_21,

    input logic signed [15:0] weight_11,
    input logic signed [15:0] weight_12,
    input logic signed [15:0] weight_21,
    input logic signed [15:0] weight_22,

    input logic signed [15:0] in_bias_21,
    input logic signed [15:0] in_bias_22,

    input logic signed[15:0] leak_factor, 

    output logic signed[15:0] out1,
    output logic signed[15:0] out2
);

    logic signed [15:0] out_21;
    logic signed [15:0] out_22;

    logic signed [15:0] out_21_bias;
    logic signed [15:0] out_22_bias; 

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .load_weights(load_weights),

        .input_11(input_11),
        .input_21(input_21),

        .weight_11(weight_11),
        .weight_12(weight_12),
        .weight_21(weight_21),
        .weight_22(weight_22),
        .out_21(out_21),
        .out_22(out_22)
    );

    bias bias_21 (
        .clk(clk),
        .rst(rst),
        .input_in(out_21),
        .bias_in(in_bias_21), 
        .output_out(out_21_bias) 
    );

    bias bias_22 (
        .clk(clk),
        .rst(rst),
        .input_in(out_22),
        .bias_in(in_bias_22),
        .output_out(out_22_bias)
    );

    leaky_relu leaky_relu_21 (
        .clk(clk),
        .rst(rst),
        .input_in(out_21_bias),
        .leak_factor(leak_factor),
        .out(out1)
    );

    leaky_relu leaky_relu_22 (
        .clk(clk),
        .rst(rst),
        .input_in(out_22_bias),
        .leak_factor(leak_factor),
        .out(out2)
    );

endmodule

