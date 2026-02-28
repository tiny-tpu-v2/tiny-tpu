module dump();
initial begin
  $dumpfile("waveforms/leaky_relu_child.vcd");
  $dumpvars(0, leaky_relu_child); 
end
endmodule