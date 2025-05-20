`timescale 1ps / 1ps

module systolic_array(
    input logic clk,
    input logic reset,
    input logic start,
    input logic load_weight,
    input logic [31:0] w00,
    input logic [31:0] w01,
    input logic [31:0] w10,
    input logic [31:0] w11,
    input logic [31:0] in0,
    input logic [31:0] in1,
    output logic [31:0] out0,
    output logic [31:0] out1
);

    logic [31:0] pe00_to_pe01;
    logic [31:0] pe00_to_pe10;
    logic [31:0] pe01_to_pe11;
    logic [31:0] pe10_to_pe11;

    pe pe00(
        .clk(clk),
        .reset(reset),
        .start(start),
        .load_weight(load_weight),
        .weight_in(w00),
        .input_in(in0),
        .sum_in(0),
        .input_out(pe00_to_pe01),
        .sum_out(pe00_to_pe10)
    );

    pe pe01(
        .clk(clk),
        .reset(reset),
        .start(start),
        .load_weight(load_weight),
        .weight_in(w01),
        .input_in(pe00_to_pe01),
        .sum_in(0),
        .input_out(),
        .sum_out(pe01_to_pe11)
    );

    pe pe10(
        .clk(clk),
        .reset(reset),
        .start(start),
        .load_weight(load_weight),
        .weight_in(w10),
        .input_in(in1),
        .sum_in(pe00_to_pe10),
        .input_out(pe10_to_pe11),
        .sum_out(out0)
    );

    pe pe11(
        .clk(clk),
        .reset(reset),
        .start(start),
        .load_weight(load_weight),
        .weight_in(w11),
        .input_in(pe10_to_pe11),
        .sum_in(pe01_to_pe11),
        .input_out(),
        .sum_out(out1)
    );

    always @(posedge clk or posedge reset) begin
        
    end

endmodule
