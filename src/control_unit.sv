`timescale 1ns/1ps
`default_nettype none

module control_unit (
    // input logic clk,
    // input logic rst,
    input logic [4:0] instruction,
    output logic [1:0] activation_datapath,
    output logic nn_start,
    output logic load_inputs,
    output logic load_weights
);

always_comb begin
    activation_datapath = instruction[1:0];

    nn_start = 0;
    load_inputs = 0;
    load_weights = 0;
    
    nn_start = instruction[2];
    load_inputs = instruction[3];
    load_weights = instruction[4];
end
endmodule