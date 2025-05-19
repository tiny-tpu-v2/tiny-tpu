`timescale 1ps/1ps
module float32_adder_tb;
  // Clock & Reset
  reg clk = 0;
  reg rst;

  // Inputs
  reg [31:0] input_a;
  reg [31:0] input_b;
  reg        input_a_stb;
  reg        input_b_stb;
  reg        output_z_ack;

  // Outputs
  wire [31:0] output_z;
  wire        output_z_stb;
  wire        input_a_ack;
  wire        input_b_ack;

  // Instantiate DUT
  float32_adder dut (
    .clk(clk),
    .rst(rst),
    .input_a(input_a),
    .input_a_stb(input_a_stb),
    .input_a_ack(input_a_ack),
    .input_b(input_b),
    .input_b_stb(input_b_stb),
    .input_b_ack(input_b_ack),
    .output_z(output_z),
    .output_z_stb(output_z_stb),
    .output_z_ack(output_z_ack)
  );

  // Clock generator: 100 MHz
  always #1 clk = ~clk;

  initial begin
    // Initialize
    rst = 1;
    input_a = 0;
    input_b = 0;
    input_a_stb = 0;
    input_b_stb = 0;
    output_z_ack = 0;
    #20; rst = 0;

    //--------------------------------------
    // First addition transaction
    //--------------------------------------
    
    // set inputs and assert strobes
    input_a = 32'h40e9999a; // 7.3
    input_b = 32'h40000000; // 2.0
    input_a_stb = 1;
    input_b_stb = 1;

    // Wait for DUT to acknowledge accept, then can set strobes to 0
    wait (input_a_ack);
    wait (!input_a_ack);
    input_a_stb = 0;
    wait (input_b_ack);
    wait (!input_b_ack);
    input_b_stb = 0;

    // Wait for result valid
    wait (output_z_stb);
    $display("[%0t] RESULT: 1.0 + 2.0 = %0h", $time, output_z);
    // wait (!output_z_stb);


    // Acknowledge that output is ready for next transaction
    output_z_ack = 1;
    wait (!output_z_stb);
    output_z_ack = 0;

    //--------------------------------------
    // Second addition transaction
    //--------------------------------------
    // Change inputs (e.g., 3.0 + 4.0)
    input_a = output_z; // 3.0
    input_b = 32'h40800000; // 4.0
    input_a_stb = 1;
    input_b_stb = 1;

    wait (input_a_ack);
    wait (!input_a_ack);
    input_a_stb = 0;
    wait (input_b_ack);
    wait (!input_b_ack);
    input_b_stb = 0;

    wait (output_z_stb);
    $display("[%0t] RESULT: 3.0 + 4.0 = %0h", $time, output_z);
    output_z_ack = 1;
    wait (!output_z_stb);
    output_z_ack = 0;

    #10;

    $finish;
  end

initial begin
  $dumpfile("float32_adder.vcd");
  $dumpvars(0, float32_adder_tb);
end
endmodule