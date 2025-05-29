`timescale 1ns/1ps
`default_nettype none


// 2x2 systolic array
module systolic (
    input logic clk,
    input logic rst,
    input logic sys_start, // this only needs to be high for one clock cycle -- goes into the first top left PE
    input logic sys_switch_in,
    input logic sys_accept_w_in,
    
    input logic [15:0] sys_data_in_11,
    input logic [15:0] sys_data_in_21,

    input logic [15:0] sys_weight_in_11,
    input logic [15:0] sys_weight_in_12,
    // input logic [15:0] sys_temp_weight_21,
    // input logic [15:0] sys_temp_weight_22,

    output logic [15:0] sys_data_out_21,
    output logic [15:0] sys_data_out_22,

    output wire sys_valid_out_21, 
    output wire sys_valid_out_22,

    output wire sys_switch_out_21,
    output wire sys_switch_out_22
);
    // Zero signals
    wire [15:0] zero_wire_inputs;
    wire [15:0] zero_wire_outputs;

    assign zero_wire_inputs = 16'b0;
    assign zero_wire_outputs = 16'b0;

    // input_out for each PE
    logic [15:0] pe_input_out_11;
    logic [15:0] pe_input_out_21;

    // psum_out for each PE
    logic [15:0] pe_psum_out_11;
    logic [15:0] pe_psum_out_12;

    logic [15:0] pe_weight_out_11;
    logic [15:0] pe_weight_out_12;

    logic pe_switch_out_11;
    logic pe_switch_out_12;

    wire pe_valid_out_11; // this wire will connect the valid signal from pe11 to pe12 and pe21
    wire pe_valid_out_12;// this wire will connect the valid signal from pe12 to pe22

    wire pe_valid_out_21; // this wire will connect the valid signal from pe21 to the first OUTPUT
    wire pe_valid_out_22; // this wire will connect the valid signal from pe22 to the second OUTPUT

    assign sys_valid_out_21 = pe_valid_out_21; 
    assign sys_valid_out_22 = pe_valid_out_22; 

    logic sys_accept_w_out_1;

    pe pe11 (
        .clk(clk),
        .rst(rst),

        .pe_valid_in(sys_start),
        .pe_valid_out(pe_valid_out_11), // valid out signal is now dispatched onto pe_valid_out_11

        .pe_accept_w_in(sys_accept_w_in),
        .pe_switch_in(sys_switch_in),

        .pe_input_in(sys_data_in_11),
        .pe_psum_in(zero_wire_inputs),
        .pe_weight_in(sys_weight_in_11),
        .pe_input_out(pe_input_out_11),
        .pe_psum_out(pe_psum_out_11),
        .pe_weight_out(pe_weight_out_11),
        .pe_switch_out(pe_switch_out_11),
        .pe_accept_w_out(sys_accept_w_out_1)
    );

    pe pe12 (
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_11), // connect this to pe_valid out of pe11?
        .pe_valid_out(pe_valid_out_12), // now connect this to pe_valid in of pe22

        .pe_accept_w_in(sys_accept_w_out_1),
        .pe_switch_in(pe_switch_out_11),

        .pe_input_in(pe_input_out_11),
        .pe_psum_in(zero_wire_inputs),
        .pe_weight_in(sys_weight_in_12),
        .pe_input_out(),
        .pe_psum_out(pe_psum_out_12),
        .pe_weight_out(pe_weight_out_12),
        .pe_switch_out(pe_switch_out_12),
        .pe_accept_w_out()
    );

    pe pe21 ( // connect this to pe_valid out of pe11?
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_11),
        .pe_valid_out(pe_valid_out_21),

        .pe_accept_w_in(sys_accept_w_in),
        .pe_switch_in(pe_switch_out_11),

        .pe_input_in(sys_data_in_21),
        .pe_psum_in(pe_psum_out_11),
        .pe_weight_in(pe_weight_out_11),
        .pe_input_out(pe_input_out_21),
        .pe_psum_out(sys_data_out_21),
        .pe_weight_out(),
        .pe_switch_out(sys_switch_out_21),
        .pe_accept_w_out()
    );

    pe pe22 ( // connect this to pe_valid out of pe 21? 
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_12),
        .pe_valid_out(pe_valid_out_22),

        .pe_accept_w_in(sys_accept_w_out_1),
        .pe_switch_in(pe_switch_out_12),

        .pe_input_in(pe_input_out_21),
        .pe_psum_in(pe_psum_out_12),
        .pe_weight_in(pe_weight_out_12),
        .pe_input_out(),
        .pe_psum_out(sys_data_out_22),
        .pe_weight_out(),
        .pe_switch_out(sys_switch_out_22),
        .pe_accept_w_out()
    );

endmodule