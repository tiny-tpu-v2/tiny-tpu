`timescale 1ns/1ps
`default_nettype none

module bias_child (
    input logic clk,
    input logic rst,

    input logic signed [15:0] bias_scalar_in, // bias scalars fetched from the unified buffer (rename it to bias_scalar_ub_in)
    output logic bias_Z_valid_out, 
    input wire signed [15:0] bias_sys_data_in, // data from systolic array
    input wire bias_sys_valid_in, // valid signal from the systolic array

    output logic signed [15:0] bias_z_data_out
);
    // output of the bias operation
    logic signed [15:0] z_pre_activation; 

    fxp_add add_inst(
        .ina(bias_sys_data_in),
        .inb(bias_scalar_in),
        .out(z_pre_activation)
    );
    // TODO: we only switch bias values for EACH layer!!!! maybe change logic herer

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bias_Z_valid_out <= 1'b0; // reset the output valid signal
            bias_z_data_out <= 16'b0; // reset the output data
        end else begin
            if (bias_sys_valid_in) begin // valid data coming through
                bias_Z_valid_out <= 1'b1;
                bias_z_data_out <= z_pre_activation; // output of the bias operation
            end else begin
                bias_Z_valid_out <= 1'b0; // output is invalid otherwise
                bias_z_data_out <= 16'b0; // reset the output data
            end
        end
    end

endmodule