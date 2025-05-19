# What verilog modules do we need for a XOR Inference Engine (a Prediction Engine that runs XOR)? {aPEX}

- Systolic array: for matmuls
  - Input layer multiplication would use a 3x2 weight matrix, so we need a 3x2 systolic array
  - First hidden layer multiplication would use a 3x3 weight matrix, so we need a 3x3 systolic array
  - Second hidden layer multiplication would use a 3x1 weight matrix, so we’d need a 3x1 systolic array
- Control unit – the thing that takes our n-bit length word and decouples it into 1) flag bits and 2) parameter bits – both types - route into different MUXes to perform different operations i.e. MOV data from reg X to reg X.
- Some shadow buffers (to stage data from some partition of memory to be moved to the main one) i.e. how do we move weight data into the weight-stationary systolic array? Ultimately shadow buffers will allow us to prepare new data in the background. For example within each PE of our systolic array, we might need a shadow buffer so that we can TOGGLE between two registers. One register in active use to hold the current weight, and one register to hold the next.
