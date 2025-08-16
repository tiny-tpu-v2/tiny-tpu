`timescale 1ns/1ps
`default_nettype none

module pe #(
    parameter int DATA_WIDTH = 16 //TODO: remove? we're not using this yet, lol)
) (
    input logic clk,
    input logic rst,

    // North wires of PE
    input logic signed [15:0] pe_psum_in, 
    input logic signed [15:0] pe_weight_in,
    input logic pe_accept_w_in, 
    
    // West wires of PE
    input logic signed [15:0] pe_input_in, 
    input logic pe_valid_in, 
    input logic pe_switch_in, 
    input logic pe_enabled,

    // South wires of the PE
    output logic signed [15:0] pe_psum_out,
    output logic signed [15:0] pe_weight_out,

    // East wires of the PE
    output logic signed [15:0] pe_input_out,
    output logic pe_valid_out,
    output logic pe_switch_out
);

    logic signed [15:0] mult_out;
    wire signed [15:0] mac_out; // just a wire
    logic signed [15:0] weight_reg_active; // foreground register
    logic signed[15:0] weight_reg_inactive; // background register

    fxp_mul mult (
        .ina(pe_input_in),
        .inb(weight_reg_active),
        .out(mult_out),
        .overflow()
    );

    fxp_add adder (
        .ina(mult_out),
        .inb(pe_psum_in),
        .out(mac_out),
        .overflow()
    );

    // Only the switch flag is combinational (active register copies inactive register on the same clock cycle that switch flag is set)
    // That means inputs from the left side of the PE can load in on the same clock cycle that the switch flag is set
    always_comb begin
        if (pe_switch_in) begin
            weight_reg_active = weight_reg_inactive;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || !pe_enabled) begin
            pe_input_out <= 16'b0;
            weight_reg_active <= 16'b0;
            weight_reg_inactive <= 16'b0;
            pe_valid_out <= 0;
            pe_weight_out <= 16'b0;
            pe_switch_out <= 0;
        end else begin
            pe_valid_out <= pe_valid_in;
            pe_switch_out <= pe_switch_in;
            
            // Weight register updates - only on clock edges
            if (pe_accept_w_in) begin
                weight_reg_inactive <= pe_weight_in;
                pe_weight_out <= pe_weight_in;
            end else begin
                pe_weight_out <= 0;
            end

            if (pe_valid_in) begin
                pe_input_out <= pe_input_in;
                pe_psum_out <= mac_out;
            end else begin
                pe_valid_out <= 0;
                pe_psum_out <= 16'b0;
            end

        end
    end

endmodule