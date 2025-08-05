module dump();
initial begin
  $dumpfile("waveforms/leaky_relu_derivative_parent.vcd");
  $dumpvars(0, leaky_relu_derivative_parent); 
end
endmodule