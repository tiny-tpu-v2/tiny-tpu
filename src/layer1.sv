module layer1 (
    input logic clk,
    input logic rst,
    input logic start,
    input logic load_weights,

    input logic signed [15:0] weight_11,
    input logic signed [15:0] weight_12,
    input logic signed [15:0] weight_21,
    input logic signed [15:0] weight_22,

    input logic signed [15:0] in_bias_21,
    input logic signed [15:0] in_bias_22,

    input logic signed[15:0] leak_factor,
    input logic valid_data_in,

    input logic signed [15:0] acc_data_nn_in1,
    input logic acc_valid_data_nn_in1,

    input logic signed [15:0] acc_data_nn_in2,
    input logic acc_valid_data_nn_in2
);

    logic signed [15:0] input_11;   // Connections from accumulator 1 to systolic array pe11
    logic signed [15:0] input_21;   // Connections from accumulator 2 to systolic array pe21

    logic signed[15:0] lr_data_out1;    // Connections from leaky relu 1 to accumulator 1
    logic signed[15:0] lr_data_out2;    // Connections from leaky relu 2 to accumulator 2

    logic signed [15:0] sys_data_out_21;        // Connections from systolic array pe21 to bias 1
    logic signed [15:0] sys_data_out_22;        // Connections from systolic array pe22 to bias 2

    logic signed [15:0] out_21_bias;        // Connections from bias 1 to leaky relu 1
    logic signed [15:0] out_22_bias;        // Connections from bias 2 to leaky relu 2

    // Below are wires which connect the valid signals from systolic array to bias and leaky relu modules
    logic valid_out_21;        // Valid signal from systolic array pe21 to bias 1
    logic valid_out_22;        // Valid signal from systolic array pe22 to bias 2

    logic bias_valid_out_21;        // Valid signal from bias 1 to leaky relu 1
    logic bias_valid_out_22;        // Valid signal from bias 2 to leaky relu 2

    logic lr_valid_out_21; // Valid signal from leaky relu 1 to accumulator 1
    logic lr_valid_out_22; // Valid signal from leaky relu 2 to accumulator 2
    
    logic acc_valid_out_1; // Valid signal from accumulator 1 to systolic array pe11
    logic acc_valid_out_2; // Valid signal from accumulator 2 to systolic array pe21

    // Define state type
 

    logic acc_valid_data_in_1;
    accumulator #(
        .ACC_WIDTH(1)
        // .INIT_VAL(16'b0000010100000000)
    ) acc_1 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(start),
        .acc_valid_data_in(lr_valid_out_21),
        .acc_data_in(lr_data_out1),
        .acc_data_nn_in(acc_data_nn_in1),
        .acc_valid_data_nn_in(acc_valid_data_nn_in1),
        .acc_valid_out(acc_valid_out_1),
        .acc_data_out(input_11)
    );

    accumulator #(
        .ACC_WIDTH(1)
        // .INIT_VAL(16'b0000011000000000)
    ) acc_2 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(acc_valid_out_1),
        .acc_valid_data_in(lr_valid_out_22),
        .acc_data_in(lr_data_out2),
        .acc_data_nn_in(acc_data_nn_in2),
        .acc_valid_data_nn_in(acc_valid_data_nn_in2),
        .acc_valid_out(acc_valid_out_2),
        .acc_data_out(input_21)
    );

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .start(acc_valid_out_1),
        .load_weights(load_weights),

        .input_11(input_11),
        .input_21(input_21),

        .weight_11(weight_11),
        .weight_12(weight_12),
        .weight_21(weight_21),
        .weight_22(weight_22),
        .out_21(sys_data_out_21),
        .out_22(sys_data_out_22),

        .valid_out_21(valid_out_21),
        .valid_out_22(valid_out_22)
    );

    bias bias_21 (
        .clk(clk),
        .rst(rst),
        .input_in(sys_data_out_21),
        .bias_in(in_bias_21), 
        .output_out(out_21_bias),

        .bias_valid_in(valid_out_21),
        .bias_valid_out(bias_valid_out_21)
    );

    bias bias_22 (
        .clk(clk),
        .rst(rst),
        .input_in(sys_data_out_22),
        .bias_in(in_bias_22),
        .output_out(out_22_bias),

        .bias_valid_in(valid_out_22),
        .bias_valid_out(bias_valid_out_22)
    );

    leaky_relu leaky_relu_21 (
        .clk(clk),
        .rst(rst),
        .input_in(out_21_bias),
        .leak_factor(leak_factor),
        .out(lr_data_out1),

        .lr_valid_in(bias_valid_out_21),
        .lr_valid_out(lr_valid_out_21)
    );

    leaky_relu leaky_relu_22 (
        .clk(clk),
        .rst(rst),
        .input_in(out_22_bias),
        .leak_factor(leak_factor),
        .out(lr_data_out2),

        .lr_valid_in(bias_valid_out_22),
        .lr_valid_out(lr_valid_out_22)
    );

endmodule

