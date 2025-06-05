`timescale 1ns/1ps
`default_nettype none

module nn (
    input logic clk,
    input logic rst,

    input logic [24:0] instruction,

    output logic signed [15:0] nn_data_out_1,
    output logic signed [15:0] nn_data_out_2,

    output logic nn_valid_out_1,
    output logic nn_valid_out_2
    
);

    assign nn_valid_out_1 = lr_valid_out_21;
    assign nn_valid_out_2 = lr_valid_out_22;

    logic signed [15:0] input_11;   // Connections from accumulator 1 to systolic array pe11
    logic signed [15:0] input_21;   // Connections from accumulator 2 to systolic array pe21

    logic signed[15:0] lr_data_out_1;    // Connections from leaky relu 1 to accumulator 1
    logic signed[15:0] lr_data_out_2;    // Connections from leaky relu 2 to accumulator 2

    logic signed [15:0] sys_data_out_21;        // Connections from systolic array pe21 to bias 1
    logic signed [15:0] sys_data_out_22;        // Connections from systolic array pe22 to bias 2

    logic sys_switch_out_21;
    logic sys_switch_out_22;

    logic signed [15:0] out_21_bias;        // Connections from bias 1 to leaky relu 1
    logic signed [15:0] out_22_bias;        // Connections from bias 2 to leaky relu 2

    logic signed [15:0] nn_data_in_1;
    logic signed [15:0] nn_data_in_2;

    logic signed [15:0] weight_acc_data_in_1;
    logic signed [15:0] weight_acc_data_in_2;
    logic signed [15:0] bias_temp_bias_in;

    logic signed [15:0] bias_temp_bias_out_1;

    logic signed [15:0] weight_11;
    logic signed [15:0] weight_12;

    logic signed [15:0] input_acc_data_in_1;
    logic signed [15:0] input_acc_data_in_2;

    logic signed [15:0] bias_data_out_1;
    logic signed [15:0] bias_data_out_2;


    logic input_acc_valid_out_1;    // Valid signal from accumulator 1 to systolic array pe11 and accumulator 2
    logic input_acc_valid_out_2;    // Valid signal from accumulator 2 to systolic array pe21
    logic weight_acc_valid_out_1;
    logic weight_acc_valid_out_2;
    logic bias_valid_out_1;
    logic bias_valid_out_2;
    

    // Below are wires which connect the valid signals from systolic array to bias and leaky relu modules
    logic sys_valid_out_21;        // Valid signal from systolic array pe21 to bias 1
    logic sys_valid_out_22;        // Valid signal from systolic array pe22 to bias 2

    logic bias_valid_out_21;        // Valid signal from bias 1 to leaky relu 1
    logic bias_valid_out_22;        // Valid signal from bias 2 to leaky relu 2

    logic lr_valid_out_21; // Valid signal from leaky relu 1 to accumulator 1
    logic lr_valid_out_22; // Valid signal from leaky relu 2 to accumulator 2

    logic load_inputs_1;
    logic load_inputs_2;
    logic load_weights_1;
    logic load_weights_2;
    logic load_bias;

    logic nn_start;
    logic accept_w;
    logic load_inputs;
    logic load_weights;
    logic switch;
    logic [1:0] activation_datapath;  // routing the activation output to either the accumulator or the output wire
    logic address; // address of the accumulator to which the input/weight/bias data is routed
    logic signed [15:0] data_in; // input data to the accumulator
    logic lr_is_backward; // IF 0 THEN BACKWARD MODE, IF 1 THEN FORWARD MDOE

    
    
    input_acc input_acc_1 (
        .clk(clk),
        .rst(rst),
        .input_acc_valid_in(nn_start),
        .input_acc_valid_data_in(lr_valid_out_21),
        .input_acc_data_in(input_acc_data_in_1),
        .input_acc_data_nn_in(nn_data_in_1),
        .input_acc_valid_data_nn_in(load_inputs_1),
        .input_acc_valid_out(input_acc_valid_out_1),
        .input_acc_data_out(input_11)
    );

    input_acc input_acc_2 (
        .clk(clk),
        .rst(rst),
        .input_acc_valid_in(input_acc_valid_out_1),
        .input_acc_valid_data_in(lr_valid_out_22),
        .input_acc_data_in(input_acc_data_in_2),
        .input_acc_data_nn_in(nn_data_in_2),
        .input_acc_valid_data_nn_in(load_inputs_2),
        .input_acc_valid_out(input_acc_valid_out_2),
        .input_acc_data_out(input_21)
    );

    weight_acc weight_acc_1 (
        .clk(clk),
        .rst(rst),
        .weight_acc_valid_in(accept_w),
        .weight_acc_valid_data_in(load_weights_1),
        .weight_acc_data_in(weight_acc_data_in_1),
        .weight_acc_valid_out(weight_acc_valid_out_1),
        .weight_acc_data_out(weight_11)
    );  
    
    weight_acc weight_acc_2 (
        .clk(clk),
        .rst(rst),
        .weight_acc_valid_in(weight_acc_valid_out_1),
        .weight_acc_valid_data_in(load_weights_2),
        .weight_acc_data_in(weight_acc_data_in_2),
        .weight_acc_valid_out(weight_acc_valid_out_2),
        .weight_acc_data_out(weight_12)
    );  

    systolic systolic_inst (
        .clk(clk),
        .rst(rst),
        .sys_start(input_acc_valid_out_1),
        .sys_accept_w_in(weight_acc_valid_out_1),
        .sys_switch_in(switch),
        .sys_data_in_11(input_11),
        .sys_data_in_21(input_21),
        .sys_weight_in_11(weight_11),
        .sys_weight_in_12(weight_12),

        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),

        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22),

        .sys_switch_out_21(sys_switch_out_21),
        .sys_switch_out_22(sys_switch_out_22)
    );

    bias bias_21 (
        .clk(clk),
        .rst(rst),
        .load_bias_in(load_bias),  
        .bias_sys_data_in(sys_data_out_21),
        .bias_switch_in(sys_switch_out_21),
        .bias_scalar_in(bias_temp_bias_in), 
        .bias_data_out(bias_data_out_1),
        .bias_scalar_out(bias_temp_bias_out_1),
        .bias_valid_in(sys_valid_out_21),
        .bias_valid_out(bias_valid_out_21)
    );

    bias bias_22 (
        .clk(clk),
        .rst(rst),
        .load_bias_in(load_bias),
        .bias_sys_data_in(sys_data_out_22),
        .bias_switch_in(sys_switch_out_22),
        .bias_scalar_in(bias_temp_bias_out_1),
        .bias_data_out(bias_data_out_2),
        .bias_scalar_out(),
        .bias_valid_in(sys_valid_out_22),
        .bias_valid_out(bias_valid_out_22)
    );

    leaky_relu leaky_relu_21 (
        .clk(clk),
        .rst(rst),
        .lr_data_in(bias_data_out_1),
        .lr_temp_leak_factor(16'b00000000_00000011),
        .lr_data_out(lr_data_out_1),

        .lr_valid_in(bias_valid_out_21),
        .lr_valid_out(lr_valid_out_21),
        .h_store_valid(activation_datapath[0]), // tie sys flag 
        .lr_is_backward(lr_is_backward)
    );

    leaky_relu leaky_relu_22 (
        .clk(clk),
        .rst(rst),
        .lr_data_in(bias_data_out_2),
        .lr_temp_leak_factor(16'b00000000_00000011),
        .lr_data_out(lr_data_out_2),

        .lr_valid_in(bias_valid_out_22),
        .lr_valid_out(lr_valid_out_22),
        .h_store_valid(activation_datapath[0]), // tie sys flag
        .lr_is_backward(lr_is_backward)
    );

    control_unit control_unit_inst (
        .instruction(instruction),
        .activation_datapath(activation_datapath),
        .nn_start(nn_start),
        .accept_w(accept_w),
        .switch(switch),
        .load_inputs(load_inputs),
        .load_weights(load_weights),
        .load_bias(load_bias),
        .address(address),
        .data_in(data_in),
        .lr_is_backward(lr_is_backward)
    );

    // Accumulator input control
    always @(*) begin
        input_acc_data_in_1 = activation_datapath[0] ? lr_data_out_1 : 16'b0;
        input_acc_data_in_2 = activation_datapath[0] ? lr_data_out_2 : 16'b0;
    end

    // Load control for weights, bias, and inputs
    always @(*) begin
        // Default assignments for all signals driven by this block
        nn_data_in_1 = 16'b0;
        load_inputs_1 = 1'b0;
        load_weights_1 = 1'b0;
        weight_acc_data_in_1 = 16'b0;

        nn_data_in_2 = 16'b0;
        load_inputs_2 = 1'b0;
        load_weights_2 = 1'b0;
        weight_acc_data_in_2 = 16'b0;

        bias_temp_bias_in = 16'b0; // Default for the input to the first bias unit

        // Main logic based on control signals
        if (!address) begin // address == 1, for acc1/weight_acc1 path
            if (load_inputs) begin
                nn_data_in_1 = data_in;
                load_inputs_1 = 1'b1;
            end else if (load_weights) begin
                weight_acc_data_in_1 = data_in;
                load_weights_1 = 1'b1;
            end
            // Note: load_bias handling for bias_temp_bias_in is common below
        end else begin // address == 0, for acc2/weight_acc2 path
            if (load_inputs) begin
                nn_data_in_2 = data_in;
                load_inputs_2 = 1'b1;
            end else if (load_weights) begin
                weight_acc_data_in_2 = data_in;
                load_weights_2 = 1'b1;
            end
            // Note: load_bias handling for bias_temp_bias_in is common below
        end

        // Common handling for bias loading:
        if (load_bias) begin
            bias_temp_bias_in = data_in;
        end
    end

    // Neural network output control
    always @(*) begin
        nn_data_out_1 = activation_datapath[1] ? lr_data_out_1 : 16'b0;
        nn_data_out_2 = activation_datapath[1] ? lr_data_out_2 : 16'b0;
    end


endmodule

