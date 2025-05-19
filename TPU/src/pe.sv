`default_nettype none
`timescale 1ns/1ns

module pe (
    input wire clk,
    input wire reset,
    input wire valid,

    input wire load_weight,
    input wire [31:0] a_in,
    input wire [31:0] weight,
    input wire [31:0] acc_in,

    output reg [31:0] a_out,
    output reg [31:0] acc_out
);

reg [31:0] weight_reg;

always @(posedge clk) begin

    if (reset) begin
        a_out <= 31'b0;
        acc_out <= 31'b0;
        weight_reg <= 31'b0;
    end else begin

        if (load_weight) begin
            weight_reg <= weight;
        end

        if (valid) begin
            acc_out <= acc_in + (a_in * weight);
            a_out <= a_in;
        end
    end
end
endmodule