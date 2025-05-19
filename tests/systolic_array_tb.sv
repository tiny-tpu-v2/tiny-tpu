`timescale 1ps / 1ps

module systolic_array_tb();

    // Inputs
    logic clk;
    logic reset;
    logic [31:0] a_mat;
    logic [31:0] b_mat;

    // Outputs
    logic [31:0] out;
    // Instantiate the systolic array module
    systolic_array u (
        .clk(clk),
        .reset(reset),
        .a_mat(a_mat),
        .b_mat(b_mat),
        .out(out)
    );

    // Clock generation
    always #1 clk = ~clk;

initial begin
    clk = 0;
    reset = 0;

    #5
        a_mat = 123;
    #5;
    
    $finish;
end

initial begin
    $dumpfile("module_tb.vcd");
    $dumpvars(0, systolic_array_tb);
end

endmodule
