`timescale 1ns/1ps
`default_nettype none


// 3x3 systolic array
module systolic (
    input logic clk,
    input logic rst,
    input logic sys_start, // this only needs to be high for one clock cycle -- goes into the first top left PE
    input logic sys_valid_load_weights,
    
    input logic [15:0] sys_data_in_11,
    input logic [15:0] sys_data_in_12, // RENAME TO sys_data_in_21

    input logic [15:0] sys_temp_weight_11,
    input logic [15:0] sys_temp_weight_12,
    input logic [15:0] sys_temp_weight_21,
    input logic [15:0] sys_temp_weight_22,


    output logic [15:0] sys_data_out_21,
    output logic [15:0] sys_data_out_22,

    output wire sys_valid_out_21, 
    output wire sys_valid_out_22
);
    // Zero signals
    wire [15:0] zero_wire_inputs;
    wire [15:0] zero_wire_outputs;

    assign zero_wire_inputs = 16'b0;
    assign zero_wire_outputs = 16'b0;

    // input_out for each PE
    logic [15:0] input_11_out;
    logic [15:0] input_21_out;

    // psum_out for each PE
    logic [15:0] psum_11;
    logic [15:0] psum_12;

    wire pe_valid_out_11; // this wire will connect the valid signal from pe11 to pe12 and pe21
    wire pe_valid_out_12;// this wire will connect the valid signal from pe12 to pe22

    wire pe_valid_out_21; // this wire will connect the valid signal from pe21 to the first OUTPUT
    wire pe_valid_out_22; // this wire will connect the valid signal from pe22 to the second OUTPUT

    assign sys_valid_out_21 = pe_valid_out_21; 
    assign sys_valid_out_22 = pe_valid_out_22; 

    pe pe11 (
        .clk(clk),
        .rst(rst),

        .pe_valid_in(sys_start),
        .pe_valid_out(pe_valid_out_11), // valid out signal is now dispatched onto pe_valid_out_11

        .input_in(sys_data_in_11),
        .psum_in(zero_wire_inputs),
        .weight(sys_temp_weight_11),
        .load_weight(sys_valid_load_weights),
        .input_out(input_11_out),
        .psum_out(psum_11)
    );

    pe pe12 (
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_11), // connect this to pe_valid out of pe11?
        .pe_valid_out(pe_valid_out_12), // now connect this to pe_valid in of pe22


        .input_in(input_11_out),
        .psum_in(zero_wire_inputs),
        .weight(sys_temp_weight_12),
        .load_weight(sys_valid_load_weights),
        .input_out(zero_wire_outputs),
        .psum_out(psum_12)
    );

    pe pe21 ( // connect this to pe_valid out of pe11?
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_11),
        .pe_valid_out(pe_valid_out_21),


        .input_in(sys_data_in_12),
        .psum_in(psum_11),
        .weight(sys_temp_weight_21),
        .load_weight(sys_valid_load_weights),
        .input_out(input_21_out),
        .psum_out(sys_data_out_21)
    );

    pe pe22 ( // connect this to pe_valid out of pe 21? 
        .clk(clk),
        .rst(rst),

        .pe_valid_in(pe_valid_out_12),
        .pe_valid_out(pe_valid_out_22),


        .input_in(input_21_out),
        .psum_in(psum_12),
        .weight(sys_temp_weight_22),
        .load_weight(sys_valid_load_weights),
        .input_out(zero_wire_outputs),
        .psum_out(sys_data_out_22)
    );

endmodule
