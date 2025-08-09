  module dump();
  initial begin
    $dumpfile("waveforms/gradient_descent.vcd");
    $dumpvars(0, gradient_descent); 
  end
  endmodule