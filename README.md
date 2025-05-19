make sure u use arm64 cocotb in conda, iverlog to path and uh yeah. 

// Pseudo-training loop inside the testbench
repeat (1000) begin  // 1000 training epochs
  feed_input(0, 0, 0);
  wait_for_prediction();
  
  feed_input(0, 1, 1);
  wait_for_prediction();
  
  feed_input(1, 0, 1);
  wait_for_prediction();
  
  feed_input(1, 1, 0);
  wait_for_prediction();
end


^^^ example testbench of how we'd maybe feed in the inputs? 


my shortcuts:

1. cmd + delete = delete line
2. cmd + p (opens command palate)
3. make test_x
4. make show_x
5. 
