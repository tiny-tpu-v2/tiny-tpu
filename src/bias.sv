`timescale 1ns/1ps
`default_nettype none

module bias (
    input logic bias_switch_in, // brings bias from inactive to active
    input logic clk,
    input logic rst,

    input wire signed [15:0] bias_sys_data_in, // data from systolic array
    input logic bias_valid_in, // valid data from systolic array?
    output logic bias_valid_out, // propogate signal forward for cascading

    input logic load_bias_in, // global signal for loading biases into internal registers
    input logic signed [15:0] bias_scalar_in, // bias value
    output logic signed [15:0] bias_scalar_out // cascaded bias value
    
    output logic signed [15:0] bias_data_out, // y + b output
    input logic bias_backward,
);

    // internal registers
    logic signed [15:0] bias_inactive; // connects to bias_scalar_in
    logic signed [15:0] bias_active;
    logic signed [15:0] add_out; // connects bias_data_out (real output signal)


    fxp_add add_inst(
        .ina(bias_sys_data_in), // THIS IS THE SYS DATA!!!  
        .inb(bias_active),
        .out(add_out)
    );

    always_comb begin
        if (bias_switch_in) begin
            bias_active = bias_inactive; 
        end 
    end

    always @(posedge clk) begin
        if (rst) begin
            bias_data_out <= 0;
            bias_inactive <= 0; 
        end 
        else begin
            bias_valid_out <= bias_valid_in;

            if (load_bias_in) begin // loading bias value
                // propogate into inactive register, and out to next bias module
                bias_inactive <= bias_scalar_in;  
                bias_scalar_out <= bias_scalar_in;
            end

            // valid data coming through?
            if (bias_valid_in) begin
                bias_data_out <= add_out;
            end

            else if(bias_backward) begin
                bias_data_out <= bias_sys_data_in;
            end
            
        end
    end

endmodule