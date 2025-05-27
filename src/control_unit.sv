`timescale 1ns/1ps
`default_nettype none


// INSTRUCTION FORMAT:
// 23 - nn_start
// 22 - accept_w
// 21 - switch
// 20:19 - activation_datapath
// 18:17 - load_weights, load_bias, load_inputs
// 16 - address
// 15:0 - data_in

module control_unit (
    input logic [23:0] instruction,
    output logic [1:0] activation_datapath,
    output logic nn_start,
    output logic accept_w, // dequeue weight from FIFO
    output logic switch,
    output logic load_bias, 
    output logic load_inputs,
    output logic load_weights, // enqueue weight in FIFO
    output logic [15:0] data_in,
    output logic address
);

always @(*)begin
    
    nn_start = instruction[23];
    accept_w = instruction[22];
    switch = instruction[21];
    activation_datapath = instruction[20:19]; // routes the activation output to either the accumulator or the output wire
    address = instruction[16];
    data_in = instruction[15:0];

    // Default assignments for load signals
    load_weights = 1'b0;
    load_bias = 1'b0;
    load_inputs = 1'b0;

    case (instruction[18:17]) 
        2'b00: begin
            // All load signals remain 0 (as per default)
        end
        2'b01: begin
            load_inputs = 1'b1;
        end
        2'b10: begin
            load_bias = 1'b1;
        end
        2'b11: begin
            load_weights = 1'b1;
        end
    endcase
end
endmodule