`default_nettype none
`timescale 1ns/1ns

module dut (
    input  wire        clk,   // Clock input
    input  wire        reset,   // Active-high synchronous reset
    output reg [7:0]   count  // 8-bit counter output
);

// TODO: parameterize COUNTER_WIDTH if you need a different bit-width

always @(posedge clk or posedge reset) begin
    if (reset) begin
        count <= 0;
    end else begin
        count <= count + 1;
    end
end

endmodule
