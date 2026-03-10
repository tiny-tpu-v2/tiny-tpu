# tiny-tpu — Full Design Explanation (Beginner-Friendly)

> **Goal of this document**: Explain every part of the tiny-tpu hardware design from the ground up, assuming you know nothing about hardware or chip design. We go from the smallest building block up to the full chip.

---

## Table of Contents

1. [What Problem Are We Solving?](#1-what-problem-are-we-solving)
2. [How Numbers Are Stored — Fixed-Point Arithmetic](#2-how-numbers-are-stored--fixed-point-arithmetic)
3. [Processing Element (PE) — The Atom of the Chip](#3-processing-element-pe--the-atom-of-the-chip)
4. [Systolic Array — A Grid of PEs Working Together](#4-systolic-array--a-grid-of-pes-working-together)
5. [Unified Buffer (UB) — The Chip's Memory](#5-unified-buffer-ub--the-chips-memory)
6. [Vector Processing Unit (VPU) — Post-Processing Pipeline](#6-vector-processing-unit-vpu--post-processing-pipeline)
   - 6a. [Bias Module](#6a-bias-module)
   - 6b. [Leaky ReLU Module](#6b-leaky-relu-module)
   - 6c. [Loss Module (MSE Gradient)](#6c-loss-module-mse-gradient)
   - 6d. [Leaky ReLU Derivative Module](#6d-leaky-relu-derivative-module)
7. [Gradient Descent Module — How the Chip Learns](#7-gradient-descent-module--how-the-chip-learns)
8. [Control Unit — The Instruction Decoder](#8-control-unit--the-instruction-decoder)
9. [TPU — How Everything Connects](#9-tpu--how-everything-connects)
10. [The Three Operating Modes](#10-the-three-operating-modes)
11. [Data Flow Summary — From Input to Output](#11-data-flow-summary--from-input-to-output)
12. [File Map](#12-file-map)

---

## 1. What Problem Are We Solving?

A **Tensor Processing Unit (TPU)** is a chip designed to run **neural networks** very fast. A neural network is a mathematical function that learns from data. The core mathematical operation it performs over and over is:

$$\text{output} = \text{activation}(W \cdot x + b)$$

Where:
- $x$ = input data (a vector or matrix)
- $W$ = weight matrix (learned numbers)
- $b$ = bias vector (learned offsets)
- $\text{activation}$ = a non-linear function (here: Leaky ReLU)

A regular CPU does these one at a time. A TPU does **many multiplications and additions simultaneously** using special hardware. This chip is a minimal, 2×2 version of that idea — tiny enough to understand completely, but real enough to run an actual forward and backward pass through a neural network layer.

---

## 2. How Numbers Are Stored — Fixed-Point Arithmetic

**File**: `src/fixedpoint.sv`

Real numbers like `3.14` or `-0.5` are tricky for hardware. This chip uses **fixed-point** format: a 16-bit number where the top 8 bits represent the integer part and the bottom 8 bits represent the fractional part.

```
bit 15 ... bit 8 | bit 7 ... bit 0
  integer part   |  fractional part
```

Think of it like this: the number `256` in raw bits actually means `1.0` because bit 8 is the "ones place". This is the same idea as a decimal point, but fixed in hardware.

The `fixedpoint.sv` file provides reusable math modules that the whole chip uses:
- `fxp_add` — adds two fixed-point numbers  
- `fxp_addsub` — adds or subtracts (controlled by a 1-bit signal)  
- `fxp_mul` — multiplies two fixed-point numbers  

Every computation on this chip goes through one of these three operations.

---

## 3. Processing Element (PE) — The Atom of the Chip

**File**: `src/pe.sv`

The **Processing Element** is the smallest working unit. Think of it as a single worker in a factory. Every clock cycle (a tick of the hardware clock), it does one **multiply-accumulate (MAC)** operation:

$$\text{output sum} = (\text{input} \times \text{weight}) + \text{incoming partial sum}$$

### Ports (Connections)

The PE has connections coming from four directions — like a cell in a spreadsheet grid:

| Direction | Signal | What it carries |
|-----------|--------|-----------------|
| West (left) | `pe_input_in` | The data value flowing across the row |
| North (top) | `pe_psum_in` | A partial sum flowing down from above |
| North (top) | `pe_weight_in` | A weight being loaded into the PE |
| East (right) | `pe_input_out` | Passes the input along to the next PE |
| South (bottom) | `pe_psum_out` | Sends the computed partial sum downward |

### Weight Registers — The Double-Buffer Trick

Each PE stores its weight in **two registers**:
- `weight_reg_active` — the weight currently being used for multiplication
- `weight_reg_inactive` — a "shadow" register loading the next weight in the background

This is like a chef preparing the next dish while the current one is still cooking. When the `pe_switch_in` signal fires, the inactive register instantly becomes the active one — zero interruption to computation.

### Valid Signal

The `pe_valid_in` signal tells the PE: "this clock cycle carries real data." If it is 0, the PE outputs zeros and produces nothing. This is how the chip handles data that arrives at different times across the array.

---

## 4. Systolic Array — A Grid of PEs Working Together

**File**: `src/systolic.sv`

The **systolic array** is a 2×2 grid of PEs. The name comes from the heart — data pulses through it rhythmically like blood.

### Layout

```
         Col 1          Col 2
         weight_in_11   weight_in_12
              ↓               ↓
Row 1:  [  PE(1,1)  ] → [  PE(1,2)  ]
              ↓               ↓
Row 2:  [  PE(2,1)  ] → [  PE(2,2)  ]
              ↓               ↓
         output_21      output_22
```

- **Data flows LEFT → RIGHT** across each row (input values)
- **Partial sums flow TOP → BOTTOM** down each column
- **Weights are loaded from the TOP** and stay fixed during computation

### What Computation Does This Implement?

This hardware computes **matrix multiplication**: $Y = X \cdot W$

For a 2×2 matrix multiply, you need 4 dot products. The systolic array computes all of them in parallel over a few clock cycles, rather than one at a time.

### Input Preprocessing (done in software before sending to chip)

Before data enters the array, two transformations are applied:
1. **Input matrix is rotated 90°** so rows align with the array's row-by-row flow
2. **Values are staggered** — Row 2's input is delayed by one clock cycle relative to Row 1, so each value meets the correct weight at the right time

### Weight Loading

Weights are loaded column-by-column through the `sys_accept_w` signals. Each column has its own load signal (`sys_accept_w_1`, `sys_accept_w_2`) so both columns can be loaded independently. The `sys_switch_in` signal, once fired, propagates diagonally through the array (top-left to bottom-right) telling each PE to swap its shadow register into active use.

### Column Enable

The `ub_rd_col_size` input tells the array how many columns are actually being used. This disables unused PE columns, saving power and preventing garbage from propagating.

---

## 5. Unified Buffer (UB) — The Chip's Memory

**File**: `src/unified_buffer.sv`

The **Unified Buffer** is the chip's on-chip RAM. It is a single array of 128 sixteen-bit words. Everything the chip needs to remember lives here:

| Data Type | Used For |
|-----------|----------|
| Input matrices ($X$) | Fed to the left side of the systolic array |
| Weight matrices ($W$) | Fed to the top of the systolic array |
| Bias vectors ($b$) | Fed to the VPU bias module |
| Post-activation values ($H$) | Stored during forward pass, needed for backprop |
| Target labels ($Y$) | Used by the loss module to compute gradient |
| Inverse batch size ($2/N$) | Used by the loss module |

### How Reading Works

Reading from the UB is not instantaneous — it streams data out over multiple clock cycles. You give it:
- A **start address** (where in memory to begin)
- A **row count** and **column count** (how much to read)
- A **pointer select** (`ub_ptr_sel`) telling it which output port to drive (inputs, weights, biases, Y, or H)
- A **transpose flag** — if set, the UB reads the matrix transposed without rearranging memory

The UB has separate output wires for each destination:
- `ub_rd_input_data_out` → left side of the systolic array
- `ub_rd_weight_data_out` → top of the systolic array
- `ub_rd_bias_data_out` → bias modules in the VPU
- `ub_rd_Y_data_out` → loss modules in the VPU
- `ub_rd_H_data_out` → leaky ReLU derivative modules in the VPU

### How Writing Works

The UB has two write paths:
1. **Host writes** (`ub_wr_host_data_in`) — the external testbench loads initial weights, biases, and inputs before computation starts
2. **VPU writes** (`ub_wr_data_in`) — after the VPU processes data, results are automatically written back to the UB (used for storing updated weights and activations)

The write pointer (`wr_ptr`) tracks where to write next and auto-increments.

### Gradient Descent Lives Here

Unusually, the UB also contains `gradient_descent` module instances. When new gradients arrive from the VPU, the gradient descent modules immediately apply the weight update formula before writing back to memory:

$$W_{\text{new}} = W_{\text{old}} - \alpha \cdot \nabla W$$

where $\alpha$ is the learning rate. This keeps the weight update on-chip without needing to ship data back to a CPU.

---

## 6. Vector Processing Unit (VPU) — Post-Processing Pipeline

**File**: `src/vpu.sv`

After the systolic array produces raw dot-product results, those numbers still need to be transformed before they are useful output. The **VPU** is a pipeline of four modules that do those transformations, wired together in sequence.

```
Systolic Array output
        ↓
  [  Bias Module  ]         ← adds b to each value
        ↓
  [ Leaky ReLU    ]         ← applies activation function
        ↓
  [  Loss Module  ]         ← computes MSE gradient (backprop)
        ↓
  [ ReLU Derivative ]       ← backpropagates through activation
        ↓
  Unified Buffer (write back)
```

A **4-bit control signal** (`vpu_data_pathway`) acts like a set of switches that turn each stage on or off:

| Bit | Module |
|-----|--------|
| bit 3 | Bias |
| bit 2 | Leaky ReLU |
| bit 1 | Loss |
| bit 0 | Leaky ReLU Derivative |

So `1100` = bias + ReLU only (forward pass), `1111` = all four (transition), `0001` = ReLU derivative only (backward pass).

Each module is built as a **parent-child pair**. The parent is just a container that instantiates two identical **child** modules side-by-side (one for each column of the 2×2 array). All real logic lives in the child.

---

### 6a. Bias Module

**Files**: `src/bias_parent.sv`, `src/bias_child.sv`

This is the simplest module. It takes the dot-product result from the systolic array and adds a bias value to it:

$$Z = \text{dot\_product} + b$$

The bias value $b$ is fetched from the Unified Buffer and arrives on a separate wire. The addition uses `fxp_add`. The result $Z$ is called the **pre-activation value** — the number before the activation function is applied.

---

### 6b. Leaky ReLU Module

**Files**: `src/leaky_relu_parent.sv`, `src/leaky_relu_child.sv`

**ReLU** (Rectified Linear Unit) is the most common activation function in neural networks:

$$H = \max(0, Z)$$

**Leaky ReLU** is a small improvement — instead of cutting all negative values to exactly zero, it keeps a tiny fraction of them:

$$H = \begin{cases} Z & \text{if } Z \geq 0 \\ \alpha \cdot Z & \text{if } Z < 0 \end{cases}$$

where $\alpha$ is the **leak factor** (a small number like 0.01).

In hardware this is a simple conditional:
- If the input bit 15 (the sign bit) is 0, the number is positive → pass it through unchanged
- If the sign bit is 1, the number is negative → multiply by the leak factor using `fxp_mul`

The result $H$ is the **post-activation value**, which is written back to the Unified Buffer for later use in backpropagation.

---

### 6c. Loss Module (MSE Gradient)

**Files**: `src/loss_parent.sv`, `src/loss_child.sv`

> Note: Despite being named "loss", this module does not compute the loss value itself. It computes the **gradient of the MSE loss** with respect to the output — which is what you need for backpropagation.

The **Mean Squared Error (MSE)** loss is:

$$L = \frac{1}{N} \sum (H - Y)^2$$

Its gradient (derivative with respect to $H$) is:

$$\frac{\partial L}{\partial H} = \frac{2}{N}(H - Y)$$

The module computes this in two pipeline stages:
1. `fxp_addsub` computes $(H - Y)$  
2. `fxp_mul` multiplies by $\frac{2}{N}$ (precomputed and passed in as `inv_batch_size_times_two_in`)

This gradient is passed to the next stage (Leaky ReLU Derivative).

---

### 6d. Leaky ReLU Derivative Module

**Files**: `src/leaky_relu_derivative_parent.sv`, `src/leaky_relu_derivative_child.sv`

During backpropagation, gradients must be propagated **backwards through the activation function**. The derivative of Leaky ReLU is:

$$\frac{\partial H}{\partial Z} = \begin{cases} 1 & \text{if } H \geq 0 \\ \alpha & \text{if } H < 0 \end{cases}$$

The module applies this using the chain rule — it multiplies the incoming gradient by either 1 (pass-through) or $\alpha$ (the leak factor), depending on the **sign of the original H value** (which was saved in the UB during the forward pass).

This is why the UB stores $H$ — it is needed here during backprop.

---

## 7. Gradient Descent Module — How the Chip Learns

**File**: `src/gradient_descent.sv`  
**Location**: Instantiated inside `unified_buffer.sv`

Once the backpropagation pipeline has produced gradients, the chip needs to **update the weights**. This is the learning step. The formula is:

$$W_{\text{new}} = W_{\text{old}} - \alpha \cdot \nabla W$$

Where:
- $W_{\text{old}}$ is the current weight (read from the UB)
- $\nabla W$ is the gradient (coming from the VPU)
- $\alpha$ is the **learning rate** (controls how big each update step is)
- $W_{\text{new}}$ is written back to the UB

In hardware this uses:
- `fxp_mul` to compute $\alpha \cdot \nabla W$
- `fxp_addsub` to compute $W_{\text{old}} - (\alpha \cdot \nabla W)$

There are two instances of this module (one per column), running in parallel.

A `grad_bias_or_weight` signal selects whether we are updating a **bias** or a **weight**. For biases, the module accumulates updates across a batch before writing back. For weights, each gradient directly updates from the stored old value.

---

## 8. Control Unit — The Instruction Decoder

**File**: `src/control_unit.sv`

The **Control Unit** is the simplest module in the chip. It takes a single wide **instruction word** (88 bits) and slices it into named control signals that go to every other module.

Think of the instruction as a very long light switch panel — each group of bits turns a specific part of the chip on or off, or tells it a number.

### Instruction Fields

| Bits | Width | Signal | What it does |
|------|-------|--------|--------------|
| [0] | 1 bit | `sys_switch_in` | Tells all PEs to swap their shadow weight into active use |
| [1] | 1 bit | `ub_rd_start_in` | Starts a read transaction from the UB |
| [2] | 1 bit | `ub_rd_transpose` | Read the matrix transposed |
| [3] | 1 bit | `ub_wr_host_valid_in_1` | Host is writing data on channel 1 |
| [4] | 1 bit | `ub_wr_host_valid_in_2` | Host is writing data on channel 2 |
| [6:5] | 2 bits | `ub_rd_col_size` | How many columns to read (0–3) |
| [14:7] | 8 bits | `ub_rd_row_size` | How many rows to read (0–255) |
| [16:15] | 2 bits | `ub_rd_addr_in` | Where in UB to start reading |
| [19:17] | 3 bits | `ub_ptr_sel` | Which UB output port to target |
| [35:20] | 16 bits | `ub_wr_host_data_in_1` | Data value the host is writing (ch 1) |
| [51:36] | 16 bits | `ub_wr_host_data_in_2` | Data value the host is writing (ch 2) |
| [55:52] | 4 bits | `vpu_data_pathway` | Which VPU modules to enable |
| [71:56] | 16 bits | `inv_batch_size_times_two_in` | Precomputed $2/N$ for loss gradient |
| [87:72] | 16 bits | `vpu_leak_factor_in` | Leak factor $\alpha$ for Leaky ReLU |

There is no logic in the control unit — it is purely combinational wire routing. The testbench assembles each instruction and loads it into an instruction buffer; the control unit decodes it every clock cycle.

---

## 9. TPU — How Everything Connects

**File**: `src/tpu.sv`

The `tpu` module is the **top-level** module — it instantiates and wires together every other module.

```
                    ┌─────────────────────────────────────────────┐
   External Host ──►│             Unified Buffer (UB)              │
  (writes weights,  │  memory[0..127]                             │
   biases, inputs)  │  gradient_descent[0], gradient_descent[1]   │
                    └──────┬────────────┬───────────────────────┬─┘
                           │            │                       │
                  inputs   │   weights  │    biases / H / Y     │
                           ▼            ▼                       │
                    ┌──────────────────────┐                    │
                    │   Systolic Array     │                    │
                    │  PE(1,1) PE(1,2)     │                    │
                    │  PE(2,1) PE(2,2)     │                    │
                    └──────────┬───────────┘                    │
                               │ dot-product results             │
                               ▼                                 ▼
                    ┌──────────────────────────────────────────────┐
                    │           Vector Processing Unit (VPU)       │
                    │  Bias → Leaky ReLU → Loss → ReLU-Derivative  │
                    └──────────────────────┬───────────────────────┘
                                           │ processed results
                                           ▼
                              (written back to Unified Buffer)
```

The data loop is:
1. **Load** → host writes parameters into UB
2. **Read** → UB streams data to systolic array and VPU
3. **Compute** → systolic array multiplies; VPU post-processes
4. **Write back** → VPU output goes back to UB
5. **Update** → gradient descent modules update weights in UB in-place

Everything is synchronized to a single `clk` signal. A `rst` signal resets all registers to zero.

---

## 10. The Three Operating Modes

The VPU `vpu_data_pathway` signal selects one of three modes:

### Mode 1 — Forward Pass (`1100`)
**Path**: Systolic Array → Bias → Leaky ReLU → UB

This computes:
$$H = \text{LeakyReLU}(W \cdot x + b)$$

The post-activation value $H$ is stored in the UB for later use.

### Mode 2 — Transition / Output Layer (`1111`)
**Path**: Systolic Array → Bias → Leaky ReLU → Loss → ReLU Derivative → UB

This computes the output layer forward pass **and immediately** computes the first backprop gradient in one pipeline. Used at the boundary between forward and backward passes.

### Mode 3 — Backward Pass (`0001`)
**Path**: Systolic Array → ReLU Derivative → UB

Backpropagation for hidden layers. The systolic array here computes $W^T \cdot \delta$ (the transposed weight matrix times the incoming gradient), and the ReLU derivative module applies the chain rule.

---

## 11. Data Flow Summary — From Input to Output

Here is a complete picture of one forward + backward pass:

**Step 1 — Load parameters**  
The host sends weights, biases, inputs, and target labels into the UB two values per clock cycle via `ub_wr_host_data_in`.

**Step 2 — Load weights into PEs**  
The UB streams weights to the top of the systolic array. PEs load them into their inactive (shadow) registers.

**Step 3 — Switch weights**  
The `sys_switch_in` signal fires. All PEs swap their shadow registers to active. The chip is now ready to compute.

**Step 4 — Stream inputs**  
The UB streams the (staggered, rotated) input matrix to the left side of the systolic array. Each PE multiplies and accumulates. After a few cycles, the bottom row outputs the complete dot-product results.

**Step 5 — VPU forward pass**  
The systolic output flows into the VPU. Bias is added, then Leaky ReLU is applied. The result $H$ is written back to the UB.

**Step 6 — Compute loss gradient**  
The output layer runs in transition mode. The loss module receives $H$ and the true labels $Y$, computes $\frac{2}{N}(H-Y)$, and passes that gradient to the ReLU derivative.

**Step 7 — Backpropagate**  
For each hidden layer (backward), the systolic array is re-used with transposed weights. Gradients flow through the ReLU derivative module and are written back to the UB.

**Step 8 — Update weights**  
The gradient descent modules inside the UB receive the gradients and immediately compute $W_{\text{new}} = W_{\text{old}} - \alpha \cdot \nabla W$, overwriting the old values in memory.

**Step 9 — Repeat**  
The next training iteration restarts from Step 2 with the new weights.

---

## 12. File Map

| File | What it is |
|------|-----------|
| `src/pe.sv` | Single multiply-accumulate unit |
| `src/systolic.sv` | 2×2 grid of PEs for matrix multiply |
| `src/unified_buffer.sv` | On-chip RAM + gradient descent |
| `src/gradient_descent.sv` | Weight update: $W = W - \alpha\nabla W$ |
| `src/vpu.sv` | Pipeline of post-processing stages |
| `src/bias_parent.sv` / `bias_child.sv` | Adds bias vector to dot products |
| `src/leaky_relu_parent.sv` / `leaky_relu_child.sv` | Leaky ReLU activation |
| `src/leaky_relu_derivative_parent.sv` / `leaky_relu_derivative_child.sv` | Backprop through Leaky ReLU |
| `src/loss_parent.sv` / `loss_child.sv` | MSE gradient: $\frac{2}{N}(H-Y)$ |
| `src/control_unit.sv` | Decodes 88-bit instruction word into control signals |
| `src/tpu.sv` | Top-level: wires every module together |
| `src/fixedpoint.sv` | Library of fixed-point math operations |
