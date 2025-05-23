# TODOs:
- Go through entire workflow to understand it fully
- Xander will explain how accumulator module works
- Once leaky ReLU valid out has a falling edge, meaning all of the outputs of the first layer are now loaded into the accumulator, set start to high in the test bench code to start calculating the second layer immediately. Right now we just wait a long number of clock cycles
- Optimize and refactor code (ex: refactoring if else statements to FSMs)
- Test forward pass w integers to see if there’s a structure error or if its due to precision
- If there’s a structure issue, figure out how to turn off PEs
- Change fp precision to 32-bit
- Look into how to do batch inference (we have single input inference working)
