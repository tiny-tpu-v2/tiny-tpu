`timescale 1ns/1ps
`default_nettype none

module control_unit (
    input logic [5:0] instruction,
    output logic [1:0] activation_datapath,
    output logic nn_start,
    output logic load_inputs,
    output logic load_weights,
    output logic load_bias
);

always_comb begin

    nn_start = 0;
    load_inputs = 0;
    load_weights = 0;
    load_bias = 0;
    activation_datapath = instruction[1:0]; // routes the activation output to either the accumulator or the output wire
    nn_start = instruction[2]; // start signal for the accumulator
    load_inputs = instruction[3]; // load inputs into the accumulator
    load_weights = instruction[4]; // load weights into the systolic array
    load_bias = instruction[5]; // load bias into the bias module
    
end
endmodule