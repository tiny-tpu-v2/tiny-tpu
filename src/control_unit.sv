`timescale 1ns/1ps
`default_nettype none


// INSTRUCTION FORMAT:
// 22 - nn_start
// 21:20 - address
// 19:4 - weight_data_in
// 3:2 - load_weights, load_bias, load_inputs
// 1:0 - activation_datapath

module control_unit (
    input logic [22:0] instruction,
    output logic [1:0] activation_datapath,
    output logic nn_start,
    output logic load_weights,
    output logic load_bias,
    output logic load_inputs,
    output logic [15:0] weight_data_in,
    output logic [15:0] input_data_in,
    output logic [15:0] bias_data_in,
    output logic [1:0] address
);

always_comb begin

    activation_datapath = instruction[1:0]; // routes the activation output to either the accumulator or the output wire
    nn_start = instruction[22];
    address = instruction[21:20];

    case (instruction[3:2]) 
        2'b00: begin
            load_weights = 0;
            load_bias = 0;
            load_inputs = 0;
            // weight_data_in = 0;
            // bias_data_in = 0;
        end
        2'b01: begin
            load_weights = 1;
            // weight_data_in = instruction[19:4];
        end
        2'b10: begin
            load_bias = 1;
            // bias_data_in = instruction[19:4];
        end
        2'b11: begin
            load_inputs = 1;
            input_data_in = instruction[19:4];
        end
    endcase
end
endmodule