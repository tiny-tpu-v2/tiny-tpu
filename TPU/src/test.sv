`default_nettype none
`timescale 1ns/1ns

module test (
    input wire clk,
    input wire reset,
    input [31:0] in_test, 
    output [31:0] out_test 
); 



reg [31:0] test_reg; 

always @(posedge clk) begin
    if (reset) begin
        test_reg <= 32'h00000000;
    end else begin
        test_reg <= in_test; 
        
    end
end


assign out_test = test_reg; 
endmodule
