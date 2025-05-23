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

always @(*) begin
    activation_datapath = instruction[1:0];

    nn_start = 0;
    load_inputs = 0;
    load_weights = 0;

    if(instruction[2]) begin
        nn_start = 1;
    end
    if(instruction[3]) begin
        load_inputs = 1;
    end
    if(instruction[4]) begin
        load_weights = 1;
    end
end



endmodule