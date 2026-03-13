`timescale 1ns/1ps
`default_nettype none

module bias_child (
    input logic clk,
    input logic rst,

    input logic signed [15:0] bias_scalar_in, // bias scalars fetched from the unified buffer (rename it to bias_scalar_ub_in)
    output logic bias_Z_valid_out, 
    input wire signed [15:0] bias_sys_data_in, // data from systolic array
    input wire bias_sys_valid_in, // valid signal from the systolic array

    output logic signed [15:0] bias_z_data_out,
    output logic bias_overflow_out  // BUG-OVF-1 fix: sticky arithmetic overflow flag
);
    // output of the bias operation
    logic signed [15:0] z_pre_activation;
    logic add_overflow;  // BUG-OVF-1 fix

    fxp_add add_inst(
        .ina(bias_sys_data_in),
        .inb(bias_scalar_in),
        .out(z_pre_activation),
        .overflow(add_overflow)
    );
    // TODO: we only switch bias values for EACH layer!!!! maybe change logic herer

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            bias_Z_valid_out <= 1'b0;
            bias_z_data_out  <= 16'b0;
            bias_overflow_out <= 1'b0;
        end else begin
            if (bias_sys_valid_in) begin
                bias_Z_valid_out  <= 1'b1;
                bias_z_data_out   <= z_pre_activation;
                bias_overflow_out <= bias_overflow_out | add_overflow; // sticky
            end else begin
                bias_Z_valid_out  <= 1'b0;
                bias_z_data_out   <= 16'b0;
            end
        end
    end

endmodule