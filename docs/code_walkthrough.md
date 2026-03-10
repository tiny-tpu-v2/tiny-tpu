# tiny-tpu — Complete Line-by-Line Code Walkthrough

> **Who this is for:** Someone who understands basic digital logic (what a clock, flip-flop, and bus are) but has never read this codebase before. Every design choice is explained in plain English.

---

## Table of Contents

1. [Background: What are we building?](#1-background-what-are-we-building)
2. [fixedpoint.sv — The Math Library](#2-fixedpointsv--the-math-library)
3. [pe.sv — The Compute Cell](#3-pesv--the-compute-cell)
4. [systolic.sv — The 2×2 Matrix Multiplier](#4-systolicsv--the-2x2-matrix-multiplier)
5. [bias_child.sv — Adding a Bias to One Column](#5-bias_childsv--adding-a-bias-to-one-column)
6. [bias_parent.sv — Bias for Both Columns](#6-bias_parentsv--bias-for-both-columns)
7. [leaky_relu_child.sv — The Activation Function](#7-leaky_relu_childsv--the-activation-function)
8. [leaky_relu_parent.sv — Activation for Both Columns](#8-leaky_relu_parentsv--activation-for-both-columns)
9. [loss_child.sv — Measuring the Error (Backprop Stage 1)](#9-loss_childsv--measuring-the-error-backprop-stage-1)
10. [loss_parent.sv — Error for Both Columns](#10-loss_parentsv--error-for-both-columns)
11. [leaky_relu_derivative_child.sv — Backprop Through the Activation](#11-leaky_relu_derivative_childsv--backprop-through-the-activation)
12. [leaky_relu_derivative_parent.sv — Derivative for Both Columns](#12-leaky_relu_derivative_parentsv--derivative-for-both-columns)
13. [gradient_descent.sv — Updating Weights](#13-gradient_descentsv--updating-weights)
14. [control_unit.sv — The Instruction Decoder](#14-control_unitsv--the-instruction-decoder)
15. [vpu.sv — The Post-Processing Pipeline](#15-vpusv--the-post-processing-pipeline)
16. [unified_buffer.sv — The Memory System](#16-unified_buffersv--the-memory-system)
17. [tpu.sv — Wiring It All Together](#17-tpusv--wiring-it-all-together)
18. [How Everything Connects — The Big Picture](#18-how-everything-connects--the-big-picture)

---

## 1. Background: What Are We Building?

A **TPU (Tensor Processing Unit)** is a chip designed to do one thing very efficiently: matrix multiplication. This is the core operation in every neural network layer.

Think of a neural network layer like this:

```
output = activation(input_matrix × weight_matrix + bias)
```

This tiny-tpu implements exactly that, and also the backward pass (the math that finds "how wrong were we and how should we fix the weights").

**The data flow for a forward pass is:**

```
Memory (UB) → Systolic Array → Bias → Leaky ReLU → Memory (UB)
```

**The data flow for a backward pass is:**

```
Memory (UB) → Systolic Array → LeakyReLU Derivative → Memory (UB)
              ↓
         Gradient Descent → Updated Weights → Memory (UB)
```

All data in this design is represented as **Q8.8 fixed-point** — a 16-bit number where the top 8 bits are the integer part and the bottom 8 bits are the fractional part. Think of it as dollars.cents but in binary.

---

## 2. fixedpoint.sv — The Math Library

This file is a pre-written library of arithmetic circuits. The rest of the design uses it everywhere. You do **not** need to understand every line of this file — but you need to know what each module does.

### The Number Format

Every data signal in this design is a **16-bit signed fixed-point number** with:
- Bits [15:8] = integer part (8 bits, with bit 15 as the sign bit)
- Bits [7:0]  = fractional part (8 bits)

So the value `1.5` is stored as `0x0180` (= 256 + 128 = 384, and 384 / 256 = 1.5).

Negative numbers use two's complement. For example `-1.0` is `0xFF00`.

**Rule of thumb:** bit [15] = 0 means the number is ≥ 0. bit [15] = 1 means the number is negative.

---

### `fxp_zoom` — Bit-Width Converter

```systemverilog
module fxp_zoom #(
    parameter WII  = 8,   // Input integer bits
    parameter WIF  = 8,   // Input fractional bits
    parameter WOI  = 8,   // Output integer bits
    parameter WOF  = 8,   // Output fractional bits
    parameter ROUND= 1    // 1 = round, 0 = truncate
)
```

**What it does:** Converts a fixed-point number from one bit width to another, handling overflow and optionally rounding. It is used internally by all the arithmetic modules below — you never call it directly.

---

### `fxp_add` — Addition

```systemverilog
module fxp_add # (
    parameter WIIA = 8,  // Integer bits of input A
    parameter WIFA = 8,  // Fractional bits of input A
    parameter WIIB = 8,  // Integer bits of input B
    parameter WIFB = 8,  // Fractional bits of input B
    parameter WOI  = 8,  // Integer bits of output
    parameter WOF  = 8,  // Output fractional bits
    parameter ROUND= 1
)(
    input  wire [WIIA+WIFA-1:0] ina,   // First number to add
    input  wire [WIIB+WIFB-1:0] inb,   // Second number to add
    output wire [WOI +WOF -1:0] out,   // Result
    output wire                 overflow  // Goes to 1 if result doesn't fit
);
```

**How it works internally:**
1. Both inputs are first "zoomed" to the same precision using `fxp_zoom`
2. They are added with `$signed(inaz) + $signed(inbz)` — standard binary addition
3. The result is "zoomed" back down to the output width, rounded if `ROUND=1`

**What it does:** Adds two fixed-point numbers together. Simple addition, but with automatic handling of different bit widths.

---

### `fxp_addsub` — Addition or Subtraction

```systemverilog
module fxp_addsub # (...)
(
    input  wire [WIIA+WIFA-1:0] ina,
    input  wire [WIIB+WIFB-1:0] inb,
    input  wire                 sub,   // 0 = add, 1 = subtract
    output wire [WOI +WOF -1:0] out,
    output wire                 overflow
);
```

**What it does:** Either adds or subtracts `ina` and `inb` depending on the `sub` bit.
- `sub = 0`: result = ina + inb
- `sub = 1`: result = ina - inb

**How subtraction works internally:** To subtract, it negates `inb` using two's complement (`~inb + 1`) and then adds. Same hardware, just flip bits and add one.

---

### `fxp_mul` — Multiplication

```systemverilog
module fxp_mul # (...) (
    input  wire [WIIA+WIFA-1:0] ina,
    input  wire [WIIB+WIFB-1:0] inb,
    output wire [WOI +WOF -1:0] out,
    output wire                 overflow
);

localparam WRI = WIIA + WIIB;   // When you multiply, integer bits add
localparam WRF = WIFA + WIFB;   // Fractional bits add too

wire signed [WRI+WRF-1:0] res = $signed(ina) * $signed(inb);
```

**What it does:** Multiplies two fixed-point numbers.

**Why the intermediate result is wider:** If you multiply two 16-bit numbers, the product needs up to 32 bits to avoid losing information. The result is then zoomed back down to 16 bits (with rounding/truncation).

**Important:** This is **purely combinational** — it produces a result on the same clock cycle the inputs arrive. There is no clock, no flip-flop. Combinational means "instant" from a logical perspective.

---

## 3. pe.sv — The Compute Cell

This is the most important module. Everything else is built on top of the logic this module performs.

### What is a PE?

**PE = Processing Element**. It is one cell in the matrix multiplication grid. A single PE does:

```
psum_out = (input × weight) + psum_in
```

This is a **Multiply-Accumulate (MAC)** operation. The trick is that many PEs are chained together so each PE passes its partial sum (`psum`) to the next PE. By the time data has passed through all PEs in a column, the full dot-product of a row and column has been accumulated.

### Port Layout

```
         weight_in / accept_w_in / switch_in
                    ↓  (North)
    input_in →  [  PE  ]  → input_out
    valid_in →  [      ]  → valid_out
   switch_in →  [      ]  → switch_out
                   ↓  (South)
              psum_out / weight_out
```

Signals flow through PEs like water through plumbing — each PE passes its processed signal to its neighbor.

---

### Line-by-Line Walkthrough

```systemverilog
`timescale 1ns/1ps
```
This sets the simulation time unit. `1ns` = one nanosecond per time step, `1ps` = one picosecond of precision. Every `#1` delay in testbenches means 1ns.

```systemverilog
`default_nettype none
```
Disables implicit wire creation. If you make a typo in a signal name, the compiler will give an error instead of silently creating a new wire. This is a best practice to catch bugs early.

```systemverilog
module pe #(
    parameter int DATA_WIDTH = 16
)
```
Defines the module named `pe`. The `#(...)` section lists **parameters** — values you can customize when you instantiate this module. `DATA_WIDTH=16` is defined but has a `//TODO` comment saying it's not used yet.

```systemverilog
    input logic clk,
    input logic rst,
```
Standard clock and reset. Every flip-flop in this module is clocked by `clk` and resets when `rst` goes high.

```systemverilog
    // North wires of PE
    input logic signed [15:0] pe_psum_in,
    input logic signed [15:0] pe_weight_in,
    input logic pe_accept_w_in,
```
- `pe_psum_in`: The partial sum coming IN from the PE above. The first PE in a column gets `0` here.
- `pe_weight_in`: A new weight value being loaded. This comes from memory.
- `pe_accept_w_in`: A flag saying "the weight on `pe_weight_in` right now is valid, please store it."

```systemverilog
    // West wires of PE
    input logic signed [15:0] pe_input_in,
    input logic pe_valid_in,
    input logic pe_switch_in,
    input logic pe_enabled,
```
- `pe_input_in`: The input data value (from the matrix being processed). Flows left-to-right.
- `pe_valid_in`: A flag saying "the data on `pe_input_in` right now is real data, not garbage." Only when this is 1 should the PE compute.
- `pe_switch_in`: A command to "activate" the freshly loaded weight. Explained more below.
- `pe_enabled`: If 0, this PE is completely inactive. Used to disable unused PEs when working with matrices smaller than 2 columns.

```systemverilog
    // South wires of the PE
    output logic signed [15:0] pe_psum_out,
    output logic signed [15:0] pe_weight_out,
```
- `pe_psum_out`: The partial sum we computed, passed down to the PE below.
- `pe_weight_out`: We pass the weight through to the PE below, so each PE in a column can load the same weight in sequence.

```systemverilog
    // East wires of the PE
    output logic signed [15:0] pe_input_out,
    output logic pe_valid_out,
    output logic pe_switch_out
```
- `pe_input_out`: We pass the input data to the right (to the next PE in the row).
- `pe_valid_out`: We pass the valid flag to the right, delayed by 1 clock cycle.
- `pe_switch_out`: We pass the switch signal to the right, delayed by 1 clock cycle.

---

### Internal Signals and Instantiations

```systemverilog
    logic signed [15:0] mult_out;
    wire signed [15:0] mac_out;
    logic signed [15:0] weight_reg_active;    // foreground register
    logic signed [15:0] weight_reg_inactive;  // background register
```

This is the **double-buffer weight scheme**:
- `weight_reg_inactive` = the "shadow" register. New weights are loaded here safely while the PE is still computing with old weights.
- `weight_reg_active` = the "live" register. The one actually being used in the multiply.
- When you want to switch to the new weights, you assert `pe_switch_in` and the inactive register's value is copied into the active register instantly.

`mult_out` holds the result of `input × weight`. `mac_out` holds `mult_out + psum_in`.

```systemverilog
    fxp_mul mult (
        .ina(pe_input_in),
        .inb(weight_reg_active),
        .out(mult_out),
        .overflow()
    );
```
This **instantiates** (creates) one copy of the `fxp_mul` module. It is connected so that:
- Input A = `pe_input_in` (the data)
- Input B = `weight_reg_active` (the loaded weight)
- Output = `mult_out`
- The `overflow` port is left unconnected — the design ignores overflow detection from the multiplier.

This module is **purely combinational**: any time `pe_input_in` or `weight_reg_active` changes, `mult_out` updates instantly (no clock needed).

```systemverilog
    fxp_add adder (
        .ina(mult_out),
        .inb(pe_psum_in),
        .out(mac_out),
        .overflow()
    );
```
Adds: `mac_out = mult_out + pe_psum_in`. This is also combinational. Together, the multiplier and adder form a **chain** that continuously computes `(input × weight) + psum` — the MAC operation.

---

### The Double-Buffer: `always_comb` Block

```systemverilog
    always_comb begin
        if (pe_switch_in) begin
            weight_reg_active = weight_reg_inactive;
        end
    end
```

**`always_comb`** means "this logic runs every time any input changes, instantly (no clock)". Think of it like a combinational mux.

- When `pe_switch_in = 1`: `weight_reg_active` immediately equals `weight_reg_inactive`. The new weights go "live" **on the same clock cycle** that `switch_in` is asserted.
- When `pe_switch_in = 0`: This block does nothing. But since there's **no `else` clause**, `weight_reg_active` is also driven by the `always_ff` block below — this creates a latch condition technically, but the design handles it through simulation.

**Why design it this way?** Because you want to load new weights into the shadow register while old weights are being used for computation. When you're ready to switch to the new weights, you assert `switch_in` and the entire array switches simultaneously.

---

### The Main Sequential Logic: `always_ff` Block

```systemverilog
    always_ff @(posedge clk or posedge rst) begin
```
`always_ff` means "this runs only when the clock rises or rst rises". Everything inside uses flip-flops (registers). This is sequential logic — it only changes at clock edges.

```systemverilog
        if (rst || !pe_enabled) begin
            pe_input_out <= 16'b0;
            weight_reg_active <= 16'b0;
            weight_reg_inactive <= 16'b0;
            pe_valid_out <= 0;
            pe_weight_out <= 16'b0;
            pe_switch_out <= 0;
```
When either `rst = 1` (reset) or `pe_enabled = 0` (this PE is disabled), all outputs and registers are forced to zero. The `<=` (non-blocking assignment) means "schedule this update for the end of the clock edge", which is how flip-flops work.

```systemverilog
        end else begin
            pe_valid_out <= pe_valid_in;
            pe_switch_out <= pe_switch_in;
```
In normal operation, both `valid` and `switch` are registered (delayed by exactly 1 clock cycle) and passed to the east (right). This is how valid signals propagate across the array — each PE delays them by 1 cycle, which ensures the data stays aligned as it flows through a chain of PEs.

```systemverilog
            if (pe_accept_w_in) begin
                weight_reg_inactive <= pe_weight_in;
                pe_weight_out <= pe_weight_in;
            end else begin
                pe_weight_out <= 0;
            end
```
If `accept_w_in = 1`, store the incoming weight in the **shadow register** (`weight_reg_inactive`), not the active one. Also pass the weight downward (`pe_weight_out`) so the PE below can load the same weight.

If not accepting, `pe_weight_out = 0` — no weight is pass through to the PE below.

```systemverilog
            if (pe_valid_in) begin
                pe_input_out <= pe_input_in;   // pass input to the right
                pe_psum_out <= mac_out;         // pass accumulated sum down
            end else begin
                pe_valid_out <= 0;
                pe_psum_out <= 16'b0;
            end
```
If `valid_in = 1` (real data is present):
- Pass the input rightward to the next PE.
- Output the MAC result (`mac_out`) downward.

If `valid_in = 0` (no valid data):
- Force `psum_out = 0` — no garbage sum passes down.
- Override `pe_valid_out = 0` even though it was already assigned above (the `else` here overwrites the earlier assignment).

**Note:** `pe_input_out` does NOT get cleared when `valid_in = 0`. It holds its last value. This is intentional — the input data value is latched and can be reused or inspected.

---

## 4. systolic.sv — The 2×2 Matrix Multiplier

### What is a Systolic Array?

Imagine you want to multiply two 2×2 matrices:

```
A × B = C

A = [a00  a01]    B = [b00  b01]
    [a10  a11]        [b10  b11]
```

In a systolic array, the weights (B matrix values) are pre-loaded into PEs. Then the input rows of A are fed in from the left, one row at a time. Data flows rightward and partial sums flow downward. After all rows have been fed in, the output matrix C is read from the bottom.

This design has a **2×2 grid** of 4 PEs:

```
         col1         col2
         ↓             ↓
row1: [pe11] → [pe12]
         ↓             ↓
row2: [pe21] → [pe22]
         ↓             ↓
     data_out_21   data_out_22
```

Naming convention: `pe_XY` where X = row, Y = column.

---

### Port Declarations

```systemverilog
module systolic #(
    parameter int SYSTOLIC_ARRAY_WIDTH = 2   // 2 columns
)
```

```systemverilog
    input logic [15:0] sys_data_in_11,    // input for row 1
    input logic [15:0] sys_data_in_21,    // input for row 2
    input logic sys_start,                // = valid signal for row 1
```
- `sys_data_in_11`: Row 1 data fed into PE(1,1).
- `sys_data_in_21`: Row 2 data fed into PE(2,1).
- `sys_start`: When high, the data on the inputs is valid. Goes directly into `pe11` and `pe21` as `pe_valid_in`.

```systemverilog
    output logic [15:0] sys_data_out_21,   // final MAC output, row 2, col 1
    output logic [15:0] sys_data_out_22,   // final MAC output, row 2, col 2
    output wire sys_valid_out_21,          // valid flag for data_out_21
    output wire sys_valid_out_22,          // valid flag for data_out_22
```
Outputs come from the **bottom row** of PEs (row 2). After 2 clock cycles, the result of the dot product appears here.

```systemverilog
    input logic [15:0] sys_weight_in_11,   // weight for column 1, row 1
    input logic [15:0] sys_weight_in_12,   // weight for column 2, row 1
    input logic sys_accept_w_1,            // load weight into column 1
    input logic sys_accept_w_2,            // load weight into column 2
    input logic sys_switch_in,             // switch all PEs to new weights
```
Weights are loaded from the top. `sys_weight_in_11` goes into `pe11`, which then passes it down to `pe21` via `pe_weight_out`. So you only need to provide the weight for the top PE in each column.

```systemverilog
    input logic [15:0] ub_rd_col_size_in,
    input logic ub_rd_col_size_valid_in
```
These tell the array how many columns of the input matrix are active. If you're multiplying a 2×1 matrix, you only want column 1 active. This lets you disable unused PEs to save energy and avoid corrupting outputs.

---

### Internal Wiring

```systemverilog
    logic [15:0] pe_input_out_11;     // connects pe11.east_out to pe12.west_in (NOT SHOWN IN HWDESIGN - pe12 gets input from pe11's output)
    logic [15:0] pe_input_out_21;     // connects pe21.east_out to pe22.west_in

    logic [15:0] pe_psum_out_11;      // connects pe11.south_out to pe21.north_in
    logic [15:0] pe_psum_out_12;      // connects pe12.south_out to pe22.north_in

    logic [15:0] pe_weight_out_11;    // weight passed from pe11 down to pe21
    logic [15:0] pe_weight_out_12;    // weight passed from pe12 down to pe22

    logic pe_switch_out_11;           // switch signal propagates diagonally
    logic pe_switch_out_12;

    wire pe_valid_out_11;             // valid propagates diagonally (pe11 → pe12, pe21)
    wire pe_valid_out_12;             // valid from pe12 → pe22

    logic [1:0] pe_enabled;           // bit 0 controls col1, bit 1 controls col2
```

These are just internal wires connecting the PEs together. Each PE's outputs connect to the next PE's inputs.

---

### PE Instantiations

```systemverilog
    pe pe11 (
        .pe_enabled(pe_enabled[0]),     // bit 0 enables column 1
        .pe_valid_in(sys_start),         // row 1 starts when sys_start is high
        .pe_valid_out(pe_valid_out_11),  // valid propagates right and down
        .pe_input_in(sys_data_in_11),    // input data from UB
        .pe_psum_in(16'b0),              // first PE in column: no accumulated sum yet
        .pe_weight_in(sys_weight_in_11), // weight from UB
        ...
    );
```

The first PE in a column always gets `pe_psum_in = 16'b0` — there is nothing to accumulate yet. The result just starts from scratch.

```systemverilog
    pe pe12 (
        .pe_enabled(pe_enabled[1]),       // bit 1 enables column 2
        .pe_valid_in(pe_valid_out_11),     // valid comes from pe11 (1 clock delay!)
        .pe_input_in(pe_input_out_11),     // data comes from pe11's east output
        .pe_psum_in(16'b0),               // first PE in its column: no prior sum
        .pe_weight_in(sys_weight_in_12),   // weight for column 2
        .pe_switch_in(pe_switch_out_11),   // switch propagates diagonally
        ...
    );
```

Notice `pe_valid_in(pe_valid_out_11)` — pe12 starts computing 1 clock cycle after pe11. This is the "wave" of computation advancing through the array.

```systemverilog
    pe pe21 (
        .pe_valid_in(pe_valid_out_11),     // also driven by pe11's valid!
        .pe_psum_in(pe_psum_out_11),       // accumulate pe11's partial sum
        .pe_weight_in(pe_weight_out_11),   // weight passed down from pe11
        .pe_psum_out(sys_data_out_21),     // FINAL RESULT for column 1
        ...
    );
```

pe21 is the **bottom** PE in column 1. Its `psum_out` is the final accumulated result for column 1 — it becomes `sys_data_out_21`.

```systemverilog
    pe pe22 (
        .pe_valid_in(pe_valid_out_12),     // valid comes from pe12 (2 cycles after start!)
        .pe_psum_in(pe_psum_out_12),       // accumulate pe12's partial sum
        .pe_psum_out(sys_data_out_22),     // FINAL RESULT for column 2
        ...
    );
```

pe22 is the bottom-right PE. Its result appears 1 cycle after pe21's result because it takes one more cycle for valid to reach pe12 → pe22.

---

### Enabling/Disabling Columns

```systemverilog
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            pe_enabled <= '0;        // reset: disable all PEs
        end else begin
            if(ub_rd_col_size_valid_in) begin
                pe_enabled <= (1 << ub_rd_col_size_in) - 1;
                // col_size=1 → (1<<1)-1 = 01 → only pe11, pe21 enabled
                // col_size=2 → (1<<2)-1 = 11 → all PEs enabled
            end
        end
    end
```

The expression `(1 << col_size) - 1` creates a bitmask:
- `col_size=1`: `0b10 - 1 = 0b01` → only bit 0 set → only column 1 active
- `col_size=2`: `0b100 - 1 = 0b11` → both bits set → both columns active

This is a clever bit trick to create a "how many columns are enabled" mask.

---

## 5. bias_child.sv — Adding a Bias to One Column

After the systolic array computes `Z = input × weight`, a neural network needs to add a **bias** value: `Z_biased = Z + bias`. Each output neuron has its own bias. Since we have 2 output columns, we need 2 bias adders.

`bias_child` handles one column.

```systemverilog
module bias_child (
    input logic clk,
    input logic rst,
    input logic signed [15:0] bias_scalar_in,    // the bias value (from memory)
    output logic bias_Z_valid_out,               // is the output valid?
    input wire signed [15:0] bias_sys_data_in,   // data from systolic array
    input wire bias_sys_valid_in,                // is the systolic data valid?
    output logic signed [15:0] bias_z_data_out   // result: data + bias
);
```

```systemverilog
    logic signed [15:0] z_pre_activation;

    fxp_add add_inst(
        .ina(bias_sys_data_in),
        .inb(bias_scalar_in),
        .out(z_pre_activation)
    );
```

`z_pre_activation` is a combinational wire — it **always** equals `data_in + bias_scalar_in` regardless of whether the data is valid. The computation is happening continuously in combinational logic.

The result is called `z_pre_activation` because in neural network terminology, `Z` (before applying the activation function) = weights × input + bias.

```systemverilog
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bias_Z_valid_out <= 1'b0;
            bias_z_data_out <= 16'b0;
        end else begin
            if (bias_sys_valid_in) begin    // real data is arriving
                bias_Z_valid_out <= 1'b1;
                bias_z_data_out <= z_pre_activation;   // register (latch) the result
            end else begin
                bias_Z_valid_out <= 1'b0;   // tell downstream: ignore this output
                bias_z_data_out <= 16'b0;   // also clear data to 0
            end
        end
    end
```

**Key point:** The output is only meaningful when `bias_Z_valid_out = 1`. When no valid data is arriving, both outputs are explicitly cleared to 0. There is NO data hold — it doesn't keep the last valid value. Each invalid cycle produces a 0 output.

Why register the result instead of using it combinationally? Because the output needs to stay stable for exactly 1 clock cycle so the next stage can read it reliably.

---

## 6. bias_parent.sv — Bias for Both Columns

```systemverilog
module bias_parent(
    input logic signed [15:0] bias_scalar_in_1,    // bias for column 1
    input logic signed [15:0] bias_scalar_in_2,    // bias for column 2
    ...
```

This module simply instantiates two `bias_child` modules — one for each column:

```systemverilog
    bias_child column_1 ( ... );
    bias_child column_2 ( ... );
```

**This pattern of "child + parent" modules is used throughout the design.** The "child" contains the actual logic for one channel. The "parent" is a wrapper that groups two children together (one per output column of the systolic array).

The parent module exists purely for clean wiring. It adds no logic.

---

## 7. leaky_relu_child.sv — The Activation Function

After `Z = input × weight + bias`, a neural network applies an **activation function**. This is needed to allow the network to learn non-linear patterns. Without it, stacking layers is pointless — the whole thing collapses to a single linear transformation.

This design uses **Leaky ReLU**:
```
output = input           if input ≥ 0
output = input × α       if input < 0
```

Where `α` (alpha, or `leak_factor`) is a small number like 0.01. This way, negative inputs are not completely blocked — they "leak" through at a reduced scale.

A plain ReLU would set negative outputs to exactly 0. Leaky ReLU prevents "dying neurons" — units that get stuck at 0 forever.

```systemverilog
module leaky_relu_child (
    input logic clk,
    input logic rst,
    input logic lr_valid_in,
    input logic signed [15:0] lr_data_in,
    input logic signed [15:0] lr_leak_factor_in,   // the α factor
    output logic signed [15:0] lr_data_out,
    output logic lr_valid_out
);
```

```systemverilog
    logic signed [15:0] mul_out;
    fxp_mul mul_inst(
        .ina(lr_data_in),
        .inb(lr_leak_factor_in),
        .out(mul_out)
    );
```

This multiplier is always computing `lr_data_in × lr_leak_factor_in` combinationally — even when the data is not valid. The register block below decides whether to use `mul_out` or `lr_data_in` based on the sign.

```systemverilog
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lr_data_out <= 16'b0;
            lr_valid_out <= 0;
        end else begin
            if (lr_valid_in) begin           // only process real data
                if (lr_data_in >= 0) begin   // positive: pass through unchanged
                    lr_data_out <= lr_data_in;
                end else begin               // negative: scale it down
                    lr_data_out <= mul_out;
                end
                lr_valid_out <= 1;
            end else begin
                lr_valid_out <= 0;
                lr_data_out <= 16'b0;        // clear outputs when no valid data
            end
        end
    end
```

**Sign detection:** `lr_data_in >= 0` in SystemVerilog compares the **signed** value. Since `lr_data_in` is declared `signed [15:0]`, bit [15] being 1 makes the number negative. So this comparison is just checking bit [15].

**Why both branches produce a 0 output when invalid:** Same as `bias_child` — no data hold, always clean outputs. Downstream modules must check `lr_valid_out` to know when to trust the data.

---

## 8. leaky_relu_parent.sv — Activation for Both Columns

Same pattern as `bias_parent`. Instantiates two `leaky_relu_child` modules:

```systemverilog
module leaky_relu_parent (
    input logic signed [15:0] lr_leak_factor_in,   // shared α across both columns
    ...
```

**Note:** Both columns share the same `lr_leak_factor_in`. This makes sense because the leak factor is a hyperparameter of the layer, not per-neuron. All neurons in the layer use the same Leaky ReLU setting.

---

## 9. loss_child.sv — Measuring the Error (Backprop Stage 1)

This module begins the **backward pass** (backpropagation). The goal of backprop is to figure out how much each weight contributed to the prediction error, so we can adjust weights to reduce that error.

**What is MSE?** Mean Squared Error. If the network predicted H (hypothesis) but the correct answer was Y (label), the error is:

```
MSE loss = (1/N) × Σ (H - Y)²
```

The **gradient** of MSE with respect to H is:

```
dLoss/dH = (2/N) × (H - Y)
```

This is what `loss_child` computes. It doesn't compute the actual loss value — it computes the **gradient** (the derivative) that will be used to update weights.

```systemverilog
module loss_child (
    input logic signed [15:0] H_in,                        // network's prediction
    input logic signed [15:0] Y_in,                        // correct label
    input logic valid_in,                                   // is data valid?
    input logic signed [15:0] inv_batch_size_times_two_in, // (2/N) as fixed-point
    output logic signed [15:0] gradient_out,               // the gradient (2/N)*(H-Y)
    output logic valid_out
);
```

The value `inv_batch_size_times_two_in` is `2/N` pre-computed outside and passed in as a fixed-point constant. `N` is the batch size. It's called "inverse batch size times two" because it represents `2 × (1/N)`.

```systemverilog
    logic signed [15:0] diff_stage1;
    logic signed [15:0] final_gradient;

    fxp_addsub subtractor (
        .ina(H_in),
        .inb(Y_in),
        .sub(1'b1),         // subtract: H - Y
        .out(diff_stage1),
        .overflow()
    );

    fxp_mul multiplier (
        .ina(diff_stage1),
        .inb(inv_batch_size_times_two_in),
        .out(final_gradient),   // result: (2/N) × (H - Y)
        .overflow()
    );
```

Both operations are **combinational** and chain together:
1. `diff_stage1 = H_in - Y_in` (always computing, instant)
2. `final_gradient = diff_stage1 × (2/N)` (also always computing)

```systemverilog
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            gradient_out <= '0;
            valid_out <= '0;
        end else begin
            valid_out <= valid_in;
            gradient_out <= final_gradient;   // ALWAYS registered, not just when valid!
        end
    end
```

**IMPORTANT DESIGN CHOICE:** `gradient_out` is registered on **every clock cycle**, regardless of `valid_in`. When `valid_in = 0`, the hardware is still computing `final_gradient` from whatever garbage `H_in` and `Y_in` values are on the bus, and registering that garbage into `gradient_out`.

This is intentional — the downstream consumer (the gradient descent module) checks `valid_out` before using `gradient_out`. The garbage value with `valid_out = 0` is simply ignored.

`valid_out` does correctly track `valid_in` — it's just a 1-cycle register delay.

---

## 10. loss_parent.sv — Error for Both Columns

Again, wraps two `loss_child` instances, one per column. Both children share the same `inv_batch_size_times_two_in` constant (the batch size is a property of the training run, not per-neuron).

---

## 11. leaky_relu_derivative_child.sv — Backprop Through the Activation

During backpropagation, when a gradient passes through the Leaky ReLU function going backward, we need to apply the **derivative** of Leaky ReLU:

```
d(LeakyReLU(H))/dH = 1       if H ≥ 0   → gradient passes through unchanged
d(LeakyReLU(H))/dH = α       if H < 0   → gradient is scaled by α
```

The key difference from the forward pass is: **the sign decision is based on H (the original activation from the forward pass), not on the gradient itself.**

```systemverilog
module leaky_relu_derivative_child(
    input logic lr_d_valid_in,
    input logic signed [15:0] lr_d_data_in,      // the gradient flowing backward
    input logic signed [15:0] lr_leak_factor_in,  // the α factor
    input logic signed [15:0] lr_d_H_data_in,     // H from the forward pass!
    output logic lr_d_valid_out,
    output logic signed [15:0] lr_d_data_out
);
```

`lr_d_H_data_in` is what makes this module different. During the forward pass, the activation values H were saved to memory. Now, during the backward pass, we read them back to know which ReLU branch was taken.

```systemverilog
    fxp_mul mul_inst(
        .ina(lr_d_data_in),          // gradient signal
        .inb(lr_leak_factor_in),
        .out(mul_out)
    );
```

The multiplier pre-computes `gradient × α` combinationally.

```systemverilog
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lr_d_data_out <= 16'b0;
            lr_d_valid_out <= 0;
        end else begin
            lr_d_valid_out <= lr_d_valid_in;     // plain register — no override
            if (lr_d_valid_in) begin
                if (lr_d_H_data_in >= 0) begin   // H was positive in forward pass
                    lr_d_data_out <= lr_d_data_in;   // gradient passes through
                end else begin                   // H was negative in forward pass
                    lr_d_data_out <= mul_out;        // scale gradient by α
                end
            end else begin
                lr_d_data_out <= 16'b0;
            end
        end
    end
```

**Critical difference from `leaky_relu_child`:** In `leaky_relu_child`, the `else` branch overrides `lr_valid_out <= 0`. Here, `lr_d_valid_out <= lr_d_valid_in` is written **unconditionally** (outside the if/else), so it is always registered, even when `valid_in = 0`. The net result is the same — `valid_out` tracks `valid_in` with 1 cycle delay — but the code structure is different.

---

## 12. leaky_relu_derivative_parent.sv — Derivative for Both Columns

Wraps two `leaky_relu_derivative_child` instances. Both children share the same `lr_leak_factor_in` but have independent `H` inputs (one H value per column from the forward pass).

---

## 13. gradient_descent.sv — Updating Weights

This is the learning step. After computing gradients (how much the loss changes with respect to weights), we update the weights using **gradient descent**:

```
W_new = W_old - learning_rate × gradient
```

This makes the weight "move" in the direction that reduces the loss.

```systemverilog
module gradient_descent (
    input logic [15:0] lr_in,               // learning rate (hyperparameter)
    input logic [15:0] value_old_in,        // current weight or bias value
    input logic [15:0] grad_in,             // gradient for this weight
    input logic grad_descent_valid_in,      // is input data valid?
    input logic grad_bias_or_weight,        // 0 = updating bias, 1 = updating weight
    output logic [15:0] value_updated_out,  // new weight value
    output logic grad_descent_done_out      // one cycle pulse when update is done
);
```

```systemverilog
    logic [15:0] sub_value_out;   // result of the subtraction
    logic [15:0] sub_in_a;        // what we're subtracting from (changes for bias mode)
    logic [15:0] mul_out;         // learning_rate × gradient

    fxp_mul mul_inst (
        .ina(grad_in),
        .inb(lr_in),
        .out(mul_out),         // mul_out = grad × lr
    );

    fxp_addsub sub_inst (
        .ina(sub_in_a),
        .inb(mul_out),
        .sub(1'b1),            // subtract: sub_in_a - (grad × lr)
        .out(sub_value_out),
    );
```

The formula `W_new = W_old - lr × grad` is computed in two combinational stages:
1. `mul_out = grad × lr`
2. `sub_value_out = sub_in_a - mul_out`

---

### Weight vs. Bias Mode

```systemverilog
    always_comb begin
        case(grad_bias_or_weight)
            1'b0: begin    // BIAS MODE
                if(grad_descent_done_out) begin
                    sub_in_a = value_updated_out;  // use the previously updated value!
                end else begin
                    sub_in_a = value_old_in;       // first update: start from old value
                end
            end

            1'b1: begin    // WEIGHT MODE
                sub_in_a = value_old_in;           // always use the old value
            end
        endcase
    end
```

**Weight mode (`grad_bias_or_weight = 1`):** Each update is independent. Always subtract from `value_old_in`. Simple one-shot update.

**Bias mode (`grad_bias_or_weight = 0`):** The bias gradient is accumulated over the batch. After the first update, we use `value_updated_out` as the new starting point, then apply the next gradient on top of that. This is how gradients from multiple batch samples get summed together before applying the final update.

`grad_descent_done_out` serves as the "is there already a valid updated value to chain from?" flag.

```systemverilog
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            value_updated_out <= '0;
            grad_descent_done_out <= '0;
        end else begin
            grad_descent_done_out <= grad_descent_valid_in;  // 1-cycle delay
            if(grad_descent_valid_in) begin
                value_updated_out <= sub_value_out;    // register the result
            end else begin
                value_updated_out <= '0;               // clear when idle
            end
        end
    end
```

`grad_descent_done_out` is simply the registered version of `grad_descent_valid_in` — it goes high 1 clock cycle after valid_in goes high. This signals to the memory system that a valid updated value is ready to be written back.

---

## 14. control_unit.sv — The Instruction Decoder

This module is the simplest in the design: it decodes a single large **instruction word** into many individual signals.

Think of it like reading a packet header: the controller sends an 88-bit "command" to the TPU and the control unit splits it into named fields.

```systemverilog
module control_unit (
    input logic [87:0] instruction,   // 88-bit command from outside
    
    output logic sys_switch_in,              // bit  0
    output logic ub_rd_start_in,             // bit  1
    output logic ub_rd_transpose,            // bit  2
    output logic ub_wr_host_valid_in_1,      // bit  3
    output logic ub_wr_host_valid_in_2,      // bit  4
    output logic [1:0] ub_rd_col_size,       // bits 6:5
    output logic [7:0] ub_rd_row_size,       // bits 14:7
    output logic [1:0] ub_rd_addr_in,        // bits 16:15
    output logic [2:0] ub_ptr_sel,           // bits 19:17
    output logic [15:0] ub_wr_host_data_in_1,// bits 35:20
    output logic [15:0] ub_wr_host_data_in_2,// bits 51:36
    output logic [3:0] vpu_data_pathway,     // bits 55:52
    output logic [15:0] inv_batch_size_times_two_in, // bits 71:56
    output logic [15:0] vpu_leak_factor_in   // bits 87:72
);
```

The instruction bit map:

| Bit range | Field | Purpose |
|-----------|-------|---------|
| [0]       | sys_switch_in | Activate new weights in systolic array |
| [1]       | ub_rd_start_in | Trigger a memory read |
| [2]       | ub_rd_transpose | Read the matrix transposed |
| [3]       | ub_wr_host_valid_in_1 | Host is writing data into column 1 of memory |
| [4]       | ub_wr_host_valid_in_2 | Host is writing data into column 2 of memory |
| [6:5]     | ub_rd_col_size | How many columns to read |
| [14:7]    | ub_rd_row_size | How many rows to read |
| [16:15]   | ub_rd_addr_in | Which memory address to start reading from |
| [19:17]   | ub_ptr_sel | Which data type (weights/biases/activations/etc.) to read |
| [35:20]   | ub_wr_host_data_in_1 | Data value to write from host to column 1 |
| [51:36]   | ub_wr_host_data_in_2 | Data value to write from host to column 2 |
| [55:52]   | vpu_data_pathway | Which VPU stages to activate (forward/backward/etc.) |
| [71:56]   | inv_batch_size_times_two_in | 2/N constant |
| [87:72]   | vpu_leak_factor_in | Leaky ReLU α factor |

Implementation — every output is a simple bit slice:

```systemverilog
    assign sys_switch_in = instruction[0];
    assign ub_rd_start_in = instruction[1];
    ...
    assign vpu_leak_factor_in = instruction[87:72];
```

**All `assign` statements are purely combinational** — no clock, no flip-flops. Any change to `instruction` immediately changes all outputs. This is the hardware equivalent of a bit-field struct in C.

---

## 15. vpu.sv — The Post-Processing Pipeline

VPU stands for **Vector Processing Unit**. It is the multi-stage pipeline that processes the systolic array's output. Depending on the current phase of training, different stages are enabled.

### The Four Stages

```
sys_out → [BIAS] → [LEAKY_RELU] → [LOSS] → [LEAKY_RELU_DERIVATIVE] → vpu_out
```

Each stage can be bypassed with a combinational mux. The 4-bit `vpu_data_pathway` field controls which stages are active:

| Pathway bits | Meaning | Stages active | Latency |
|--------------|---------|---------------|---------|
| `1100` | Forward pass | Bias + Leaky ReLU | 2 cycles |
| `1111` | Transition | All 4 stages | 4 cycles |
| `0001` | Backward pass | Leaky ReLU Derivative only | 1 cycle |
| `0000` | Passthrough | None | 0 cycles (combinational) |

---

### Internal Wiring Declarations

Before the module instances, `vpu.sv` declares a large set of intermediate signals:

```systemverilog
    // bias to lr intermediate values
    logic [15:0] b_to_lr_data_in_1;
    logic b_to_lr_valid_in_1;
    ...

    // lr to loss intermediate values
    logic [15:0] lr_to_loss_data_in_1;
    ...

    // loss to lrd intermediate values
    logic [15:0] loss_to_lrd_data_in_1;
    ...
```

These are "staging lanes" between stages. In the `always @(*)` routing block, each lane is either connected to a stage's output (if that stage is active) or bypassed by connecting it directly to the previous lane. This creates the configurable pipeline.

There is also a "last H cache":

```systemverilog
    logic [15:0] last_H_data_1_in;
    logic [15:0] last_H_data_1_out;
```

In the transition pathway (`1111`), the H values (activations from Leaky ReLU) need to be passed into the Loss module. But by the time they pass through the Loss stage, they also need to feed the Leaky ReLU Derivative stage. The cache registers them for one cycle to synchronize timing.

---

### Module Instantiations

```systemverilog
    bias_parent bias_parent_inst ( ... );
    leaky_relu_parent leaky_relu_parent_inst ( ... );
    loss_parent loss_parent_inst ( ... );
    leaky_relu_derivative_parent leaky_relu_derivative_parent_inst ( ... );
```

All four processing stages are **always instantiated**. The pathway routing logic (below) controls whether they receive real data or zeros.

---

### The Routing Logic (`always @(*)`)

This is the most important part of VPU. The entire block is `always @(*)` (combinational) — it runs instantly whenever inputs change.

```systemverilog
    always @(*) begin
        if (rst) begin
            // zero everything out
            ...
        end else begin
```

**Bias stage routing (bit 3 of pathway):**

```systemverilog
            if(vpu_data_pathway[3]) begin
                // Route input into bias module
                bias_data_1_in = vpu_data_in_1;
                bias_valid_1_in = vpu_valid_in_1;

                // Route bias output into next stage
                b_to_lr_data_in_1 = bias_z_data_out_1;
                b_to_lr_valid_in_1 = bias_valid_1_out;
            end else begin
                // Bypass bias: feed input directly to next stage
                bias_data_1_in = 16'b0;     // starve the bias module (don't waste power)
                bias_valid_1_in = 1'b0;

                b_to_lr_data_in_1 = vpu_data_in_1;    // skip straight to next stage
                b_to_lr_valid_in_1 = vpu_valid_in_1;
            end
```

When bias is **enabled** (bit=1): real data flows through the bias module; its output feeds the next stage.
When bias is **disabled** (bit=0): the bias module gets zeroed inputs (it does nothing useful), and the input bypasses directly to the next stage.

The same pattern repeats for each of the four stages. Each stage writes into the "lane" that connects it to the next stage. If skipped, that lane is populated by the lane before it.

**Loss stage — special: H caching:**

```systemverilog
            if(vpu_data_pathway[1]) begin
                // Loss stage active
                loss_data_1_in = lr_to_loss_data_in_1;
                ...

                // Save the H matrix COMING OUT OF LEAKY RELU
                last_H_data_1_in = lr_data_1_out;
                lr_d_H_in_1 = last_H_data_1_out;    // use CACHED H for derivative
            end else begin
                // Loss stage bypassed: use H from memory (UB)
                lr_d_H_in_1 = H_in_1;
            end
```

When the loss stage is active (transition pathway), it means both Leaky ReLU and Leaky ReLU Derivative are also active. The H values that came out of Leaky ReLU need to be fed into Leaky ReLU Derivative. But the derivative stage runs AFTER the loss stage, so the H values need to be stored for one extra cycle — that's what `last_H_data_1_out` (the cached version) is for.

When the loss stage is NOT active (pure backward pass), the H values come directly from memory (`H_in_1` from the UB).

---

### H Cache Sequential Logic

```systemverilog
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            last_H_data_1_out <= 0;
        end else begin
            if (vpu_data_pathway[1]) begin
                last_H_data_1_out <= last_H_data_1_in;   // register the H value
            end else begin
                last_H_data_1_out <= 0;    // clear when not needed
            end
        end
    end
```

Simple: when the loss stage is active, the H value from Leaky ReLU's output is registered and available on the next cycle for the Leaky ReLU Derivative stage.

---

## 16. unified_buffer.sv — The Memory System

This is the largest and most complex module. The **Unified Buffer (UB)** is a 128-word (128 × 16-bit = 2048 bits) RAM that stores:
- Input matrices (features)
- Weight matrices
- Bias vectors
- Label matrices (Y)
- Activation matrices (H) from the forward pass
- Gradient matrices from the backward pass
- Updated weights after gradient descent

It also contains **2 gradient_descent module instances** (one per column) and all the address generation logic to feed data to every other part of the design.

### Memory Declaration

```systemverilog
    logic [15:0] ub_memory [0:UNIFIED_BUFFER_WIDTH-1];
```

This is literally a 128-element array of 16-bit values — a register file. All 128 words are accessible every clock cycle.

### Seven Read "Channels"

The UB has 7 different read pointers, each feeding a different destination:

| Pointer | `ptr_sel` value | Feeds | Used when |
|---------|----------------|-------|-----------|
| `rd_input_ptr` | 0 | Left side of systolic array (input data) | Forward pass |
| `rd_weight_ptr` | 1 | Top of systolic array (weights) | Weight loading |
| `rd_bias_ptr` | 2 | Bias modules in VPU | Forward pass |
| `rd_Y_ptr` | 3 | Loss modules in VPU (labels) | Transition pass |
| `rd_H_ptr` | 4 | Leaky ReLU derivative in VPU (saved activations) | Backward pass |
| `rd_grad_bias_ptr` | 5 | Gradient descent modules (bias update) | After backward pass |
| `rd_grad_weight_ptr` | 6 | Gradient descent modules (weight update) | After backward pass |

### Write Channels

The UB has two write sources:
1. **From VPU:** computational results (activations, gradients) are written back automatically
2. **From host:** the initial weight/bias/input data is written by the external world (a computer, testbench, etc.) via `ub_wr_host_data_in`

### Memory Write Logic

```systemverilog
for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin   // NOTE: DECREMENT for row-major order
    if (ub_wr_valid_in[i]) begin
        ub_memory[wr_ptr] <= ub_wr_data_in[i];
        wr_ptr = wr_ptr + 1;    // blocking assignment (exception to rule)
    end else if (ub_wr_host_valid_in[i]) begin
        ub_memory[wr_ptr] <= ub_wr_host_data_in[i];
        wr_ptr = wr_ptr + 1;
    end
end
```

**Why decrement?** Data from VPU comes out as `[column_1, column_2]`. Human-readable row-major order stores data as `[row0_col0, row0_col1, row1_col0, ...]`. Decrementing the loop ensures column 0 goes into the lower address, column 1 into the next — matching row-major layout.

**Why mix blocking (`=`) and non-blocking (`<=`) assignments?** The comment in the code acknowledges this is not ideal. The `wr_ptr` uses a blocking assignment so it increments immediately within the same clock cycle, letting multiple columns be written sequentially in one cycle. The actual memory write uses non-blocking. This works in simulation but could cause issues in synthesis — hence the TODO comment.

### Read Logic Pattern

Each of the 7 read channels follows the same pattern:

```systemverilog
// if we still have data to read (time_counter hasn't expired yet)
if (rd_input_time_counter + 1 < rd_input_row_size + rd_input_col_size) begin
    // for each column, check if this counter tick falls within its active window
    for (int i = SYSTOLIC_ARRAY_WIDTH-1; i >= 0; i--) begin
        if(rd_input_time_counter >= i &&
           rd_input_time_counter < rd_input_row_size + i &&
           i < rd_input_col_size) begin
            ub_rd_input_valid_out[i] <= 1'b1;
            ub_rd_input_data_out[i] <= ub_memory[rd_input_ptr];
            rd_input_ptr = rd_input_ptr + 1;
        end else begin
            ub_rd_input_valid_out[i] <= 1'b0;
            ub_rd_input_data_out[i] <= '0;
        end
    end
    rd_input_time_counter <= rd_input_time_counter + 1;
end else begin
    // done: reset the channel
    rd_input_ptr <= 0;
    ...
end
```

**How the staggering works:** For a 2×2 matrix on a 2-column bus:
- `time_counter = 0`: column 0 is valid (sends row 0, col 0). Column 1 waits.
- `time_counter = 1`: both column 0 and column 1 are valid (column 0 sends row 1, col 0; column 1 sends row 0, col 1).
- `time_counter = 2`: only column 1 is valid (sends row 1, col 1).

This **diagonal stagger** is exactly what the systolic array expects — each column starts one cycle later than the column to its left, so each PE gets the right input at the right time.

### The `ptr_sel` Switch Statement (Combinational)

```systemverilog
    always_comb begin
        if (ub_rd_start_in) begin
            case (ub_ptr_select)
                0: begin   // set up input read
                    rd_input_ptr = ub_rd_addr_in;
                    rd_input_row_size = ub_rd_row_size;
                    ...
                end
                1: begin   // set up weight read
                    ...
                    // Also compute starting pointer position for column-major access
                    rd_weight_ptr = ub_rd_addr_in + ub_rd_row_size*ub_rd_col_size - ub_rd_col_size;
                    ...
                    ub_rd_col_size_valid_out = 1'b1;   // tell systolic how many columns
                end
                2: begin   // set up bias read ... end
                3: begin   // set up Y read ... end
                4: begin   // set up H read ... end
                5: begin   // set up bias gradient descent
                    grad_bias_or_weight = 1'b0;    // bias mode
                    ...
                end
                6: begin   // set up weight gradient descent
                    grad_bias_or_weight = 1'b1;    // weight mode
                    ...
                end
            endcase
        end
    end
```

When `ub_rd_start_in` is asserted with a `ptr_select` value, the UB sets up the corresponding read channel with the starting address, dimensions, and configuration. The actual reading then happens in the sequential always block on subsequent clock cycles.

### Weight Address Calculation (Transposed)

```systemverilog
rd_weight_ptr = ub_rd_addr_in + ub_rd_col_size - 1;            // transposed
rd_weight_ptr = ub_rd_addr_in + ub_rd_row_size*ub_rd_col_size - ub_rd_col_size;  // normal
```

Weights are loaded column-by-column into the systolic array from the **top**. In memory they're stored row-major. To load weights column-by-column, the address pointer must jump by `col_size` each step rather than 1. The starting address is calculated to point to the correct starting position depending on transpose mode.

---

## 17. tpu.sv — Wiring It All Together

This is the **top-level module**. It contains no logic of its own — it only instantiates and connects:
1. `unified_buffer` — memory
2. `systolic` — matrix multiplier
3. `vpu` — post-processing pipeline

### Port Connections

```systemverilog
    assign ub_wr_data_in[0] = vpu_data_out_1;
    assign ub_wr_data_in[1] = vpu_data_out_2;
    assign ub_wr_valid_in[0] = vpu_valid_out_1;
    assign ub_wr_valid_in[1] = vpu_valid_out_2;
```

These four lines close the **feedback loop**: VPU outputs feed back into the UB as write data. This is how the results of every computation get stored back for use in the next step.

The rest of `tpu.sv` is boilerplate connections between the three modules. The interesting parts:

```systemverilog
    .sys_start(ub_rd_input_valid_out_0),   // UB's valid output becomes the start signal
```

The systolic array starts computing when the UB's read channel declares its data valid. No separate start signal needed — the valid protocol handles everything.

```systemverilog
    .sys_weight_in_11(ub_rd_weight_data_out_0),
    .sys_accept_w_1(ub_rd_weight_valid_out_0),
```

The weight valid signal from the UB becomes `sys_accept_w` — the systolic array loads a new weight on every cycle that the UB sends a valid weight.

---

## 18. How Everything Connects — The Big Picture

### Forward Pass (predicting outputs):

```
1. Host writes input matrix, weight matrix, bias vector into UB
2. Send instruction ptr_sel=1 (weights) → UB sends weights to systolic PEs (loading phase)
3. Assert sys_switch_in → PEs make new weights "live"
4. Send instruction ptr_sel=0 (inputs) + ptr_sel=2 (biases) + vpu_pathway=1100
5. UB sends input rows to systolic array
6. Systolic computes input×weight (2 cycles) → sends to VPU
7. VPU: Bias adds bias → Leaky ReLU applies activation → output to UB
8. UB stores the activations (H values) at wr_ptr
```

### Transition Pass (computing loss gradients):

```
1. Load Y (labels) into UB (ptr_sel=3), H already in UB from forward pass
2. Send instruction vpu_pathway=1111 (all stages)
3. UB sends H through systolic (just passes through, no new weights) to VPU
4. VPU: Bias → Leaky ReLU → Loss (computes 2/N*(H-Y)) → Leaky ReLU Derivative
5. Result (dL/dH) written back to UB
```

### Backward Pass (computing weight/bias gradients):

```
1. dL/dH is in UB; load H values into ptr_sel=4
2. vpu_pathway=0001 (derivative only)
3. UB sends gradient×input through systolic → gradient with respect to weights
4. UB sends to gradient_descent modules → W_new = W_old - lr × grad
5. Updated weights written back to UB
```

### The Clock Cycle Count for a Forward Pass

With a 2×2 weight matrix and 2-row input batch:
- Weight loading: 2 cycles (one per PE column, staggered)
- Input feeding: 3 cycles (2-row input + 1 overlap due to stagger)
- Systolic output delay: 2 cycles for col 1, 3 for col 2
- Bias: +1 cycle
- Leaky ReLU: +1 cycle

Total from start to final output: about 6-7 clock cycles.

---

## Summary Table — All Modules at a Glance

| Module | Type | Purpose | Key operation |
|--------|------|---------|---------------|
| `fixedpoint.sv` | Library | Signed arithmetic | fxp_add, fxp_mul, fxp_addsub |
| `pe.sv` | Sequential | One MAC unit | `psum = (input × weight) + psum_in` |
| `systolic.sv` | Mixed | 2×2 mat-mul grid | 4 PEs wired in 2 rows × 2 cols |
| `bias_child.sv` | Sequential | Add bias to one column | `output = data + bias` (registered) |
| `bias_parent.sv` | Structural | Wrap 2 bias children | No logic |
| `leaky_relu_child.sv` | Sequential | Activation function | Pass if ≥0, scale if <0 |
| `leaky_relu_parent.sv` | Structural | Wrap 2 ReLU children | No logic |
| `loss_child.sv` | Mixed | MSE gradient | `grad = (2/N) × (H - Y)` |
| `loss_parent.sv` | Structural | Wrap 2 loss children | No logic |
| `leaky_relu_derivative_child.sv` | Sequential | Backprop through ReLU | Pass if H≥0, scale if H<0 |
| `leaky_relu_derivative_parent.sv` | Structural | Wrap 2 derivative children | No logic |
| `gradient_descent.sv` | Mixed | Weight update | `W = W - lr × grad` |
| `control_unit.sv` | Combinational | Instruction decoder | 88-bit field splitter |
| `vpu.sv` | Mixed | Configurable pipeline | 4-stage routing + H cache |
| `unified_buffer.sv` | Sequential | 128-word memory + GD | 7 read channels, write-back logic |
| `tpu.sv` | Structural | Top-level integration | Connects UB + systolic + VPU |
