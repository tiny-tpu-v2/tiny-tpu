# tiny-tpu — Full Design Explanation

> **Goal of this document:** Explain every part of the tiny-tpu hardware design starting from zero. No chip-design background is assumed. We build up from the smallest piece all the way to the complete system.

---

## Table of Contents

1. [What Problem Are We Solving?](#1-what-problem-are-we-solving)
2. [How Numbers Are Stored — Fixed-Point Arithmetic](#2-how-numbers-are-stored--fixed-point-arithmetic)
3. [Processing Element (PE) — The Smallest Building Block](#3-processing-element-pe--the-smallest-building-block)
4. [Systolic Array — A Grid of PEs Working Together](#4-systolic-array--a-grid-of-pes-working-together)
5. [Unified Buffer (UB) — The Chip's Memory](#5-unified-buffer-ub--the-chips-memory)
6. [Vector Processing Unit (VPU) — The Post-Processing Pipeline](#6-vector-processing-unit-vpu--the-post-processing-pipeline)
   - [6a. Bias Module](#6a-bias-module)
   - [6b. Leaky ReLU Module](#6b-leaky-relu-module)
   - [6c. Loss Module (MSE Gradient)](#6c-loss-module-mse-gradient)
   - [6d. Leaky ReLU Derivative Module](#6d-leaky-relu-derivative-module)
7. [Gradient Descent Module — How the Chip Learns](#7-gradient-descent-module--how-the-chip-learns)
8. [Control Unit — The Instruction Decoder](#8-control-unit--the-instruction-decoder)
9. [TPU — How Everything Connects](#9-tpu--how-everything-connects)
10. [The Three Operating Modes](#10-the-three-operating-modes)
11. [A Complete Training Step — From Input to Output](#11-a-complete-training-step--from-input-to-output)
12. [File Map](#12-file-map)

---

## 1. What Problem Are We Solving?

A **Tensor Processing Unit (TPU)** is a chip built specifically to run **neural networks** fast. A neural network learns by repeatedly doing one core calculation:

$$\text{output} = \text{activation}(W \cdot x + b)$$

Where:
- $x$ = input data
- $W$ = weight matrix (numbers the network is learning)
- $b$ = bias vector (learned offsets)
- $\text{activation}$ = a non-linear function applied at the end (here: Leaky ReLU)

A regular CPU does these multiplications one at a time. A TPU does **many simultaneously** in dedicated hardware. This chip is a minimal 2×2 version — small enough to understand fully, but real enough to run an actual neural network forward and backward pass.

---

## 2. How Numbers Are Stored — Fixed-Point Arithmetic

**File:** `src/fixedpoint.sv`

Real numbers like `3.14` or `-0.5` are awkward for digital hardware. This chip uses **Q8.8 fixed-point format**: every value is a 16-bit integer where the true value is that integer divided by 256.

```
Bit layout of every 16-bit value:
+-------------------------------------+
¦  bits [15:8]     ¦  bits [7:0]      ¦
¦  integer part    ¦  fractional part ¦
¦  (signed, 8 bit) ¦  (1/256 units)   ¦
+-------------------------------------+

Real value = raw_integer / 256
```

**Examples:**

| Raw value (decimal) | Hex    | Real value | Why |
|---------------------|--------|------------|-----|
| 256                 | 0x0100 | 1.0        | 256 / 256 = 1.0 |
| 384                 | 0x0180 | 1.5        | 384 / 256 = 1.5 |
| 128                 | 0x0080 | 0.5        | 128 / 256 = 0.5 |
| -256 (signed)       | 0xFF00 | -1.0       | -256 / 256 = -1.0 |
| 0                   | 0x0000 | 0.0        | zero |

**Sign rule:** Bit 15 = `0` ? positive or zero. Bit 15 = `1` ? negative (two's complement).

**Why not floating point?** Floating-point (like Python's `float`) needs complex exponent hardware. Fixed-point is plain integer arithmetic with a known scale factor (256), so the chip stays small and fast.

The `fixedpoint.sv` file provides three arithmetic modules used throughout the design:

| Module | Operation | Used by |
|--------|-----------|---------|
| `fxp_add` | `a + b` | bias_child |
| `fxp_addsub` | `a + b` or `a - b` (flag-controlled) | loss_child, gradient_descent |
| `fxp_mul` | `a × b` | pe, leaky_relu_child, leaky_relu_derivative_child, gradient_descent |

All three are **purely combinational** — they produce results instantly in the same clock cycle, with no internal registers.

---

## 3. Processing Element (PE) — The Smallest Building Block

**File:** `src/pe.sv`

The **Processing Element (PE)** is the tiniest computing unit on the chip. Each clock cycle it performs one **multiply-accumulate (MAC)**:

$$\text{psum\_out} = (\text{input} \times \text{weight}) + \text{psum\_in}$$

Think of it as one worker on an assembly line: take the number coming from the left, multiply it by your stored weight, add the partial result coming from above, and pass the new total downward.

### The Four Sides of a PE

```
             NORTH
       pe_weight_in  pe_psum_in
             ¦             ¦
             ?             ?
WEST ------[  PE  ]------? EAST
pe_input_in  ¦   pe_input_out
             ?
            SOUTH
       pe_psum_out  pe_weight_out
```

| Side | Signal | Direction | Carries |
|------|--------|-----------|---------|
| West (left)  | `pe_input_in`    | in  | Input data flowing across the row |
| West         | `pe_valid_in`    | in  | 1 = this cycle carries real data |
| West         | `pe_switch_in`   | in  | Pulse to swap shadow ? active weight |
| West         | `pe_enabled`     | in  | 0 = disable and zero-out this PE |
| North (top)  | `pe_psum_in`     | in  | Partial sum arriving from above |
| North        | `pe_weight_in`   | in  | New weight value being loaded |
| North        | `pe_accept_w_in` | in  | 1 = load the arriving weight |
| East (right) | `pe_input_out`   | out | `pe_input_in` forwarded right (1-cycle delay) |
| East         | `pe_valid_out`   | out | `pe_valid_in` forwarded right (1-cycle delay) |
| East         | `pe_switch_out`  | out | `pe_switch_in` forwarded right (1-cycle delay) |
| South (bottom)| `pe_psum_out`   | out | `(input × weight) + psum_in` — the MAC result |
| South         | `pe_weight_out`  | out | Loaded weight passed down to the next row |
| —            | `pe_overflow_out`| out | Sticky flag: stays 1 once any overflow ever occurs |

### Double-Buffered Weights

Each PE has **two weight registers**:
- `weight_reg_active` — used **right now** for multiplication
- `weight_reg_inactive` — the shadow, being pre-loaded with the **next** weight in the background

This is like a DJ: the next track is already cued up (shadow) while the current one plays (active). When `pe_switch_in` fires, the shadow becomes active instantly — computation never pauses.

### What Happens Each Clock Cycle

1. `pe_valid_out` and `pe_switch_out` are always sampled and forwarded (1-cycle delay)
2. If `pe_switch_in = 1` ? copy `weight_reg_inactive` into `weight_reg_active`
3. If `pe_accept_w_in = 1` ? load `pe_weight_in` into `weight_reg_inactive`, pass weight downward
4. If `pe_valid_in = 1` ? compute MAC, latch result to `pe_psum_out`, forward input right, update sticky overflow flag
5. If `pe_valid_in = 0` ? output zeros (prevents stale data from propagating)
6. If `rst = 1` or `pe_enabled = 0` ? clear all registers to zero

---

## 4. Systolic Array — A Grid of PEs Working Together

**File:** `src/systolic.sv`

The **systolic array** arranges four PEs in a 2×2 grid. Data pulses through it rhythmically — like a heartbeat ("systole") — with each PE performing its MAC and passing results along.

### The Grid Layout

```
        Weight col-1           Weight col-2
      (sys_weight_in_11)     (sys_weight_in_12)
              ?                     ?
row1: [PE(1,1)] --input_out--? [PE(1,2)]
              ¦ psum_out?             ¦ psum_out?
row2: [PE(2,1)] --input_out--? [PE(2,2)]
              ?                     ?
       sys_data_out_21        sys_data_out_22
       (column-1 result)      (column-2 result)
```

- Input data enters from the **left** and ripples right
- Weights are loaded from the **top** and stay fixed during computation
- Partial sums flow **downward** through each column, accumulating
- Final dot-product results exit from the **bottom**

### What Computation This Performs

This computes the matrix product $Y = X \cdot W$ for 2×2 matrices. Both output columns are computed in parallel over two clock cycles.

**Software preprocessing (done before data reaches the chip):**
1. The input matrix $X$ is rotated 90° so that its rows align with the array's left-to-right data flow
2. Row-2's data is sent **1 cycle later** than Row-1's, so each value meets the correct weight at the right time inside the array

### Loading and Switching Weights

- `sys_accept_w_1 / sys_accept_w_2` — each HIGH pulse loads one weight row into the shadow registers of column 1 or column 2
- `sys_switch_in` — fires once after loading to atomically swap all shadow weights to active; the signal propagates diagonally (PE(1,1) ? PE(2,1) and PE(1,2) ? PE(2,2)) to maintain timing

### Column Enable

`ub_rd_col_size` tells the array how many columns are active. If only 1 column is needed, PE(1,2) and PE(2,2) are disabled (`pe_enabled=0`), which zeroes their outputs and prevents garbage from reaching the VPU.

---

## 5. Unified Buffer (UB) — The Chip's Memory

**File:** `src/unified_buffer.sv`

The **Unified Buffer** is a flat array of 128 sixteen-bit words (expandable via a parameter). It is the single shared memory that every module reads from or writes to. Everything lives here: inputs, weights, biases, activations, labels, and gradients.

### What It Stores

| Data | Purpose |
|------|---------|
| Input matrix $X$ | Fed to the left edge of the systolic array |
| Weight matrix $W$ | Fed to the top of the systolic array |
| Bias vector $b$ | Fed to the VPU bias stage |
| Post-activation $H$ | Saved during forward pass; re-read during backpropagation |
| Target labels $Y$ | Fed to the VPU loss stage |
| $2/N$ inverse batch size | Fed to the VPU loss stage for the MSE gradient scale |
| Updated weights/biases | Written back after gradient descent runs |

### Reading from the UB

Reading **streams data** out over multiple clock cycles. To start a read, assert `ub_rd_start_in = 1` with:
- `ub_rd_addr_in` — starting address
- `ub_rd_row_size` — how many rows to stream
- `ub_rd_col_size` — how many columns per row
- `ub_ptr_select` — **which output destination** to target (see table below)
- `ub_rd_transpose` — if 1, stream the matrix transposed

| `ub_ptr_select` | Destination | Data sent |
|-----------------|-------------|-----------|
| 0 | Systolic left side | Input data (`sys_data_in`, `sys_start`) |
| 1 | Systolic top | Weight data (`sys_weight_in`, `sys_accept_w`) |
| 2 | VPU bias stage | Bias scalars (`bias_scalar_in`) |
| 3 | VPU loss stage | Target labels (`Y_in`) |
| 4 | VPU LRD stage | Stored activations (`H_in`) |
| 5 | Gradient descent (bias mode) | Old bias values (`value_old_in`) |
| 6 | Gradient descent (weight mode) | Old weight values (`value_old_in`) |

The input read channel (ptr_select=0) **skews** its two output columns by 1 cycle automatically, creating the diagonal timing the systolic array requires.

### Writing to the UB

Two write paths share the same auto-incrementing write pointer `wr_ptr`:
1. **Host writes** — the testbench pre-loads data via `ub_wr_host_data_in` before computation
2. **VPU writes** — after computation, `vpu_data_out` flows back to `ub_wr_data_in` and is written to the next address

### Gradient Descent Lives Inside the UB

The UB instantiates **two `gradient_descent` modules** (generated by a `generate` loop, one per column). When the VPU writes gradients and a gradient-descent read channel is active (`ptr_select=5` or `6`), the modules immediately compute $W_{\text{new}} = W_{\text{old}} - \alpha \cdot \nabla W$ and write the result back to memory — all without CPU involvement.

---

## 6. Vector Processing Unit (VPU) — The Post-Processing Pipeline

**File:** `src/vpu.sv`

The systolic array produces raw dot-product numbers. The VPU applies a configurable chain of transformations to those numbers before writing results back to the UB.

### The Four Stages

```
Systolic Array result
        ?
  +-------------+   adds bias:       Z = dot_product + b
  ¦  Bias       ¦
  +-------------+
         ?
  +-------------+   activation:      H = Z   (if Z=0)
  ¦  Leaky ReLU ¦                  H = a·Z  (if Z<0)
  +-------------+
         ?
  +-------------+   MSE gradient:    grad = (2/N)·(H - Y)
  ¦  Loss       ¦
  +-------------+
         ?
  +-------------+   backprop step:   d = grad·1  (if H=0)
  ¦  LReLU Deriv¦                  d = grad·a  (if H<0)
  +-------------+
         ?
  Unified Buffer (write back)
```

### The Pathway Control

A 4-bit signal `vpu_data_pathway` enables/disables each stage independently:

| Bit | Stage |
|-----|-------|
| bit 3 | Bias |
| bit 2 | Leaky ReLU |
| bit 1 | Loss |
| bit 0 | Leaky ReLU Derivative |

| `vpu_data_pathway` | Active stages | When used |
|--------------------|---------------|-----------|
| `4'b1100` | Bias + Leaky ReLU | Forward pass — hidden layers |
| `4'b1111` | All four | Transition pass — output layer |
| `4'b0001` | LReLU Derivative only | Backward pass — hidden layers |

### Parent-Child Structure

Every stage is a **parent + two children**:
- The **child** module has all arithmetic logic (for one column)
- The **parent** wraps two identical child instances side-by-side (one per column)

This gives every stage two-column parallel processing without duplicating the logic description.

---

### 6a. Bias Module

**Files:** `src/bias_parent.sv`, `src/bias_child.sv`

The simplest stage. Adds bias $b$ to the systolic result: $Z = \text{dot\_product} + b$

The bias value arrives from the UB. Uses `fxp_add`. The output $Z$ is the **pre-activation value**. 1-cycle registered latency.

---

### 6b. Leaky ReLU Module

**Files:** `src/leaky_relu_parent.sv`, `src/leaky_relu_child.sv`

Applies the Leaky ReLU activation:

$$H = \begin{cases} Z & \text{if } Z \geq 0 \\ \alpha \cdot Z & \text{if } Z < 0 \end{cases}$$

$\alpha$ is the **leak factor** (e.g., 0.01). In hardware: check bit 15 (sign bit) of the input. If 0 ? pass through unchanged. If 1 ? multiply by $\alpha$ using `fxp_mul`.

The `fxp_mul` runs combinationally every cycle. The `always_ff` just selects which result to register. Output $H$ is the **post-activation value (activation)**, written back to the UB for use during backpropagation.

---

### 6c. Loss Module (MSE Gradient)

**Files:** `src/loss_parent.sv`, `src/loss_child.sv`

> This module does **not** compute the loss value. It computes the **gradient of MSE loss** needed for backpropagation.

MSE loss: $L = \frac{1}{N}\sum(H - Y)^2$. Its gradient w.r.t. $H$:

$$\frac{\partial L}{\partial H} = \frac{2}{N}(H - Y)$$

Two combinational stages:
1. `fxp_addsub` (`sub=1`): computes $H - Y$
2. `fxp_mul`: multiplies by $\frac{2}{N}$ (passed in as `inv_batch_size_times_two_in`)

Both run simultaneously. The result latches on the clock edge when `valid_in=1`. When `valid_in=0`, `gradient_out` is driven to zero. `valid_out` is assigned **unconditionally** so it always accurately mirrors `valid_in`.

---

### 6d. Leaky ReLU Derivative Module

**Files:** `src/leaky_relu_derivative_parent.sv`, `src/leaky_relu_derivative_child.sv`

During backpropagation, the gradient passes **back through** the activation function. The derivative of Leaky ReLU:

$$\frac{\partial H}{\partial Z} = \begin{cases} 1 & \text{if } H \geq 0 \\ \alpha & \text{if } H < 0 \end{cases}$$

The module multiplies the incoming gradient by 1 or $\alpha$, depending on the sign of the **original forward-pass $H$** (from the UB or the VPU's internal cache). This ensures the backward path mirrors the forward path exactly. Like the loss module, `valid_out` is assigned unconditionally.

---

## 7. Gradient Descent Module — How the Chip Learns

**File:** `src/gradient_descent.sv`  
**Location:** Instantiated inside `unified_buffer.sv` (two instances, one per column)

This module applies the gradient descent update rule:

$$W_{\text{new}} = W_{\text{old}} - \alpha \cdot \nabla W$$

In hardware (two combinational operations running simultaneously):
1. `fxp_mul`: computes $\alpha \times \nabla W$
2. `fxp_addsub` (`sub=1`): computes $W_{\text{old}} - (\alpha \cdot \nabla W)$

`grad_descent_done_out` fires 1 cycle after `grad_descent_valid_in`, signalling the UB to write the result.

### Weight Mode vs Bias Mode

`grad_bias_or_weight` selects the behaviour:

**Weight mode (`= 1`):** Each gradient directly updates from the old value read from the UB. One-shot per weight.

**Bias mode (`= 0`):** The bias accumulates updates across all batch samples. Once the first result is ready (`done=1`), it feeds back as input for the next gradient, forming an accumulation loop — no repeated UB reads needed.

After the update, `value_updated_out` **holds its value** (no else-branch clears it). This is intentional: it must stay stable until the UB writes it to memory.

---

## 8. Control Unit — The Instruction Decoder

**File:** `src/control_unit.sv`

The Control Unit takes a **130-bit instruction word** and slices it into named control signals. It is entirely combinational — just 14 `assign` statements, zero logic.

Think of it as a labeled cable splitter: one wide wire in, many labeled wires out.

### Instruction Bit Map

| Bits | Width | Signal | What it controls |
|------|-------|--------|-----------------|
| [0]      | 1  | `sys_switch_in`              | Swap PE shadow weights ? active |
| [1]      | 1  | `ub_rd_start_in`             | Trigger a UB read operation |
| [2]      | 1  | `ub_rd_transpose`            | Read the matrix transposed |
| [3]      | 1  | `ub_wr_host_valid_in_1`      | Host is writing on port 1 |
| [4]      | 1  | `ub_wr_host_valid_in_2`      | Host is writing on port 2 |
| [20:5]   | 16 | `ub_rd_col_size`             | Number of columns to stream |
| [36:21]  | 16 | `ub_rd_row_size`             | Number of rows to stream |
| [52:37]  | 16 | `ub_rd_addr_in`              | UB start address |
| [61:53]  | 9  | `ub_ptr_select`              | Which data type to read (0–6) |
| [77:62]  | 16 | `ub_wr_host_data_in_1`       | Data for host write port 1 |
| [93:78]  | 16 | `ub_wr_host_data_in_2`       | Data for host write port 2 |
| [97:94]  | 4  | `vpu_data_pathway`           | Which VPU stages are active |
| [113:98] | 16 | `inv_batch_size_times_two_in`| $2/N$ for MSE gradient |
| [129:114]| 16 | `vpu_leak_factor_in`         | Leaky ReLU leak factor $\alpha$ |

**Total: 5×1 + 5×16 + 9 + 4 = 130 bits**

The testbench builds each instruction by bit-shifting and OR-ing field values together, loads it into a register, and the control unit decodes it combinationally every cycle.

---

## 9. TPU — How Everything Connects

**File:** `src/tpu.sv`

The `tpu` module is the **top-level integration point**. It contains no computation — only wires and module instantiations. Think of it as the circuit board.

```
              +--------------------------------------+
Host/TB ----? ¦          Unified Buffer (UB)          ¦
(loads data)  ¦  memory[0:127]                        ¦
              ¦  gradient_descent[0..1]               ¦
              +---------------------------------------+
                      ¦              ¦          ¦
            inputs ?--+   weights ?--+  bias/H/Y?+
                      ¦              ¦
                      ?              ?
            +--------------------------+
            ¦      Systolic Array       ¦
            ¦  PE(1,1)     PE(1,2)      ¦
            ¦  PE(2,1)     PE(2,2)      ¦
            +--------------------------+
                          ¦  dot-product results
                          ?
            +--------------------------+
            ¦  Vector Processing Unit  ¦
            ¦  Bias?LReLU?Loss?LRD     ¦
            +--------------------------+
                          ¦  processed results
                          ?
              (written back to Unified Buffer)
```

The data forms a **closed loop**: UB ? Systolic ? VPU ? UB.

**There are no output ports at the top level.** Results stay in the UB. The host reads them by inspecting UB memory (in simulation via waveform dumps or signal hierarchy).

---

## 10. The Three Operating Modes

### Mode 1 — Forward Pass (`vpu_data_pathway = 4'b1100`)

**Active stages:** Bias + Leaky ReLU

$$H = \text{LeakyReLU}(W \cdot x + b)$$

Systolic computes the dot products; bias is added; Leaky ReLU is applied. Result $H$ is written back to the UB (needed later for backpropagation).

### Mode 2 — Transition Pass (`vpu_data_pathway = 4'b1111`)

**Active stages:** All four

Used at the output layer. Does the forward pass and the first backprop step in one pipeline sweep:
1. $Z = W \cdot x + b$
2. $H = \text{LeakyReLU}(Z)$
3. $\text{grad} = \frac{2}{N}(H - Y)$
4. $\delta = \text{grad} \cdot \frac{\partial H}{\partial Z}$

The VPU internally **caches** $H$ between the LReLU output and the Loss/LRD stages (since both need it), so no extra UB read is required.

### Mode 3 — Backward Pass (`vpu_data_pathway = 4'b0001`)

**Active stage:** Leaky ReLU Derivative only

For hidden layers. The systolic array is loaded with the **transposed weight matrix** $W^T$, which is how gradients propagate backward through a dense layer. The LRD stage applies the chain rule using stored $H$ from the UB. Gradient descent updates weights simultaneously inside the UB.

---

## 11. A Complete Training Step — From Input to Output

### Step 1 — Load all data into UB

The testbench writes weights $W$, biases $b$, inputs $x$, target labels $Y$, and $2/N$ into UB memory via `ub_wr_host_data_in`. Two words per clock cycle (one per column).

### Step 2 — Load weights into PE shadow registers

Assert `ub_rd_start_in=1`, `ub_ptr_select=1` (weights). The UB streams weight data to the top of the systolic array. PEs store received weights into `weight_reg_inactive`.

### Step 3 — Activate weights

Assert `sys_switch_in=1` for one cycle. All PEs copy `weight_reg_inactive` ? `weight_reg_active`. The chip is now ready to compute.

### Step 4 — Forward pass (hidden layer)

Assert reads for inputs (`ptr_select=0`) and biases (`ptr_select=2`). Set `vpu_data_pathway=4'b1100`. The UB streams the staggered input rows into the systolic array. MAC results flow to the VPU; bias is added; Leaky ReLU fires; $H$ is written back to UB.

### Step 5 — Transition pass (output layer)

Set `vpu_data_pathway=4'b1111`. Assert reads for second-layer inputs, biases, and Y labels. The full pipeline runs: forward then immediately backprop. The gradient $\delta$ is written to UB. Gradient descent updates weights.

### Step 6 — Backward pass (hidden layer)

Set `vpu_data_pathway=4'b0001`. Load the **transposed** hidden-layer weights. Stream the $\delta$ values as "inputs" to the systolic array. Systolic computes $W^T \cdot \delta$; LRD applies the chain rule using stored $H$. Gradient descent updates hidden layer weights and biases.

### Step 7 — Repeat

The next training iteration begins from Step 4 (weights already loaded) or Step 2 (if freshly updated weights need reloading).

---

## 12. File Map

| File | Role |
|------|------|
| `src/fixedpoint.sv` | Q8.8 arithmetic library (`fxp_add`, `fxp_addsub`, `fxp_mul`, `fxp_zoom`) |
| `src/pe.sv` | Single MAC unit — the fundamental compute cell |
| `src/systolic.sv` | 2×2 grid of PEs performing matrix multiply |
| `src/bias_child.sv` | Adds one bias scalar to one column |
| `src/bias_parent.sv` | Wraps two `bias_child` instances (both columns) |
| `src/leaky_relu_child.sv` | Leaky ReLU activation for one column |
| `src/leaky_relu_parent.sv` | Wraps two `leaky_relu_child` instances |
| `src/leaky_relu_derivative_child.sv` | Backprop chain-rule through LReLU, one column |
| `src/leaky_relu_derivative_parent.sv` | Wraps two derivative child instances |
| `src/loss_child.sv` | MSE gradient $(2/N)(H-Y)$ for one column |
| `src/loss_parent.sv` | Wraps two `loss_child` instances |
| `src/gradient_descent.sv` | Weight update: $W_{\text{new}} = W_{\text{old}} - \alpha \nabla W$ |
| `src/control_unit.sv` | Decodes 130-bit instruction into named control signals |
| `src/vpu.sv` | Configurable pipeline: Bias ? LReLU ? Loss ? LRD |
| `src/unified_buffer.sv` | 128-word on-chip RAM + gradient descent integration |
| `src/tpu.sv` | Top-level: instantiates and wires all modules together |
