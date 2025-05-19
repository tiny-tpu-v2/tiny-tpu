`timescale 1ps / 1ps

module pe(
    input logic clk,
    input logic reset,
    input logic start,              // start = 1 to compute
    input logic load_weight,

    input logic [31:0] input_in,
    input logic [31:0] sum_in,
    input logic [31:0] weight_in,
    
    output logic [31:0] input_out,
    output logic [31:0] sum_out
);

    logic [31:0] weight_reg;
    

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            input_out <= 0;
            sum_out <= 0;
            weight_reg <= 0;
        end
        else begin
            if (load_weight) begin
                weight_reg <= weight_in;
            end
            if (start) begin
                input_out <= input_in;
            end
        end
    end

endmodule

