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
        case (instruction[1:0])
            2'b00: begin
                activation_datapath = 2'b00;
            end
            2'b01: begin
                activation_datapath = 2'b01;
            end
            2'b10: begin
                activation_datapath = 2'b10;
            end
            2'b11: begin
                activation_datapath = 2'b11;
            end
        endcase

        case (instruction[4:2])
            3'b000: begin
                nn_start = 0;
                load_inputs = 0;
                load_weights = 0;
            end
            3'b001: begin
                nn_start = 1;
                load_inputs = 0;
                load_weights = 0;
            end
            3'b010: begin
                nn_start = 0;
                load_inputs = 1;
                load_weights = 0;
            end
            3'b011: begin
                nn_start = 1;
                load_inputs = 1;
                load_weights = 0;
            end
            3'b100: begin
                nn_start = 0;
                load_inputs = 0;
                load_weights = 1;
            end
            3'b101: begin
                nn_start = 1;
                load_inputs = 0;
                load_weights = 1;
            end
            3'b110: begin
                nn_start = 0;
                load_inputs = 1;
                load_weights = 1;
            end
            3'b111: begin
                nn_start = 1;
                load_inputs = 1;
                load_weights = 1;
        end
    endcase
end



endmodule