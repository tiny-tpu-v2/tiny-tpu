module dump();
initial begin
  $dumpfile("waveforms/loss.vcd");
  $dumpvars(0, loss); // dump entire loss module hierarchy
end
endmodule
