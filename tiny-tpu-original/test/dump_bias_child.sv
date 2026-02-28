module dump();
initial begin
  $dumpfile("waveforms/bias_child.vcd");
  $dumpvars(0, bias_child); 
end
endmodule