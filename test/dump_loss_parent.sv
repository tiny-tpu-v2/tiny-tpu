module dump();
initial begin
  $dumpfile("waveforms/loss_parent.vcd");
  $dumpvars(0, loss_parent); 
end
endmodule