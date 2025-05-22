module nn (
    input logic clk,
    input logic rst,

    // MODULE FLAGS
    input logic nn_start,
    input logic nn_valid_load_weights,

    // START OF TEMPORARY CONSTANTS
    input logic signed [15:0] nn_temp_weight_11,
    input logic signed [15:0] nn_temp_weight_12,
    input logic signed [15:0] nn_temp_weight_21,
    input logic signed [15:0] nn_temp_weight_22,

    input logic signed [15:0] nn_temp_bias_1,
    input logic signed [15:0] nn_temp_bias_2,

    input logic signed [15:0] nn_temp_leak_factor,
    // END OF TEMPORARY CONSTANTS

    input logic signed [15:0] nn_data_in_1,
    input logic signed [15:0] nn_data_in_2,

    input logic nn_valid_in_1,
    input logic nn_valid_in_2
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
    logic sys_valid_out_21;        // Valid signal from systolic array pe21 to bias 1
    logic sys_valid_out_22;        // Valid signal from systolic array pe22 to bias 2

    logic bias_valid_out_21;        // Valid signal from bias 1 to leaky relu 1
    logic bias_valid_out_22;        // Valid signal from bias 2 to leaky relu 2

    logic lr_valid_out_21; // Valid signal from leaky relu 1 to accumulator 1
    logic lr_valid_out_22; // Valid signal from leaky relu 2 to accumulator 2
    
    logic acc_valid_out_1; // Valid signal from accumulator 1 to systolic array pe11
    logic acc_valid_out_2; // Valid signal from accumulator 2 to systolic array pe21


    accumulator acc_1 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(nn_start),
        .acc_valid_data_in(lr_valid_out_21),
        .acc_data_in(lr_data_out1),
        .acc_data_nn_in(nn_data_in_1),
        .acc_valid_data_nn_in(nn_valid_in_1),
        .acc_valid_out(acc_valid_out_1),
        .acc_data_out(input_11)
    );

    accumulator acc_2 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(acc_valid_out_1),
        .acc_valid_data_in(lr_valid_out_22),
        .acc_data_in(lr_data_out2),
        .acc_data_nn_in(nn_data_in_2),
        .acc_valid_data_nn_in(nn_valid_in_2),
        .acc_valid_out(acc_valid_out_2),
        .acc_data_out(input_21)
    );

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .sys_start(acc_valid_out_1),
        .sys_valid_load_weights(nn_valid_load_weights),

        .sys_data_in_11(input_11),
        .sys_data_in_12(input_21),

        .sys_temp_weight_11(nn_temp_weight_11),
        .sys_temp_weight_12(nn_temp_weight_12),
        .sys_temp_weight_21(nn_temp_weight_21),
        .sys_temp_weight_22(nn_temp_weight_22),

        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),

        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22)
    );

    bias bias_21 (
        .clk(clk),
        .rst(rst),
        .bias_data_in(sys_data_out_21),
        .bias_temp_bias(nn_temp_bias_1), 
        .bias_data_out(out_21_bias),

        .bias_valid_in(sys_valid_out_21),
        .bias_valid_out(bias_valid_out_21)
    );

    bias bias_22 (
        .clk(clk),
        .rst(rst),
        .bias_data_in(sys_data_out_22),
        .bias_temp_bias(nn_temp_bias_2),
        .bias_data_out(out_22_bias),

        .bias_valid_in(sys_valid_out_22),
        .bias_valid_out(bias_valid_out_22)
    );

    leaky_relu leaky_relu_21 (
        .clk(clk),
        .rst(rst),
        .lr_data_in(out_21_bias),
        .lr_temp_leak_factor(nn_temp_leak_factor),
        .lr_data_out(lr_data_out1),

        .lr_valid_in(bias_valid_out_21),
        .lr_valid_out(lr_valid_out_21)
    );

    leaky_relu leaky_relu_22 (
        .clk(clk),
        .rst(rst),
        .lr_data_in(out_22_bias),
        .lr_temp_leak_factor(nn_temp_leak_factor),
        .lr_data_out(lr_data_out2),

        .lr_valid_in(bias_valid_out_22),
        .lr_valid_out(lr_valid_out_22)
    );

endmodule

