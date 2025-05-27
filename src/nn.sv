`timescale 1ns/1ps
`default_nettype none

module nn (
    input logic clk,
    input logic rst,

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
    input logic nn_valid_in_2,

    input logic [37:0] instruction,

    output logic signed [15:0] nn_data_out_1,
    output logic signed [15:0] nn_data_out_2
    
);

    logic signed [15:0] input_11;   // Connections from accumulator 1 to systolic array pe11
    logic signed [15:0] input_21;   // Connections from accumulator 2 to systolic array pe21

    logic signed[15:0] lr_data_out_1;    // Connections from leaky relu 1 to accumulator 1
    logic signed[15:0] lr_data_out_2;    // Connections from leaky relu 2 to accumulator 2

    logic signed [15:0] sys_data_out_21;        // Connections from systolic array pe21 to bias 1
    logic signed [15:0] sys_data_out_22;        // Connections from systolic array pe22 to bias 2

    logic signed [15:0] out_21_bias;        // Connections from bias 1 to leaky relu 1
    logic signed [15:0] out_22_bias;        // Connections from bias 2 to leaky relu 2

    logic signed [15:0] acc_data_in_1;
    logic signed [15:0] acc_data_in_2;

    // Below are wires which connect the valid signals from systolic array to bias and leaky relu modules
    logic sys_valid_out_21;        // Valid signal from systolic array pe21 to bias 1
    logic sys_valid_out_22;        // Valid signal from systolic array pe22 to bias 2

    logic bias_valid_out_21;        // Valid signal from bias 1 to leaky relu 1
    logic bias_valid_out_22;        // Valid signal from bias 2 to leaky relu 2

    logic lr_valid_out_21; // Valid signal from leaky relu 1 to accumulator 1
    logic lr_valid_out_22; // Valid signal from leaky relu 2 to accumulator 2
    
    logic acc_valid_out_1; // Valid signal from accumulator 1 to systolic array pe11
    logic acc_valid_out_2; // Valid signal from accumulator 2 to systolic array pe21

    logic input_acc_vaid_data_nn_in_1;
    logic input_acc_vaid_data_nn_in_2;

    logic load_inputs;
    logic load_weights;
    logic load_bias;
    logic nn_start;
    logic [1:0] activation_datapath;  // routing the activation output to either the accumulator or the output wire
    logic [1:0] address; // address of the accumulator to which the input/weight/bias data is routed
    logic signed [15:0] input_data_in; // input data to the accumulator


    wire sys_switch_out_21; // need to route this to bias unit
    wire sys_switch_out_22; // need to route this to bias unit


    
    accumulator acc_1 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(nn_start),
        .acc_valid_data_in(lr_valid_out_21),
        .acc_data_in(acc_data_in_1),
        .acc_data_nn_in(input_data_in),
        .acc_valid_data_nn_in(input_acc_vaid_data_nn_in_1),
        .acc_valid_out(acc_valid_out_1),
        .acc_data_out(input_11)
    );

    accumulator acc_2 (
        .clk(clk),
        .rst(rst),
        .acc_valid_in(acc_valid_out_1),
        .acc_valid_data_in(lr_valid_out_22),
        .acc_data_in(lr_data_out_2),
        .acc_data_nn_in(input_data_in),
        .acc_valid_data_nn_in(input_acc_vaid_data_nn_in_2),
        .acc_valid_out(acc_valid_out_2),
        .acc_data_out(input_21)
    );

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .sys_start(acc_valid_out_1),
        .sys_valid_load_weights(load_weights),
        .sys_data_in_11(input_11),
        .sys_data_in_12(input_21),

        .sys_temp_weight_11(nn_temp_weight_11),
        .sys_temp_weight_12(nn_temp_weight_12),
        .sys_temp_weight_21(nn_temp_weight_21),
        .sys_temp_weight_22(nn_temp_weight_22),

        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),

        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22),
        .switch_out_21(sys_switch_out_21), 
        .switch_out_22(sys_switch_out_22)
    );

    bias bias_21 (
        .clk(clk),
        .rst(rst),
        .bias_switch_in(sys_switch_out_21),
        .load_bias(load_bias),
        .bias_data_in(sys_data_out_21),
        .bias_temp_bias(nn_temp_bias_1), 
        .bias_data_out(out_21_bias),

        .bias_valid_in(sys_valid_out_21),
        .bias_valid_out(bias_valid_out_21)
    );

    bias bias_22 (
        .clk(clk),
        .rst(rst),
        .bias_switch_in(sys_switch_out_22),
        .load_bias(load_bias),
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
        .lr_data_out(lr_data_out_1),

        .lr_valid_in(bias_valid_out_21),
        .lr_valid_out(lr_valid_out_21)
    );

    leaky_relu leaky_relu_22 (
        .clk(clk),
        .rst(rst),
        .lr_data_in(out_22_bias),
        .lr_temp_leak_factor(nn_temp_leak_factor),
        .lr_data_out(lr_data_out_2),

        .lr_valid_in(bias_valid_out_22),
        .lr_valid_out(lr_valid_out_22)
    );

    control_unit control_unit_inst (
        .instruction(instruction),
        .activation_datapath(activation_datapath),
        .nn_start(nn_start),
        .load_inputs(load_inputs),
        .load_weights(load_weights),
        .load_bias(load_bias),
        .address(address),
        .input_data_in(input_data_in)
    );

    // Accumulator input control
    always_comb begin
    
        acc_data_in_1 = activation_datapath[0] ? lr_data_out_1 : 16'b0;
        acc_data_in_2 = activation_datapath[0] ? lr_data_out_2 : 16'b0;
    end

    // Neural network output control
    always_comb begin
        nn_data_out_1 = activation_datapath[1] ? lr_data_out_1 : 16'b0;
        nn_data_out_2 = activation_datapath[1] ? lr_data_out_2 : 16'b0;
    end

    always_comb begin

        // routing input data to specific accumulators based on address and load_inputs flag
        input_acc_vaid_data_nn_in_1 = 0;
        input_acc_vaid_data_nn_in_2 = 0;
        if (load_inputs) begin
            case (address)
                2'b00: begin
                    input_acc_vaid_data_nn_in_1 = 0;
                    input_acc_vaid_data_nn_in_2 = 0;
                end
                2'b01: begin
                    input_acc_vaid_data_nn_in_1 = 1;
                end
                2'b10: begin
                    input_acc_vaid_data_nn_in_2 = 1;
                end
            endcase
        end

        // ADD SIMILAR LOGIC AS INPUTS FOR WEIGHTS AND BIAS ONCE ACCUMULATORS ARE DONE

    end

endmodule

