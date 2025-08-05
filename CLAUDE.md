Here is how the codebase is organized:
For each .sv module in /src, there is a corresponding cocotb testbench that can be found in the /test folder of the project.
Please refer to the Makefile for the workflow of how to add a new module, as well as the README.md, both found in the project home directory

For each signal, if its declared as an input, please end the signal with "in". If its declared as an output, end the signal with "out". Take a look at the sample modules in /src to figure out more details about this signal declaration format. Ignore this format for "clk" and "rst", they are self-explanatory. 

When naming signals, please be slightly verbose. Use mathematical terminology that describes visual aspects of signals, eg. adding the words "col" or "row" for better documentation on visualizing what the code is doing.

When adding documentation, please make sure all comments are in lower case, and all variables/signals are in snake case.
