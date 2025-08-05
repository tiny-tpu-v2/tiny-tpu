module dump();
initial begin
  $dumpfile("waveforms/loss_child.vcd");
  $dumpvars(0, loss_child); 
end
endmodule