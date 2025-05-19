`timescale 1ps / 1ps

module systolic_array(
    input logic clk,
    input logic reset,
    input logic [31:0] a_mat,
    input logic [31:0] b_mat,
    output logic [31:0] out
);
    reg [31:0] weight_mat [2:0][2:0];
    logic [31:0] out_intermediate;
    logic [31:0] out_intermediate2;
    logic [31:0] out_intermediate3;

    pe pe_inst(
        .clk(clk),
        .reset(reset),
        .in_left(a_mat),
        .in_up(b_mat),
        .out_right(out_intermediate),
        .out_down(out_intermediate2)
    );

    pe pe_inst2(
        .clk(clk),
        .reset(reset),
        .in_left(out_intermediate),
        .in_up(b_mat),
        .out_right(out),
        .out_down(out_intermediate3)
    );

    always @(posedge clk) begin
        
    end

endmodule
