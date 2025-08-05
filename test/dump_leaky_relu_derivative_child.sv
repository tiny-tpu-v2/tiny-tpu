module dump();
initial begin
  $dumpfile("waveforms/leaky_relu_derivative_child.vcd");
  $dumpvars(0, leaky_relu_derivative_child); 
end
endmodule