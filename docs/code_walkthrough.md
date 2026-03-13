# tiny-tpu — Complete Detailed Code Walkthrough

> **Who this is for:** Someone who has never seen this codebase, knows basic digital logic (what a clock and a flip-flop are), but needs every design decision, every signal name, and every line of purpose explained in plain English.

---

## Table of Contents

1. [Background: What Are We Building?](#1-background-what-are-we-building)
2. [The Number Format Used Everywhere: Q8.8 Fixed-Point](#2-the-number-format-used-everywhere-q88-fixed-point)
3. [fixedpoint.sv — The Arithmetic Library](#3-fixedpointsv--the-arithmetic-library)
4. [pe.sv — The Processing Element (One MAC Cell)](#4-pesv--the-processing-element-one-mac-cell)
5. [systolic.sv — The 2×2 Systolic Array](#5-systolicsv--the-2x2-systolic-array)
6. [bias_child.sv — Adding a Bias to One Column](#6-bias_childsv--adding-a-bias-to-one-column)
7. [bias_parent.sv — Bias for Both Columns Together](#7-bias_parentsv--bias-for-both-columns-together)
8. [leaky_relu_child.sv — The Activation Function (One Column)](#8-leaky_relu_childsv--the-activation-function-one-column)
9. [leaky_relu_parent.sv — Activation for Both Columns Together](#9-leaky_relu_parentsv--activation-for-both-columns-together)
10. [leaky_relu_derivative_child.sv — Backprop Through Activation (One Column)](#10-leaky_relu_derivative_childsv--backprop-through-activation-one-column)
11. [leaky_relu_derivative_parent.sv — Derivative for Both Columns Together](#11-leaky_relu_derivative_parentsv--derivative-for-both-columns-together)
12. [loss_child.sv — Computing the Error Gradient (One Column)](#12-loss_childsv--computing-the-error-gradient-one-column)
13. [loss_parent.sv — Error Gradient for Both Columns Together](#13-loss_parentsv--error-gradient-for-both-columns-together)
14. [gradient_descent.sv — Updating Weights and Biases](#14-gradient_descentsv--updating-weights-and-biases)
15. [control_unit.sv — The Instruction Decoder](#15-control_unitsv--the-instruction-decoder)
16. [vpu.sv — The Post-Processing Pipeline](#16-vpusv--the-post-processing-pipeline)
17. [unified_buffer.sv — The Memory System](#17-unified_buffersv--the-memory-system)
18. [tpu.sv — Wiring Everything Together (The Top Module)](#18-tpusv--wiring-everything-together-the-top-module)
19. [How Everything Connects: The Big Picture](#19-how-everything-connects-the-big-picture)

---

## 1. Background: What Are We Building?

A **TPU (Tensor Processing Unit)** is a chip designed specifically to run neural network computations efficiently. The key operation in every neural network layer is:

```
output = activation_function( input x weights + bias )
```

This is called a **multiply-accumulate with activation**. This tiny-tpu implements exactly that, for **2 columns** of data at a time, and also implements the **backward pass** -- the math that figures out "how wrong were our predictions, and how should we change the weights to be less wrong next time."

### The Two Passes

**Forward Pass** (making a prediction):
```
Memory -> Systolic Array (matrix multiply) -> Bias Add -> Leaky ReLU -> Memory
```

**Transition Pass** (first backwards step -- computing error gradients):
```
Memory -> Systolic Array -> Bias Add -> Leaky ReLU -> Loss (compute gradient) -> LReLU Derivative -> Memory
```

**Backward Pass** (propagating gradients deeper into the network):
```
Memory -> Systolic Array -> LReLU Derivative -> Memory
                 |
         Gradient Descent -> Updated Weights/Biases -> Memory
```

### The Module Hierarchy (Biggest to Smallest)

```
tpu.sv                      <- top-level chip wrapper
+-- unified_buffer.sv       <- the memory (holds all matrices)
|   +-- gradient_descent.sv <- weight/bias update math (2 instances)
+-- systolic.sv             <- 2x2 matrix multiply engine
|   +-- pe.sv (x4)          <- each MAC cell
+-- vpu.sv                  <- post-processing pipeline
    +-- bias_parent.sv
    |   +-- bias_child.sv (x2)
    +-- leaky_relu_parent.sv
    |   +-- leaky_relu_child.sv (x2)
    +-- loss_parent.sv
    |   +-- loss_child.sv (x2)
    +-- leaky_relu_derivative_parent.sv
        +-- leaky_relu_derivative_child.sv (x2)
```

Every arithmetic module (the "child" modules) uses `fixedpoint.sv` for its math.

---

## 2. The Number Format Used Everywhere: Q8.8 Fixed-Point

**Every single data value** in this design is a **16-bit signed fixed-point number** in the **Q8.8 format**. Understanding this is critical before reading any code.

### What Q8.8 Means

A 16-bit number is split into two halves:
- **Bits [15:8]** = the integer part (8 bits, with bit 15 as the sign bit using twos complement)
- **Bits [7:0]**  = the fractional part (8 bits, representing 1/256, 2/256, ... 255/256)

To convert a Q8.8 number to a real number: divide the raw 16-bit integer value by 256.

| Raw 16-bit value (hex) | Real value | Explanation |
|------------------------|------------|-------------|
| `0x0100` (= 256)       | 1.0        | 256 / 256 = 1.0 |
| `0x0180` (= 384)       | 1.5        | 384 / 256 = 1.5 |
| `0x0080` (= 128)       | 0.5        | 128 / 256 = 0.5 |
| `0xFF00` (= -256 signed) | -1.0     | -256 / 256 = -1.0 |
| `0x0000`               | 0.0        | zero |

**Rule of thumb for sign:** Bit [15] = `0` means the number is zero or positive. Bit [15] = `1` means the number is negative.

**Why fixed-point instead of floating-point?** Because fixed-point hardware is much simpler and smaller. Floating-point (like Python or C `float`) requires complex exponent handling. Fixed-point just uses integer arithmetic with an agreed-upon scale factor (256 here).

---

## 3. fixedpoint.sv -- The Arithmetic Library

**File:** `src/fixedpoint.sv`

This file is a **library of reusable arithmetic circuits**. All the other source files instantiate modules from here. Think of it like `import math` in Python. Every module here is **purely combinational** -- it produces its result immediately within the same clock cycle, with no registers inside. The calling module is responsible for registering the result.

---

### Module: `fxp_zoom` -- Bit-Width Converter

**Purpose:** Changes a fixed-point number from one bit-width to another (e.g., Q8.8 to Q10.10). Handles overflow detection and optional rounding.

**Used by:** All arithmetic modules internally as a helper. Never called directly from the design.

```
Parameters:
  WII   = number of integer bits in the INPUT
  WIF   = number of fractional bits in the INPUT
  WOI   = number of integer bits in the OUTPUT
  WOF   = number of fractional bits in the OUTPUT
  ROUND = 1 means round to nearest, 0 means truncate

Ports:
  in       [WII+WIF-1:0]  -> the input number
  out      [WOI+WOF-1:0]  -> the converted output
  overflow                -> HIGH if the value was saturated (did not fit)
```

**What it does:** Aligns the fractional parts, then checks if the integer part fits.
If the number is too large it saturates to the representable maximum; if too negative, saturates to the minimum. The `overflow` flag alerts the caller.

---

### Module: `fxp_add` -- Fixed-Point Addition

**Purpose:** Adds two Q8.8 numbers and produces a Q8.8 result.

```
Ports:
  ina      [15:0]  -> first operand
  inb      [15:0]  -> second operand
  out      [15:0]  -> ina + inb, in Q8.8
  overflow         -> HIGH if result overflowed Q8.8 range
```

**Used in:** `bias_child.sv`

---

### Module: `fxp_addsub` -- Fixed-Point Addition or Subtraction

**Purpose:** Adds or subtracts two Q8.8 numbers. `sub=0` adds, `sub=1` subtracts.

```
Ports:
  ina, inb [15:0]  -> operands
  sub              -> 0 = ina + inb,  1 = ina - inb
  out      [15:0]  -> result
  overflow         -> HIGH if result overflowed
```

**Used in:** `loss_child.sv` (H - Y), `gradient_descent.sv` (weight - lr*grad)

---

### Module: `fxp_mul` -- Fixed-Point Multiplication

**Purpose:** Multiplies two Q8.8 numbers and produces a Q8.8 result.

```
Ports:
  ina, inb [15:0]  -> operands
  out      [15:0]  -> ina x inb, rounded back to Q8.8
  overflow         -> HIGH if result overflowed
```

Internally produces a 32-bit Q16.16 result then uses `fxp_zoom` to round back to Q8.8.

**Used in:** `pe.sv` (MAC), `leaky_relu_child.sv` (scale negative), `leaky_relu_derivative_child.sv`, `gradient_descent.sv` (lr x gradient)

---

## 4. pe.sv -- The Processing Element (One MAC Cell)

**File:** `src/pe.sv`

### What It Is

A **Processing Element (PE)** is the smallest compute cell. It performs one **MAC** (Multiply-Accumulate):

```
output_partial_sum = (input x weight) + input_partial_sum
```

This is the core operation of matrix multiplication. Four PEs arranged in a 2x2 grid perform the full 2x2 matrix multiply.

### Why a Systolic Array Needs This

In a systolic array, data flows through a grid of PEs like water through pipes. Each PE takes a partial sum from above, multiplies its stored weight with the incoming data, adds the two, and passes the new partial sum downward. The input simultaneously ripples rightward. After all data has flowed through, the bottom-row partial sums are the full matrix multiply results.

### Port Explanation

Think of the PE sitting in a grid with four sides: North (top), West (left), South (bottom), East (right).

```
North inputs (from above):
  pe_psum_in    [15:0]  -- partial sum arriving from the PE above (0 for top-row PEs)
  pe_weight_in  [15:0]  -- new weight value being loaded from the top
  pe_accept_w_in        -- HIGH = load the weight on this clock edge (flows top-to-bottom)

West inputs (from the left):
  pe_input_in   [15:0]  -- the input data flowing in from the left
  pe_valid_in           -- HIGH = pe_input_in contains real data
  pe_switch_in          -- HIGH = swap shadow weight into active use
                           (propagates diagonally to synchronize weight-switch timing with data flow)
  pe_enabled            -- HIGH = this PE is allowed to compute; LOW = freeze and clear outputs

South outputs (going downward):
  pe_psum_out   [15:0]  -- (input x weight) + pe_psum_in, passed down to next row
  pe_weight_out [15:0]  -- the loaded weight, forwarded downward to the next row

East outputs (going rightward):
  pe_input_out  [15:0]  -- pe_input_in delayed by 1 cycle, forwarded right
  pe_valid_out          -- pe_valid_in delayed by 1 cycle, forwarded right
  pe_switch_out         -- pe_switch_in delayed by 1 cycle, forwarded right/diagonally
  pe_overflow_out       -- sticky flag: stays HIGH permanently once any overflow occurs
```

### Internal Signals

```
mult_out           [15:0]  -- combinational output of multiplier: input x weight
mac_out            [15:0]  -- combinational output of adder: mult_out + pe_psum_in
weight_reg_active  [15:0]  -- the ACTIVE weight being used for multiplication
weight_reg_inactive[15:0]  -- the SHADOW (pre-loaded) weight, not yet active
mult_overflow, add_overflow -- overflow flags from the two arithmetic units
```

**Why two weight registers (double-buffering)?** While the PE computes with `weight_reg_active`, the controller pre-loads the next weight set into `weight_reg_inactive`. A `pe_switch_in` pulse atomically swaps them. This lets the system load next-batch weights while current-batch computation is still running -- a pipeline overlap optimization.

### The Arithmetic (Combinational, Instant)

```systemverilog
fxp_mul mult (.ina(pe_input_in), .inb(weight_reg_active),
              .out(mult_out), .overflow(mult_overflow));

fxp_add adder (.ina(mult_out), .inb(pe_psum_in),
               .out(mac_out), .overflow(add_overflow));
```

Results `mult_out` and `mac_out` are combinationally available every cycle. They are latched in the `always_ff` block below.

### The Sequential Block (Registered on Clock Edge)

**On reset OR when disabled (`!pe_enabled`):** All registers go to zero. Disabling clears outputs to prevent garbage values from flowing downstream when processing smaller matrices.

**Normal operation every clock cycle:**
- `pe_valid_out  <= pe_valid_in`  (propagate valid signal rightward, 1 cycle delay)
- `pe_switch_out <= pe_switch_in` (propagate switch signal, 1 cycle delay)
- If `pe_switch_in=1`: copy `weight_reg_inactive` into `weight_reg_active` (swap happens)
- If `pe_accept_w_in=1`: load `pe_weight_in` into `weight_reg_inactive` and pass downward
- If `pe_valid_in=1`:
  - `pe_input_out  <= pe_input_in`  (forward input rightward)
  - `pe_psum_out   <= mac_out`      (latch computed partial sum going downward)
  - `pe_overflow_out <= pe_overflow_out | mult_overflow | add_overflow` (sticky OR)
- If `pe_valid_in=0`:
  - `pe_input_out <= 0`  (clear stale data, do not propagate)
  - `pe_psum_out  <= 0`  (no computation this cycle)

**Why is `pe_overflow_out` sticky?** Once any overflow is detected, the flag stays HIGH until reset. This lets you check "did anything overflow during the whole computation?" without monitoring every cycle.

### What This Module Outputs Per Cycle

When `pe_valid_in` is HIGH:
- `pe_psum_out` = `(pe_input_in x weight_reg_active) + pe_psum_in` (downward)
- `pe_input_out` = `pe_input_in` (rightward, 1-cycle delayed)
- `pe_valid_out` = 1 (rightward, 1-cycle delayed)

---

## 5. systolic.sv -- The 2×2 Systolic Array

**File:** `src/systolic.sv`

### What It Is

This module arranges **four PEs in a 2x2 grid** and routes signals between them. It is the matrix multiplication engine.

### The Grid Layout

```
        col1 (weight col1)    col2 (weight col2)
         sys_weight_in_11      sys_weight_in_12
                |                     |
row1:  [pe11] ------input_out------> [pe12]
sys_data_in_11  |                         |
(sys_start_1)   | psum_out               | psum_out
                |                         |
row2:  [pe21] ------input_out------> [pe22]
sys_data_in_21  |                         |
(sys_start_2)   v                         v
         sys_data_out_21          sys_data_out_22
         sys_valid_out_21         sys_valid_out_22
```

Data enters from the left. Weights load from the top. Results exit from the bottom.

### Port Explanation

```
Data inputs (from left, fed by Unified Buffer):
  sys_data_in_11  [15:0] -- row-1 input data going into pe11
  sys_data_in_21  [15:0] -- row-2 input data going into pe21
  sys_start_1            -- valid/start for row-1 data (drives pe11 valid_in)
  sys_start_2            -- valid/start for row-2 data (drives pe21 valid_in, INDEPENDENT)

Result outputs (from bottom):
  sys_data_out_21 [15:0] -- column-1 MAC result (from pe21)
  sys_data_out_22 [15:0] -- column-2 MAC result (from pe22)
  sys_valid_out_21       -- HIGH when sys_data_out_21 is valid
  sys_valid_out_22       -- HIGH when sys_data_out_22 is valid

Weight inputs (from top, fed by Unified Buffer):
  sys_weight_in_11 [15:0] -- weight data for column-1 PEs
  sys_weight_in_12 [15:0] -- weight data for column-2 PEs
  sys_accept_w_1          -- HIGH = load weight into column-1 PE shadow registers
  sys_accept_w_2          -- HIGH = load weight into column-2 PE shadow registers
  sys_switch_in           -- copy shadow weights to active across all PEs

Column-size control (from Unified Buffer):
  ub_rd_col_size_in  [15:0] -- how many columns in the matrix (1 or 2)
  ub_rd_col_size_valid_in   -- HIGH = the column size value is valid
```

### How the 4 PEs Are Connected

**pe11** (row 1, col 1):
- Input data: `sys_data_in_11` from the left; valid: `sys_start_1`
- Partial sum input: 16'b0 (it is the top-left, no partial sum above it)
- Weight: `sys_weight_in_11` loaded when `sys_accept_w_1` is HIGH
- `pe_psum_out` flows downward into pe12 (to accumulate the column-1 dot product)
- `pe_input_out` flows rightward to pe21 (the input ripple)
- `pe_valid_out` flows downward to pe12 (chains timing within the column)

**pe12** (row 1, col 2):
- Input: `pe_input_out_11` (the rippled row-1 data, 1 cycle delayed)
- Partial sum input: `pe_psum_out_11` (accumulates from pe11)
- Weight: `sys_weight_in_12` loaded when `sys_accept_w_2` is HIGH
- `pe_psum_out` flows downward into pe22
- `pe_valid_out` flows downward to pe22

**pe21** (row 2, col 1):
- Input: `sys_data_in_21` directly from UB; valid: `sys_start_2` (INDEPENDENT timing)
- Partial sum input: `pe_psum_out_11` (adds column-1 contributions from pe11)
- Weight: passed down from pe11 via `pe_weight_out_11`
- `pe_psum_out` goes to `sys_data_out_21` (FINAL column-1 result)
- `pe_valid_out` goes to `sys_valid_out_21`

**pe22** (row 2, col 2):
- Input: `pe_input_out_21` (row-2 data rippled from pe21)
- Partial sum input: `pe_psum_out_12` (column-2 accumulation from pe12)
- Weight: passed down from pe12 via `pe_weight_out_12`
- `pe_psum_out` goes to `sys_data_out_22` (FINAL column-2 result)
- `pe_valid_out` goes to `sys_valid_out_22`

### Why `sys_start_1` and `sys_start_2` Are Independent

In a systolic array, row-2's data must arrive 1 cycle after row-1's data. This is because the first column PE needs 1 cycle to produce its partial sum for row-2 to accumulate. The Unified Buffer generates separate valid signals with this 1-cycle skew. Using two independent start signals (`sys_start_1`, `sys_start_2`) instead of one shared signal gives the UB full control over this skew.

### The `pe_enabled` Register

```systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst)
        pe_enabled <= 2'b11;   // reset default: all columns enabled
    else if (ub_rd_col_size_valid_in)
        case (ub_rd_col_size_in[1:0])
            2'd1:    pe_enabled <= 2'b01;   // only column 1
            2'd2:    pe_enabled <= 2'b11;   // both columns
            default: pe_enabled <= 2'b00;
        endcase
end
```

`pe_enabled[0]` controls pe11 and pe21 (column 1). `pe_enabled[1]` controls pe12 and pe22 (column 2). When a matrix has only 1 column, disabling column-2 PEs prevents garbage from appearing on `sys_data_out_22`.

Reset sets `2'b11` (all-enabled) as the safe default. The first instruction from UB overrides this to the correct value.

### Timing

- `sys_valid_out_21` goes HIGH **1 cycle** after `sys_start_2` is asserted
- `sys_valid_out_22` goes HIGH **2 cycles** after `sys_start_1` is asserted (passes through pe11 then pe22)

---

## 6. bias_child.sv -- Adding a Bias to One Column

**File:** `src/bias_child.sv`

### What It Is

After matrix multiplication, a neural network adds a **bias** to each output. A bias is a learned constant that shifts the neuron's output, giving the model more flexibility. This module handles that addition for exactly **one column** of data.

Math: `output = systolic_result + bias_constant`

### Port Explanation

```
Inputs:
  clk, rst
  bias_scalar_in  [15:0]  -- the bias value from UB (Q8.8, same for every row in this column)
  bias_sys_data_in[15:0]  -- data arriving from the systolic array
  bias_sys_valid_in       -- HIGH = the systolic data is valid

Outputs:
  bias_z_data_out [15:0]  -- result: sys_data + bias_scalar (registered, 1 cycle later)
  bias_Z_valid_out        -- HIGH = bias_z_data_out is valid
  bias_overflow_out       -- sticky flag: stays HIGH if any cycle's addition overflowed
```

### How It Works

A `fxp_add` instance computes `bias_sys_data_in + bias_scalar_in` combinationally every cycle. The `always_ff` block then latches this result on the clock edge only when `bias_sys_valid_in` is HIGH. When invalid, the output is zeroed.

**Output timing:** 1 cycle after input arrives.

**Z** in the output name refers to the neural network convention: Z = W*X + b (the pre-activation value).

---

## 7. bias_parent.sv -- Bias for Both Columns Together

**File:** `src/bias_parent.sv`

A thin **wrapper** that instantiates two `bias_child` modules side by side -- one for each output column from the systolic array. The VPU uses this to apply bias to both columns with a single module instance.

Both columns are processed in parallel. Each column has its own independent bias scalar (`bias_scalar_in_1` for column 1, `bias_scalar_in_2` for column 2). All other ports are per-column versions of the same signals.

Contains no logic of its own -- just wiring.

---

## 8. leaky_relu_child.sv -- The Activation Function (One Column)

**File:** `src/leaky_relu_child.sv`

### What It Is

After bias addition the result goes through an **activation function**. This design uses **Leaky ReLU**:

```
if input >= 0:   output = input          (pass through unchanged)
if input  < 0:   output = input x leak_factor   (scale down by a small factor)
```

Without activation functions, stacking neural network layers does nothing beyond a single linear transformation. The non-linearity is what allows deep networks to learn complex patterns.

"Leaky" means a tiny fraction of the negative signal passes through (instead of being cut to zero like regular ReLU). This prevents "dying neurons" -- neurons that get stuck outputting exactly zero forever and stop learning.

### Port Explanation

```
Inputs:
  clk, rst
  lr_valid_in            -- HIGH = input data is meaningful
  lr_data_in   [15:0]    -- the value to apply activation to (Q8.8)
  lr_leak_factor_in[15:0]-- the leak factor (Q8.8, e.g. 0.01 ~ 0x0003)

Outputs:
  lr_data_out  [15:0]    -- result: lr_data_in (if >= 0) or lr_data_in x leak_factor (if < 0)
  lr_valid_out           -- HIGH = output is valid (1-cycle delayed from input)
  lr_overflow_out        -- sticky overflow flag
```

### How It Works

A `fxp_mul` instance computes `lr_data_in x lr_leak_factor_in` **all the time** (every cycle, combinationally). The `always_ff` block selects which value to latch:

- If `lr_data_in >= 0` (bit [15] = 0): latch `lr_data_in` unchanged
- If `lr_data_in < 0` (bit [15] = 1): latch `mul_out` (the scaled-down version)

When `lr_valid_in` is LOW: output is zeroed, `lr_valid_out` is de-asserted.

**Output timing:** 1 cycle after input arrives.

---

## 9. leaky_relu_parent.sv -- Activation for Both Columns Together

**File:** `src/leaky_relu_parent.sv`

Wraps two `leaky_relu_child` instances in parallel. Both children share the **same `lr_leak_factor_in`** (one leak factor per layer). Each column gets its own data and valid signals. No logic of its own -- just wiring.

---

## 10. leaky_relu_derivative_child.sv -- Backprop Through Activation (One Column)

**File:** `src/leaky_relu_derivative_child.sv`

### What It Is

During training (backward pass), gradients must flow backward through the same activation function. The **derivative** of Leaky ReLU tells us how much the gradient changes passing through:

```
if H >= 0:   dOutput/dInput = 1         -> gradient passes unchanged
if H  < 0:   dOutput/dInput = leak_factor -> gradient scaled by leak_factor
```

where `H` is the **original output of the Leaky ReLU from the forward pass**, stored back in the UB. This is why the backward pass reads the H matrix out of memory before calling this module.

### Port Explanation

```
Inputs:
  clk, rst
  lr_d_valid_in         -- HIGH = gradient input is valid
  lr_d_data_in  [15:0]  -- the incoming gradient (from the loss module upstream)
  lr_leak_factor_in[15:0]-- same leak factor used in the forward pass
  lr_d_H_data_in[15:0]  -- the original H value from the forward pass (to decide which branch)

Outputs:
  lr_d_valid_out        -- HIGH = output gradient is valid
  lr_d_data_out [15:0]  -- the scaled or unscaled gradient
  lr_d_overflow_out     -- sticky overflow flag
```

**Critical difference from `leaky_relu_child`:** The forward module checks if *the current input* is positive/negative. The derivative module checks if *the stored H* is positive/negative. The branch taken during backprop must match the branch taken during the forward pass.

### Key Design Detail

`lr_d_valid_out <= lr_d_valid_in` is assigned **unconditionally** (outside the `if(lr_d_valid_in)` block). This ensures `valid_out` always correctly mirrors the input valid signal every cycle -- it will de-assert when input de-asserts, and assert when input asserts, regardless of other conditions. If it were inside the conditional block it could get stuck HIGH.

### Output Timing

1 cycle after input arrives.

---

## 11. leaky_relu_derivative_parent.sv -- Derivative for Both Columns Together

**File:** `src/leaky_relu_derivative_parent.sv`

Wraps two `leaky_relu_derivative_child` instances. Each column has its own `lr_d_H_1_in` / `lr_d_H_2_in` input (the stored forward-pass activation for that column). No logic of its own.

---

## 12. loss_child.sv -- Computing the Error Gradient (One Column)

**File:** `src/loss_child.sv`

### What It Is

This module computes the **gradient of the MSE (Mean Squared Error) loss** with respect to the network's output. This is the entry point of backpropagation -- it measures how wrong each prediction was.

MSE loss formula: `loss = (1/N) x SUM[(H - Y)^2]`

The gradient of this loss with respect to prediction H is:
```
dL/dH = (2/N) x (H - Y)
```

Where:
- `H` = the network's prediction (output of the forward pass)
- `Y` = the correct answer (ground truth from training data)
- `N` = the number of samples in the batch
- `2/N` is precomputed and stored as `inv_batch_size_times_two_in`

### Port Explanation

```
Inputs:
  clk, rst
  H_in         [15:0]  -- network's prediction (Q8.8)
  Y_in         [15:0]  -- correct label (Q8.8)
  valid_in             -- HIGH = H_in and Y_in are valid data
  inv_batch_size_times_two_in [15:0] -- precomputed (2/N) in Q8.8

Outputs:
  gradient_out [15:0]  -- the computed gradient: (2/N) x (H - Y)
  valid_out            -- HIGH = gradient_out is valid
  loss_overflow_out    -- sticky flag if subtraction or multiplication overflowed
```

### Two-Stage Combinational Pipeline

**Stage 1 (subtraction):**
```
fxp_addsub:  diff_stage1 = H_in - Y_in
```

**Stage 2 (multiplication):**
```
fxp_mul:  final_gradient = diff_stage1 x inv_batch_size_times_two_in
                         = (H - Y) x (2/N)
                         = (2/N)(H - Y)
```

Both stages are combinational (instant). The `always_ff` latches `final_gradient` on the clock edge.

### Key Design Detail

`valid_out <= valid_in` is assigned **unconditionally** (outside the `if(valid_in)` block). Same reason as in `leaky_relu_derivative_child` -- the valid handshake must always mirror the input regardless of data conditions.

### What the Gradient Means

- If `H > Y`: gradient is **positive** (model predicted too high; decrease H)
- If `H < Y`: gradient is **negative** (model predicted too low; increase H)
- If `H == Y`: gradient is **zero** (perfect prediction for this sample)

### Output Timing

1 cycle after input arrives.

---

## 13. loss_parent.sv -- Error Gradient for Both Columns Together

**File:** `src/loss_parent.sv`

Wraps two `loss_child` instances. Both share the same `inv_batch_size_times_two_in` (same 2/N for the whole batch). Each column gets its own `H_in` and `Y_in`. No logic of its own.

---

## 14. gradient_descent.sv -- Updating Weights and Biases

**File:** `src/gradient_descent.sv`

### What It Is

After backpropagation computes the gradient, this module applies the **gradient descent update rule**:

```
new_value = old_value - (learning_rate x gradient)
```

"Move the weight in the opposite direction of the gradient by a small step." Repeated over many iterations, this converges the weights toward values that minimize the loss.

This single module handles both **weights** and **biases** using the `grad_bias_or_weight` flag.

### Port Explanation

```
Inputs:
  clk, rst
  lr_in           [15:0]  -- learning rate (Q8.8, e.g., 0.01)
  value_old_in    [15:0]  -- the current weight or bias value from memory
  grad_in         [15:0]  -- the gradient for this weight/bias
  grad_descent_valid_in   -- HIGH = all inputs are valid, compute the update
  grad_bias_or_weight     -- 0 = bias mode,  1 = weight mode

Outputs:
  value_updated_out [15:0] -- the new weight/bias after the update step
  grad_descent_done_out    -- HIGH = value_updated_out is ready (1-cycle delay from valid_in)
  grad_overflow_out        -- sticky overflow flag
```

### Two-Operation Combinational Pipeline

**Operation 1 (multiplication):**
```
fxp_mul:  mul_out = grad_in x lr_in    (gradient x learning_rate)
```

**Operation 2 (subtraction):**
```
fxp_addsub:  sub_value_out = sub_in_a - mul_out    (old_value - lr*gradient)
```

`sub_in_a` is selected by the combinational mode logic below.

### Weight Mode vs Bias Mode

**Weight mode (`grad_bias_or_weight = 1`):**
```
sub_in_a = value_old_in     (always use the original weight from memory)
```
One gradient, one update, done. The weight update is straightforward.

**Bias mode (`grad_bias_or_weight = 0`):**
```
if grad_descent_done_out == 1:   sub_in_a = value_updated_out  (feed last result back in)
else:                            sub_in_a = value_old_in        (start from the UB value)
```
Bias updates accumulate across multiple gradient steps (one per sample in the batch). Once the first update completes (`done=1`), the result feeds back as the input for the next step. The feedback loop allows the bias to accumulate all gradients in the batch without the UB needing to read/write at every step.

### The Sequential Block

```systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        value_updated_out     <= '0;
        grad_descent_done_out <= '0;
        grad_overflow_out     <= '0;
    end else begin
        grad_descent_done_out <= grad_descent_valid_in;  // UNCONDITIONAL 1-cycle delay
        if (grad_descent_valid_in) begin
            value_updated_out <= sub_value_out;
            grad_overflow_out <= grad_overflow_out | mul_overflow | sub_overflow;
        end
        // NO else clause -- hold value_updated_out when not valid
    end
end
```

**Why no else clause?** After computing an update, the result must stay stable until the UB reads it back and writes it to memory. Clearing to zero in the else branch would destroy the computed result between the `done` pulse and the UB writeback. The register holds its value indefinitely until reset.

**`grad_descent_done_out`** is unconditionally `grad_descent_valid_in` delayed by 1 cycle. Consumers watch `done` to know when to read `value_updated_out`.

---

## 15. control_unit.sv -- The Instruction Decoder

**File:** `src/control_unit.sv`

### What It Is

The TPU is controlled by a **130-bit instruction word**. Rather than setting dozens of individual wires, the host system packs all control signals into one wide bus. The `control_unit` **decodes** this bus -- it is purely combinational (no clock, no registers) with all outputs driven by `assign` statements.

### Port Explanation

```
Input:
  instruction [129:0]  -- the full 130-bit packed control word from the host

Decoded output signals (all determined instantly from instruction bits):
  sys_switch_in              [bit 0]     -- swap active/shadow weights NOW
  ub_rd_start_in             [bit 1]     -- trigger a UB read operation
  ub_rd_transpose            [bit 2]     -- read the matrix transposed
  ub_wr_host_valid_in_1      [bit 3]     -- host is writing on port 1
  ub_wr_host_valid_in_2      [bit 4]     -- host is writing on port 2
  ub_rd_col_size     [15:0]  [bits 20:5] -- number of columns in the target matrix
  ub_rd_row_size     [15:0]  [bits 36:21]-- number of rows in the target matrix
  ub_rd_addr_in      [15:0]  [bits 52:37]-- start address in UB memory
  ub_ptr_select      [8:0]   [bits 61:53]-- which data type to read (0-6, see UB section)
  ub_wr_host_data_in_1[15:0] [bits 77:62]-- data value being written on host port 1
  ub_wr_host_data_in_2[15:0] [bits 93:78]-- data value being written on host port 2
  vpu_data_pathway   [3:0]   [bits 97:94]-- which VPU stages to activate
  inv_batch_size_times_two_in[15:0] [bits 113:98] -- 2/N for MSE loss gradient
  vpu_leak_factor_in [15:0]  [bits 129:114]-- leak factor for Leaky ReLU
```

### Bit Allocation Summary

| Bits | Signal | Width |
|------|--------|-------|
| [0]     | sys_switch_in | 1 bit |
| [1]     | ub_rd_start_in | 1 bit |
| [2]     | ub_rd_transpose | 1 bit |
| [3]     | ub_wr_host_valid_in_1 | 1 bit |
| [4]     | ub_wr_host_valid_in_2 | 1 bit |
| [20:5]  | ub_rd_col_size | 16 bits |
| [36:21] | ub_rd_row_size | 16 bits |
| [52:37] | ub_rd_addr_in | 16 bits |
| [61:53] | ub_ptr_select | 9 bits |
| [77:62] | ub_wr_host_data_in_1 | 16 bits |
| [93:78] | ub_wr_host_data_in_2 | 16 bits |
| [97:94] | vpu_data_pathway | 4 bits |
| [113:98] | inv_batch_size_times_two_in | 16 bits |
| [129:114] | vpu_leak_factor_in | 16 bits |

**Total: 5x1 + 3x16 + 1x9 + 2x16 + 4 + 2x16 = 130 bits**

The full implementation is just 14 `assign` statements, one per decoded signal.

---

## 16. vpu.sv -- The Post-Processing Pipeline

**File:** `src/vpu.sv`

### What It Is

The **VPU (Vector Processing Unit)** sits between the systolic array and the Unified Buffer. It is a configurable pipeline of four processing stages that can be individually enabled or bypassed depending on which phase of computation is running.

### The Four Stages (Always Instantiated)

```
[bias_parent]  ->  [leaky_relu_parent]  ->  [loss_parent]  ->  [leaky_relu_derivative_parent]
```

Each stage is **always instantiated** in hardware. The routing logic decides whether each stage receives real data or zeros (effectively bypassing it).

### The Pathway Control

The 4-bit `vpu_data_pathway` controls which stages are active:

| `vpu_data_pathway` | Active stages | Use case | Total latency |
|---|---|---|---|
| `4'b0000` | None (passthrough) | Raw systolic results to UB | 1 cycle (output register) |
| `4'b1100` | Bias + Leaky ReLU | Forward pass, hidden layers | 3 cycles |
| `4'b1111` | All four stages | Transition pass, output layer | 5 cycles |
| `4'b0001` | LReLU Derivative only | Backward pass, hidden layers | 2 cycles |

Bit mapping: `[3]`=bias, `[2]`=leaky_relu, `[1]`=loss, `[0]`=leaky_relu_derivative

### Port Explanation

```
Inputs from systolic array:
  vpu_data_in_1/2  [15:0]  -- column 1 and 2 MAC results
  vpu_valid_in_1/2         -- valid signals for column 1 and 2

Scalar inputs from Unified Buffer:
  bias_scalar_in_1/2 [15:0]              -- bias constants for each column (for bias stage)
  lr_leak_factor_in  [15:0]              -- leak factor (shared for both relu stages)
  Y_in_1/2           [15:0]              -- ground truth labels (for loss stage)
  inv_batch_size_times_two_in [15:0]     -- 2/N for MSE gradient (for loss stage)
  H_in_1/2           [15:0]              -- stored forward-pass activations (for lrd stage in backward pass)

Outputs to Unified Buffer:
  vpu_data_out_1/2   [15:0]  -- final processed results
  vpu_valid_out_1/2          -- valid signals for the outputs
```

### The Internal Data Chain

Data flows through a chain of intermediate wire groups. Each group is named for the two stages it connects:

```
vpu_data_in_* / vpu_valid_in_*
        |
        v [if pathway[3]=1: route through bias_parent; else: bypass with vpu_data_in directly]
b_to_lr_data_in_* / b_to_lr_valid_in_*
        |
        v [if pathway[2]=1: route through leaky_relu_parent; else: bypass]
lr_to_loss_data_in_* / lr_to_loss_valid_in_*
        |
        v [if pathway[1]=1: route through loss_parent AND capture H into H-cache; else: bypass]
loss_to_lrd_data_in_* / loss_to_lrd_valid_in_*
        |
        v [if pathway[0]=1: route through lr_derivative_parent; else: bypass]
vpu_data_mux_* / vpu_valid_mux_*
        |
        v [ALWAYS registered here -- the output always_ff register]
vpu_data_out_* / vpu_valid_out_*
```

### The "Last-H Cache"

During the transition pass (`1111`), the data flows: input -> bias -> leaky_relu -> loss -> lrd.

The `loss` module needs `H` (the leaky_relu output). The `lrd` module also needs `H`. But `H` is mid-pipeline and is being consumed by `loss`. The solution: the VPU maintains two registers (`last_H_data_1_out`, `last_H_data_2_out`) that snap a copy of the leaky_relu output exactly when it flows through.

```
if pathway[1]=1:
    last_H_data_1_in = lr_data_1_out     (the leaky_relu output this cycle)
    lr_d_H_in_1      = last_H_data_1_out (the REGISTERED copy from last cycle)
else:
    last_H_data_1_in = 16'b0             (clear the cache)
    lr_d_H_in_1      = H_in_1            (use the UB-supplied H instead)
```

The registered copy is 1 cycle older, but because `lrd` comes AFTER `loss` in the pipeline, the registered H value arrives at `lrd` at the correct time relative to the gradient computed by `loss`.

During the backward pass (not transition), `H` is read directly from the UB into `H_in_1/2` and forwarded to `lrd` without using the cache.

### The Output Register (always_ff)

```systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        last_H_data_1_out <= '0;
        last_H_data_2_out <= '0;
        vpu_data_out_1    <= '0;
        vpu_data_out_2    <= '0;
        vpu_valid_out_1   <= '0;
        vpu_valid_out_2   <= '0;
    end else begin
        vpu_data_out_1  <= vpu_data_mux_1;   // latch selected output each cycle
        vpu_data_out_2  <= vpu_data_mux_2;
        vpu_valid_out_1 <= vpu_valid_mux_1;
        vpu_valid_out_2 <= vpu_valid_mux_2;
        if (vpu_data_pathway[1]) begin
            last_H_data_1_out <= last_H_data_1_in;  // capture H this cycle
            last_H_data_2_out <= last_H_data_2_in;
        end else begin
            last_H_data_1_out <= '0;  // clear H cache when loss stage inactive
            last_H_data_2_out <= '0;
        end
    end
end
```

This final register adds exactly +1 cycle of latency to every pathway. It exists to prevent combinational glitches (unstable transitions during logic evaluation) from propagating directly into the UB write port and corrupting memory.

---

## 17. unified_buffer.sv -- The Memory System

**File:** `src/unified_buffer.sv`

### What It Is

The **Unified Buffer (UB)** is the central shared memory of the TPU. It holds ALL data:

- Input activation matrices
- Weight matrices
- Bias vectors
- Y (ground truth label) matrices
- H (stored forward-pass activation) matrices
- Gradient results written by VPU
- Updated weights/biases after gradient descent

### Memory Array

```systemverilog
logic [15:0] ub_memory [0:UNIFIED_BUFFER_WIDTH-1];
// 128 slots of 16-bit (Q8.8) values by default
// Expandable via the UNIFIED_BUFFER_WIDTH parameter
```

A single flat array of 16-bit words. The software-side (host) is responsible for placing each data type at a known, non-overlapping address range.

### Write Ports

**Source 1 -- Host writes** (loading data before computation):
```
ub_wr_host_data_in [SYSTOLIC_ARRAY_WIDTH]  -- 2-element array; one per column
ub_wr_host_valid_in[SYSTOLIC_ARRAY_WIDTH]  -- when [i] is HIGH, write ub_wr_host_data_in[i]
```

**Source 2 -- VPU writes** (storing computation results):
```
ub_wr_data_in  [SYSTOLIC_ARRAY_WIDTH]   -- VPU output data (2 columns)
ub_wr_valid_in [SYSTOLIC_ARRAY_WIDTH]   -- when [i] is HIGH, write ub_wr_data_in[i]
```

Both sources share the same `wr_ptr` write pointer. They are mutually exclusive by protocol: the host only writes before computation, the VPU only writes during/after computation.

**Row-major write order:** The write loop decrements from `SYSTOLIC_ARRAY_WIDTH-1` to 0. This stores column[1] first (lower address), then column[0] (next address) -- row-major layout for the 2-column result.

### The `_next` Variable Pattern

Inside `always_ff`, when a `for` loop needs to advance an address on multiple iterations in the same clock cycle, ordinary non-blocking assignments (`<=`) would all see the same OLD value. The fix uses **blocking assignments** (`=`) to a helper `_next` variable:

```systemverilog
wr_ptr_next = wr_ptr;           // (= not <=) start from current
for (int i = N-1; i >= 0; i--) begin
    if (valid[i]) begin
        ub_memory[wr_ptr_next] <= data[i];  // write to current address
        wr_ptr_next = wr_ptr_next + 1;      // (= not <=) advance for next iteration
    end
end
wr_ptr <= wr_ptr_next;          // single final non-blocking update
```

This correctly advances the address across iterations within one clock cycle.

### Read Channels and the Pointer Select System

When `ub_rd_start_in` is HIGH, `ub_ptr_select` determines WHICH type of data to stream out:

| `ub_ptr_select` | Data type | Destination |
|---|---|---|
| 0 | Input activations | Left side of systolic array (`sys_data_in_*`, `sys_start_*`) |
| 1 | Weight matrix | Top of systolic array (`sys_weight_in_*`, `sys_accept_w_*`) PLUS sends `ub_rd_col_size_out` to set `pe_enabled` |
| 2 | Bias scalars | VPU bias stage (`bias_scalar_in_*`) |
| 3 | Y labels | VPU loss stage (`Y_in_*`) |
| 4 | H activations | VPU LReLU derivative stage (`H_in_*`) |
| 5 | Bias values for gradient descent | gradient_descent `value_old_in` (bias mode) |
| 6 | Weight values for gradient descent | gradient_descent `value_old_in` (weight mode) |

When `ub_rd_start_in` fires, the UB loads `ub_rd_addr_in`, `ub_rd_row_size`, `ub_rd_col_size` into the selected channel's internal registers. Then over the next `row_size + col_size` cycles, the channel auto-streams data out (incrementing its internal pointer each cycle).

### Time Counter Streaming Pattern

Each read channel has a time counter:

```systemverilog
if (rd_X_time_counter + 1 < rd_X_row_size + rd_X_col_size) begin
    // still streaming: output the next data word
    rd_X_time_counter <= rd_X_time_counter + 1;
    // ... per-column output logic with skewed timing
end else begin
    // done: reset all channel registers to zero
    rd_X_ptr          <= 0;
    rd_X_row_size     <= 0;
    rd_X_col_size     <= 0;
    rd_X_time_counter <= '0;
    // ... clear all outputs
end
```

The skewed per-column logic (`if time_counter >= i && time_counter < row_size + i`) ensures that column 0 starts outputting 0 cycles into the burst, and column 1 starts outputting 1 cycle later. This creates the diagonal input skew that the systolic array needs.

### Column-Size Output (Registered)

When a weight read starts (`ptr_select = 1`), the UB tells the systolic array how many columns are active:

```systemverilog
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        ub_rd_col_size_valid_out <= 1'b0;
        ub_rd_col_size_out       <= '0;
    end else begin
        ub_rd_col_size_valid_out <= (ub_rd_start_in && (ub_ptr_select == 9'd1));
        ub_rd_col_size_out       <= (ub_rd_start_in && (ub_ptr_select == 9'd1)) ?
                                    (ub_rd_transpose ? ub_rd_row_size : ub_rd_col_size)
                                    : 16'b0;
    end
end
```

This is **registered** (not combinational) to prevent glitches from the instruction decode from reaching the systolic array's `pe_enabled` register.

### Gradient Descent Integration

The UB instantiates **2 gradient_descent modules** via `generate` (one per column):

```systemverilog
generate
    for (i = 0; i < SYSTOLIC_ARRAY_WIDTH; i++) begin : gradient_descent_gen
        gradient_descent gradient_descent_inst (
            .lr_in(learning_rate_in),
            .grad_in(ub_wr_data_in[i]),        // gradient from VPU
            .value_old_in(value_old_in[i]),     // old weight/bias -- read from UB memory
            .grad_descent_valid_in(grad_descent_valid_in[i]),
            .grad_bias_or_weight(grad_bias_or_weight),
            .value_updated_out(value_updated_out[i]),
            .grad_descent_done_out(grad_descent_done_out[i]),
            ...
        );
    end
endgenerate
```

The always_comb block automatically activates gradient descent whenever a gradient read channel (`ptr_select` 5 or 6) is active AND the VPU is writing valid gradient data. When `done` is asserted, the UB writes the updated value back to memory at `grad_descent_ptr`.

### All Output Ports

```
To systolic left side (input data):
  ub_rd_input_data_out_0/1  [15:0]  -- row data per column
  ub_rd_input_valid_out_0/1         -- valid signals (these become sys_start_1/2)

To systolic top (weights):
  ub_rd_weight_data_out_0/1 [15:0]  -- weight per column
  ub_rd_weight_valid_out_0/1        -- valid (these become sys_accept_w_1/2)

To VPU bias stage:
  ub_rd_bias_data_out_0/1   [15:0]  -- bias scalar per column

To VPU loss stage:
  ub_rd_Y_data_out_0/1      [15:0]  -- Y (ground truth) per column

To VPU lrd stage:
  ub_rd_H_data_out_0/1      [15:0]  -- H (stored activation) per column

To systolic (column count):
  ub_rd_col_size_out         [15:0] -- number of active columns
  ub_rd_col_size_valid_out          -- HIGH = above is valid
```

Output ports are split into `_0` / `_1` suffixed individual signals (rather than arrays) because certain tools have difficulty connecting SystemVerilog port arrays between modules.

---

## 18. tpu.sv -- Wiring Everything Together (The Top Module)

**File:** `src/tpu.sv`

### What It Is

`tpu.sv` is the **top-level integration module**. It contains no computation logic -- it only declares internal wires and connects the three major subsystems. Think of it as the circuit-board-level schematic.

### Port Explanation

```
Inputs from the host (the external system driving the TPU):
  clk, rst
  ub_wr_host_data_in [2]   -- data to write into UB from host (2 columns)
  ub_wr_host_valid_in[2]   -- valid signal for host writes

Instruction interface (comes from control_unit in a real system):
  ub_rd_start_in           -- trigger a UB read
  ub_rd_transpose          -- read in transposed order
  ub_ptr_select  [8:0]     -- which data type to read
  ub_rd_addr_in  [15:0]    -- memory start address
  ub_rd_row_size [15:0]    -- number of rows
  ub_rd_col_size [15:0]    -- number of columns

Scalar parameters:
  learning_rate_in [15:0]  -- learning rate for gradient descent
  vpu_data_pathway [3:0]   -- which VPU stages to activate
  sys_switch_in            -- switch active/shadow weights in systolic array
  vpu_leak_factor_in[15:0] -- Leaky ReLU leak factor
  inv_batch_size_times_two_in [15:0] -- 2/N for MSE gradient
```

There are no output ports from the top-level TPU -- results are written back into the Unified Buffer internally. The host reads computed results by looking at the UB memory contents (in a real system with a memory-mapped interface, or by reading testbench signals in simulation).

### The Three Key Internal Connections

**Connection 1: UB feeds the Systolic Array**
```
UB ub_rd_input_data_out_0  ---> sys_data_in_11    (row-1 input data)
UB ub_rd_input_data_out_1  ---> sys_data_in_21    (row-2 input data)
UB ub_rd_input_valid_out_0 ---> sys_start_1       (row-1 start/valid)
UB ub_rd_input_valid_out_1 ---> sys_start_2       (row-2 start/valid, independent)
UB ub_rd_weight_data_out_0 ---> sys_weight_in_11  (column-1 weight)
UB ub_rd_weight_data_out_1 ---> sys_weight_in_12  (column-2 weight)
UB ub_rd_weight_valid_out_0---> sys_accept_w_1    (load column-1 weight)
UB ub_rd_weight_valid_out_1---> sys_accept_w_2    (load column-2 weight)
UB ub_rd_col_size_out      ---> ub_rd_col_size_in (tells systolic how many cols active)
UB ub_rd_col_size_valid_out---> ub_rd_col_size_valid_in
```

**Connection 2: Systolic Array feeds the VPU**
```
sys_data_out_21  ---> vpu_data_in_1    (column-1 MAC result)
sys_data_out_22  ---> vpu_data_in_2    (column-2 MAC result)
sys_valid_out_21 ---> vpu_valid_in_1
sys_valid_out_22 ---> vpu_valid_in_2
UB ub_rd_bias_data_out_0/1  ---> bias_scalar_in_1/2  (scalars from UB)
UB ub_rd_Y_data_out_0/1     ---> Y_in_1/2
UB ub_rd_H_data_out_0/1     ---> H_in_1/2
```

**Connection 3: VPU writes back to UB** (the feedback loop)
```
vpu_data_out_1   ---> ub_wr_data_in[0]   (result for column 1)
vpu_data_out_2   ---> ub_wr_data_in[1]   (result for column 2)
vpu_valid_out_1  ---> ub_wr_valid_in[0]
vpu_valid_out_2  ---> ub_wr_valid_in[1]
```

This forms a **closed loop**: UB -> Systolic -> VPU -> UB.

---

## 19. How Everything Connects: The Big Picture

### Forward Pass Data Flow

```
HOST:  load input_matrix, weight_matrix, bias_vector into UB

Step 1 -- Load weights:
  host sets: ub_rd_start_in=1, ub_ptr_select=1 (weight), ub_rd_addr_in=<weight_addr>
  UB streams: sys_weight_in_11/12 with sys_accept_w_1/2 HIGH -> PEs load shadow registers

Step 2 -- Switch weights active:
  host sets: sys_switch_in=1
  All PEs: weight_reg_inactive -> weight_reg_active simultaneously

Step 3 -- Stream inputs + compute:
  host sets: ub_rd_start_in=1, ub_ptr_select=0 (input), ub_rd_addr_in=<input_addr>
             ub_rd_start_in=1, ub_ptr_select=2 (bias), ub_rd_addr_in=<bias_addr>
  host sets: vpu_data_pathway = 4'b1100  (bias + leaky_relu)
  UB streams: sys_data_in_11, sys_data_in_21 with sys_start_1, sys_start_2
  Systolic: accumulates MAC results -> sys_data_out_21/22 valid after 1/2 cycles
  VPU: applies bias then leaky_relu -> vpu_data_out_1/2 valid after 3 cycles total
  UB: receives vpu_data_out via ub_wr_valid -> writes H matrix to wr_ptr
```

### Transition Pass (Output Layer Backward)

```
  host sets: vpu_data_pathway = 4'b1111 (all stages)
  host sets: ub_ptr_select=3 to stream Y labels, ub_ptr_select=2 for biases
  Systolic: computes input x weight
  VPU bias: adds bias
  VPU leaky_relu: applies activation, H is captured in last_H_data cache
  VPU loss: computes (2/N)(H - Y) gradient using H from cache and Y from UB
  VPU lrd: applies derivative using cached H
  UB: receives gradient -> gradient_descent computes new_value = old - lr*grad -> writes back
```

### Backward Pass (Hidden Layer)

```
  host sets: vpu_data_pathway = 4'b0001 (lrd only)
  host sets: ub_ptr_select=4 to stream H matrix from UB
  Systolic: computes input x weight (transposed weight matrix for backprop)
  VPU: directly applies lrd using H from UB
  UB: writes gradient result back
  Then gradient_descent runs separately on the stored old weights
```

### Signal Summary Table

| Signal | Source | Destination | What it carries |
|--------|--------|-------------|-----------------|
| `sys_data_in_11` | UB ptr=0 ch[0] | pe11 input | Row-1 input data |
| `sys_data_in_21` | UB ptr=0 ch[1] | pe21 input | Row-2 input data |
| `sys_start_1` | UB input valid[0] | pe11 valid_in | Row-1 timing signal |
| `sys_start_2` | UB input valid[1] | pe21 valid_in | Row-2 timing signal (1 cycle skewed) |
| `sys_weight_in_11` | UB ptr=1 ch[0] | pe11 weight load | Column-1 weight value |
| `sys_accept_w_1` | UB weight valid[0] | pe11/pe21 accept_w | Load column-1 shadow register |
| `sys_switch_in` | host | all PEs switch_in | atomic weight swap command |
| `sys_data_out_21` | pe21 psum | vpu_data_in_1 | Column-1 MAC result |
| `sys_data_out_22` | pe22 psum | vpu_data_in_2 | Column-2 MAC result |
| `ub_rd_col_size_out` | UB (registered) | systolic pe_enabled | How many PE columns are active |
| `bias_scalar_in_1` | UB ptr=2 ch[0] | VPU bias stage | Bias constant for column 1 |
| `Y_in_1` | UB ptr=3 ch[0] | VPU loss stage | Ground truth label for column 1 |
| `H_in_1` | UB ptr=4 ch[0] | VPU lrd stage | Stored forward activation for column 1 |
| `vpu_data_pathway` | host/CU | VPU routing | Which pipeline stages are active |
| `vpu_data_out_1` | VPU output reg | UB wr_data[0] | Processed result for column 1 back to memory |
| `learning_rate_in` | host | UB grad_descent | Learning rate for weight update |
| `pe_overflow_out` | each PE | (not at top) | Sticky overflow flag per PE cell |

### Overflow Flags

Every arithmetic stage outputs a **sticky overflow flag**:
- `pe_overflow_out` (per PE in systolic)
- `bias_overflow_out` (per column in VPU)
- `lr_overflow_out` (per column in VPU)
- `lr_d_overflow_out` (per column in VPU)
- `loss_overflow_out` (per column in VPU)
- `grad_overflow_out` (per gradient_descent instance in UB)

These flags go HIGH and stay HIGH if the Q8.8 representable range (-127.996 to +127.996) is exceeded at any point. In `tpu.sv` these are left unconnected at the top level (the `.pe_overflow_out()` syntax means "connect but don't bring to a port"). They are accessible in simulation through hierarchical signal references or waveform dumps, useful for debugging numerical range issues.

---

*End of Walkthrough.*
*For formal verification assertions covering each module, see the `sva/` directory.*
*For Python simulation tests, see the `test/` directory.*
*For numpy reference implementation, see `jupyter/single_pass_numpy.ipynb`.*
