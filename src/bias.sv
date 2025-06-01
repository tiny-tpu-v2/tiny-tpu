`timescale 1ns/1ps
`default_nettype none

module bias (
    input logic bias_switch_in, // brings bias from inactive to active

    input logic clk,
    input logic rst,
    input logic load_bias_in, // global signal for loading biases
    input logic bias_valid_in,
    input logic signed [15:0] bias_scalar_in, // THIS IS THE ACTUAL BIAS DATA
    output logic bias_valid_out,
    input wire signed [15:0] bias_sys_data_in, // THIS IS THE DATA COMING FROM THE SYS!!!
    
    output logic signed [15:0] bias_data_out,
    output logic signed [15:0] bias_scalar_out,

    input logic bias_backward
);

    logic signed [15:0] add_out;

    logic signed [15:0] bias_inactive;
    logic signed [15:0] bias_active;


    fxp_add add_inst(
        .ina(bias_sys_data_in), // THIS IS THE SYS DATA!!!  
        .inb(bias_active),
        .out(add_out)
    );

    always_comb begin
        if (bias_switch_in) begin
            bias_active = bias_inactive; 
        end
        if(bias_backward) begin
            bias_data_out = bias_sys_data_in;
            bias_valid_out = bias_valid_in;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            bias_data_out <= 0;
            bias_inactive <= 0; 
        end else if (!bias_backward) begin
            bias_valid_out <= bias_valid_in;
            if (load_bias_in) begin
                bias_inactive <= bias_scalar_in;  
                bias_scalar_out <= bias_scalar_in;
            end 
            if (bias_valid_in) begin
                bias_data_out <= add_out;
            end
        end
    end

endmodule