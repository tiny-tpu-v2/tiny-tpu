# tiny-tpu — SystemVerilog Assertions Verification Plan

## 1. Overview

This plan defines every SystemVerilog assertion (SVA) to be written for the tiny-tpu design.
Assertions are organised as separate **bind modules** in `sva/`, one file per RTL module.
Each bind module is bound to its DUT using:
```systemverilog
bind <module_name> <module_name>_assertions #(...) u_assert (.*);
```

---

## 2. Methodology

### Assertion categories used

| Category | SVA construct | Purpose |
|----------|---------------|---------|
| Reset | `property ... rst \|=> ...` | Every register must clear after rst |
| Valid protocol | `property` on `valid_in/out` | Valid signals propagate and gate correctly |
| Data path | `property` on data signals vs. `$past` | Outputs equal registered inputs through pipeline |
| Mutual exclusion | `property` on conflicting enables | UB write ports don't collide |
| Functional | `property` with `$past` arithmetic | Computed result equals expected formula |
| Coverage | `cover property` | Ensures all branches are exercised |

### Clocking convention

All sequential assertions are clocked on **`posedge clk`** and have **`disable iff (rst)`** unless they explicitly test reset behaviour itself.

### Fixed-point note

All data signals are Q8.8 signed 16-bit fixed-point. Arithmetic assertions use `$past` sampling and compare against the expected combinationally computed value latched one cycle later. Where the exact fxp_mul/fxp_add rounding is involved, assertions are written as structural/protocol checks; numerical tolerance is validated by the cocotb golden model.

---

## 3. Module-by-Module Assertion Plan

---

### 3.1 `pe` — Processing Element

**Source**: `src/pe.sv`

**Key RTL facts extracted from source:**
- `pe_valid_out` and `pe_switch_out` are the registered versions of their inputs (one-cycle delay). The `else` branch re-assigns `pe_valid_out <= 0`, so both branches agree: `pe_valid_out` always equals `$past(pe_valid_in)`.
- `pe_psum_out` is set to `mac_out` (the combinational result of `fxp_mul(pe_input_in, weight_reg_active) + pe_psum_in`) when `pe_valid_in=1`, otherwise `0`.
- `pe_input_out` captures `pe_input_in` when `pe_valid_in=1` and is **not reset** in the `else` branch (retains last value).
- `pe_weight_out` = `pe_weight_in` when `pe_accept_w_in=1`, otherwise `0`.
- `weight_reg_inactive` updates on `pe_accept_w_in` rising. `weight_reg_active` is a latch: it equals `weight_reg_inactive` when `pe_switch_in=1`, holds otherwise.
- `rst || !pe_enabled` both clear all registers.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| PE-A1 | `p_rst_clears_psum` | After rst, `pe_psum_out == 0` |
| PE-A2 | `p_rst_clears_valid` | After rst, `pe_valid_out == 0` |
| PE-A3 | `p_rst_clears_switch` | After rst, `pe_switch_out == 0` |
| PE-A4 | `p_rst_clears_weight_out` | After rst, `pe_weight_out == 0` |
| PE-A5 | `p_rst_clears_input_out` | After rst, `pe_input_out == 0` |
| PE-A6 | `p_disabled_clears_outputs` | `!pe_enabled` on clk edge clears psum, valid, switch, weight |
| PE-A7 | `p_valid_out_registered` | `pe_valid_out == $past(pe_valid_in)` every cycle |
| PE-A8 | `p_switch_out_registered` | `pe_switch_out == $past(pe_switch_in)` every cycle |
| PE-A9 | `p_weight_out_when_accepting` | `pe_accept_w_in |=> pe_weight_out == $past(pe_weight_in)` |
| PE-A10 | `p_weight_out_zero_when_idle` | `!pe_accept_w_in |=> pe_weight_out == 0` |
| PE-A11 | `p_input_out_captured_on_valid` | `pe_valid_in |=> pe_input_out == $past(pe_input_in)` |
| PE-A12 | `p_psum_zero_when_invalid` | `!pe_valid_in |=> pe_psum_out == 0` |
| PE-A13 | `p_valid_out_zero_when_in_low` | `!pe_valid_in |=> !pe_valid_out` (explicit from A7) |

**Cover properties:**

| ID | Scenario |
|----|----------|
| PE-C1 | MAC active: `pe_valid_in && pe_switch_in` — compute with fresh weight |
| PE-C2 | Weight load then switch: `pe_accept_w_in ##1 !pe_accept_w_in ##1 pe_switch_in` |
| PE-C3 | `pe_enabled` de-asserted mid computation |

---

### 3.2 `systolic` — 2×2 Systolic Array

**Source**: `src/systolic.sv`

**Key RTL facts:**
- `pe_enabled` register is set on `ub_rd_col_size_valid_in`: `pe_enabled <= (1 << ub_rd_col_size_in) - 1`. So col_size=1 → `pe_enabled=01` (only col 0 active); col_size=2 → `pe_enabled=11`.
- Valid chain: `sys_start → pe11(1 cycle) → pe_valid_out_11 → pe21(1 cycle) → sys_valid_out_21`. Total: **2 cycles** from `sys_start` to `sys_valid_out_21`.
- `sys_valid_out_22` arrives **1 cycle after** `sys_valid_out_21` (pe22 is fed by pe_valid_out_12 which is fed by pe_valid_out_11 just like pe21, but adds one extra register stage through pe12→pe22).
- Switch propagates diagonally: `sys_switch_in → pe11.pe_switch_out (1 cycle) → pe12 and pe21`.
- Weight columns are independent: `sys_accept_w_1` controls column 1, `sys_accept_w_2` controls column 2.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| S-A1 | `p_rst_clears_valid_out_21` | `rst \|=> !sys_valid_out_21` |
| S-A2 | `p_rst_clears_valid_out_22` | `rst \|=> !sys_valid_out_22` |
| S-A3 | `p_rst_clears_data_out_21` | `rst \|=> sys_data_out_21 == 0` |
| S-A4 | `p_rst_clears_data_out_22` | `rst \|=> sys_data_out_22 == 0` |
| S-A5 | `p_valid_21_two_cycle_delay` | `sys_start \|=> ##1 sys_valid_out_21` — valid_out_21 appears exactly 2 cycles after sys_start |
| S-A6 | `p_valid_22_one_cycle_after_21` | `sys_valid_out_21 \|=> sys_valid_out_22` — col 2 lags col 1 by 1 cycle |
| S-A7 | `p_no_valid_without_start` | `!sys_start \|=> ##[0:1] !sys_valid_out_21` — when start deasserts, valid follows (note overlapping bursts) |
| S-A8 | `p_col_size_1_disables_col2` | After `ub_rd_col_size_valid_in && ub_rd_col_size_in==1`, `sys_valid_out_22` stays 0 |
| S-A9 | `p_col_size_2_enables_both` | After `ub_rd_col_size_valid_in && ub_rd_col_size_in==2`, both columns can produce valid output |
| S-A10 | `p_accept_w_cols_independent` | `sys_accept_w_1 && !sys_accept_w_2` — weights loadable per column independently |

**Cover properties:**

| ID | Scenario |
|----|----------|
| S-C1 | Full 4-row batch: 4 consecutive `sys_start` cycles producing 4 output pairs |
| S-C2 | Weight switch during active computation |
| S-C3 | col_size change from 2 to 1 |

---

### 3.3 `bias_child` — Bias Adder

**Source**: `src/bias_child.sv`

**Key RTL facts:**
- `z_pre_activation = bias_sys_data_in + bias_scalar_in` — combinational via `fxp_add`.
- On `posedge clk`: if `bias_sys_valid_in`: outputs latch `z_pre_activation` and `valid=1`; else outputs clear to `0`.
- Both outputs are zero when `valid_in=0` — **no hold behaviour on data path**.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| BC-A1 | `p_rst_clears_valid` | `rst \|=> !bias_Z_valid_out` |
| BC-A2 | `p_rst_clears_data` | `rst \|=> bias_z_data_out == 0` |
| BC-A3 | `p_valid_out_mirrors_valid_in` | `1'b1 \|=> (bias_Z_valid_out == $past(bias_sys_valid_in))` |
| BC-A4 | `p_data_zero_when_invalid` | `!bias_sys_valid_in \|=> bias_z_data_out == 0` |
| BC-A5 | `p_data_nonzero_when_valid_nonzero_input` | When `bias_sys_valid_in && (bias_sys_data_in != 0 \|\| bias_scalar_in != 0)`, the next cycle's `bias_z_data_out != 0` (functional liveness) |

**Cover properties:**

| ID | Scenario |
|----|----------|
| BC-C1 | Positive input + positive bias |
| BC-C2 | Negative input + positive bias (result crosses zero) |
| BC-C3 | Valid deasserted mid-stream |

---

### 3.4 `leaky_relu_child` — Leaky ReLU Activation

**Source**: `src/leaky_relu_child.sv`

**Key RTL facts:**
- `mul_out = lr_data_in * lr_leak_factor_in` — combinational via `fxp_mul`.
- On `posedge clk`:
  - `lr_valid_out <= 1` and `lr_data_out <= lr_data_in` if `lr_valid_in && lr_data_in >= 0`
  - `lr_valid_out <= 1` and `lr_data_out <= mul_out` if `lr_valid_in && lr_data_in < 0`
  - `lr_valid_out <= 0`, `lr_data_out <= 0` if `!lr_valid_in`
- Sign is determined by bit `[15]` in the registered input (via `lr_data_in >= 0` comparison which is on the wire value at the clock edge).

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| LR-A1 | `p_rst_clears_outputs` | `rst \|=> (!lr_valid_out && lr_data_out == 0)` |
| LR-A2 | `p_valid_out_mirrors_valid_in` | `1'b1 \|=> (lr_valid_out == $past(lr_valid_in))` |
| LR-A3 | `p_data_zero_when_invalid` | `!lr_valid_in \|=> lr_data_out == 0` |
| LR-A4 | `p_positive_input_passes_through` | `(lr_valid_in && !lr_data_in[15]) \|=> lr_data_out == $past(lr_data_in)` — non-negative input is passed unchanged |
| LR-A5 | `p_negative_input_is_scaled` | `(lr_valid_in && lr_data_in[15]) \|=> (lr_data_out != $past(lr_data_in))` — negative input is modified (scaled by leak factor) |
| LR-A6 | `p_nonneg_output_for_nonneg_input` | `(lr_valid_in && !lr_data_in[15]) \|=> !lr_data_out[15]` — sign preserved for positive path |
| LR-A7 | `p_zero_input_zero_output` | `(lr_valid_in && lr_data_in == 0) \|=> lr_data_out == 0` — zero is fixed point of ReLU |

**Cover properties:**

| ID | Scenario |
|----|----------|
| LR-C1 | Positive input: passthrough path taken |
| LR-C2 | Negative input: scaled path taken |
| LR-C3 | Exactly-zero input |
| LR-C4 | Valid deasserted after a run |

---

### 3.5 `leaky_relu_derivative_child` — ReLU Derivative

**Source**: `src/leaky_relu_derivative_child.sv`

**Key RTL facts:**
- `mul_out = lr_d_data_in * lr_leak_factor_in` — combinational.
- On `posedge clk`: `lr_d_valid_out <= lr_d_valid_in` **always** (no gating in the else branch — unlike leaky_relu_child which resets valid to 0).
- Data: if `lr_d_valid_in && lr_d_H_data_in >= 0`: pass `lr_d_data_in` through; if `lr_d_valid_in && lr_d_H_data_in < 0`: output `mul_out`; if `!lr_d_valid_in`: output `0`.
- The routing decision is based on **`lr_d_H_data_in`** (the stored activation H from the forward pass), not the gradient itself.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| LRD-A1 | `p_rst_clears_outputs` | `rst \|=> (!lr_d_valid_out && lr_d_data_out == 0)` |
| LRD-A2 | `p_valid_out_mirrors_valid_in` | `1'b1 \|=> (lr_d_valid_out == $past(lr_d_valid_in))` — note: no gating, pure register |
| LRD-A3 | `p_data_zero_when_invalid` | `!lr_d_valid_in \|=> lr_d_data_out == 0` |
| LRD-A4 | `p_positive_H_passes_gradient_through` | `(lr_d_valid_in && !lr_d_H_data_in[15]) \|=> lr_d_data_out == $past(lr_d_data_in)` |
| LRD-A5 | `p_negative_H_scales_gradient` | `(lr_d_valid_in && lr_d_H_data_in[15]) \|=> (lr_d_data_out != $past(lr_d_data_in))` |
| LRD-A6 | `p_zero_H_passes_gradient_through` | `(lr_d_valid_in && lr_d_H_data_in == 0) \|=> lr_d_data_out == $past(lr_d_data_in)` — H=0 is non-negative |

**Key difference from leaky_relu_child**: `lr_d_valid_out` is a plain register with no override — `p_valid_out_mirrors_valid_in` holds unconditionally.

**Cover properties:**

| ID | Scenario |
|----|----------|
| LRD-C1 | H ≥ 0: gradient passes through unscaled |
| LRD-C2 | H < 0: gradient is scaled by leak factor |
| LRD-C3 | H = 0 boundary (exactly zero H) |

---

### 3.6 `loss_child` — MSE Gradient

**Source**: `src/loss_child.sv`

**Key RTL facts:**
- Two purely **combinational** stages:
  - `diff_stage1 = H_in - Y_in` via `fxp_addsub`
  - `final_gradient = diff_stage1 * inv_batch_size_times_two_in` via `fxp_mul`
- Sequential register: `gradient_out <= final_gradient` and `valid_out <= valid_in` — **both always updated every clock cycle regardless of `valid_in`**. `gradient_out` is NOT gated by `valid_in` — when `valid_in=0`, stale/garbage gradient is computed from whatever H_in and Y_in are (but `valid_out=0` tells the consumer to ignore it).

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| LC-A1 | `p_rst_clears_gradient` | `rst \|=> gradient_out == 0` |
| LC-A2 | `p_rst_clears_valid` | `rst \|=> !valid_out` |
| LC-A3 | `p_valid_out_mirrors_valid_in` | `1'b1 \|=> (valid_out == $past(valid_in))` |
| LC-A4 | `p_gradient_always_registered` | `1'b1 \|=> (gradient_out == $past(final_gradient))` — where `final_gradient` is accessed via bind (internal wire) |
| LC-A5 | `p_invalid_valid_out_zero` | `!valid_in \|=> !valid_out` (redundant with A3 but explicit) |
| LC-A6 | `p_gradient_sign_correct_for_H_gt_Y` | When `valid_in` and `H_in > Y_in`, next cycle `gradient_out[15] == 0` (positive gradient) |
| LC-A7 | `p_gradient_sign_correct_for_H_lt_Y` | When `valid_in` and `H_in < Y_in`, next cycle `gradient_out[15] == 1` (negative gradient) |

**NOTE on LC-A4**: `final_gradient` is an internal `logic` signal. To assert on it from a bind module use `dut.final_gradient` or declare it in the bind module through hierarchical reference. Many simulators support this directly in bind.

**Cover properties:**

| ID | Scenario |
|----|----------|
| LC-C1 | H > Y (positive gradient) |
| LC-C2 | H < Y (negative gradient) |
| LC-C3 | H == Y (zero gradient) |
| LC-C4 | `valid_in` deasserted — confirms `valid_out` follows correctly |

---

### 3.7 `gradient_descent` — Weight Update

**Source**: `src/gradient_descent.sv`

**Key RTL facts:**
- `mul_out = grad_in * lr_in` — combinational via `fxp_mul`.
- `sub_value_out = sub_in_a - mul_out` — combinational via `fxp_addsub`.
- `sub_in_a` selection (combinational, `always_comb`):
  - `grad_bias_or_weight == 1` (weight mode): `sub_in_a = value_old_in` always.
  - `grad_bias_or_weight == 0` (bias mode): `sub_in_a = value_updated_out` if `grad_descent_done_out`, else `value_old_in`.
- Sequential:
  - `grad_descent_done_out <= grad_descent_valid_in` — **always registered, 1-cycle delay**.
  - `value_updated_out <= sub_value_out` when `grad_descent_valid_in`; else `<= 0`.
- The bias mode accumulates over the batch (uses updated output as next input). The weight mode always reads fresh `value_old_in`.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| GD-A1 | `p_rst_clears_output` | `rst \|=> value_updated_out == 0` |
| GD-A2 | `p_rst_clears_done` | `rst \|=> !grad_descent_done_out` |
| GD-A3 | `p_done_one_cycle_delay` | `1'b1 \|=> (grad_descent_done_out == $past(grad_descent_valid_in))` |
| GD-A4 | `p_output_zero_when_not_valid` | `!grad_descent_valid_in \|=> value_updated_out == 0` |
| GD-A5 | `p_weight_mode_uses_value_old` | `(grad_descent_valid_in && grad_bias_or_weight) \|=> (value_updated_out == $past(value_old_in) - $past(mul_out))` — weight update formula (requires `mul_out` via bind) |
| GD-A6 | `p_done_implies_valid_was_set` | `grad_descent_done_out \|-> $past(grad_descent_valid_in)` — done can only be 1 if valid was 1 last cycle |
| GD-A7 | `p_not_done_implies_valid_was_clear` | `!grad_descent_done_out \|-> !$past(grad_descent_valid_in)` (inverse of A6) |

**Cover properties:**

| ID | Scenario |
|----|----------|
| GD-C1 | Weight mode: single-cycle update |
| GD-C2 | Bias mode: multi-cycle accumulation (done cascades) |
| GD-C3 | `grad_descent_valid_in` deasserted after a run |

---

### 3.8 `control_unit` — Instruction Decoder

**Source**: `src/control_unit.sv`

**Key RTL facts:**
- Purely **combinational** — all outputs are `assign` statements.
- 88-bit instruction word sliced into named fields. No clock, no state.
- All assertions are **immediate concurrent** (no clock required, hold at all times).

**Assertions (all combinational — no posedge needed):**

| ID | Name | What it checks |
|----|------|----------------|
| CU-A1 | `p_sys_switch_bit` | `sys_switch_in === instruction[0]` |
| CU-A2 | `p_ub_rd_start_bit` | `ub_rd_start_in === instruction[1]` |
| CU-A3 | `p_ub_rd_transpose_bit` | `ub_rd_transpose === instruction[2]` |
| CU-A4 | `p_ub_wr_host_valid_1_bit` | `ub_wr_host_valid_in_1 === instruction[3]` |
| CU-A5 | `p_ub_wr_host_valid_2_bit` | `ub_wr_host_valid_in_2 === instruction[4]` |
| CU-A6 | `p_ub_rd_col_size_field` | `ub_rd_col_size === instruction[6:5]` |
| CU-A7 | `p_ub_rd_row_size_field` | `ub_rd_row_size === instruction[14:7]` |
| CU-A8 | `p_ub_rd_addr_field` | `ub_rd_addr_in === instruction[16:15]` |
| CU-A9 | `p_ub_ptr_sel_field` | `ub_ptr_sel === instruction[19:17]` |
| CU-A10 | `p_host_data_1_field` | `ub_wr_host_data_in_1 === instruction[35:20]` |
| CU-A11 | `p_host_data_2_field` | `ub_wr_host_data_in_2 === instruction[51:36]` |
| CU-A12 | `p_vpu_data_pathway_field` | `vpu_data_pathway === instruction[55:52]` |
| CU-A13 | `p_inv_batch_size_field` | `inv_batch_size_times_two_in === instruction[71:56]` |
| CU-A14 | `p_vpu_leak_factor_field` | `vpu_leak_factor_in === instruction[87:72]` |
| CU-A15 | `p_no_bits_overlap` | All named outputs together exactly cover bits [87:0] — no gap, no overlap. This is a static structural check. |

**Cover properties:**

| ID | Scenario |
|----|----------|
| CU-C1 | `vpu_data_pathway == 4'b1100` (forward pass mode) |
| CU-C2 | `vpu_data_pathway == 4'b1111` (transition mode) |
| CU-C3 | `vpu_data_pathway == 4'b0001` (backward pass mode) |
| CU-C4 | `sys_switch_in == 1` |
| CU-C5 | `ub_rd_transpose == 1` |

---

### 3.9 `vpu` — Vector Processing Unit

**Source**: `src/vpu.sv`

**Key RTL facts:**
- The 4-bit `vpu_data_pathway` routes data through 0–4 registered pipeline stages:
  - bit 3 = bias (1 cycle)
  - bit 2 = leaky_relu (1 cycle)
  - bit 1 = loss (1 cycle)
  - bit 0 = leaky_relu_derivative (1 cycle)
- Total pipeline latency = `$countones(vpu_data_pathway)` clock cycles.
- When a stage's bit is 0, the combinational mux bypasses that stage (zero latency for that stage).
- When `pathway == 4'b0000`: `vpu_data_out` = `vpu_data_in` (combinational passthrough, **no latency**). `vpu_valid_out` = `vpu_valid_in` combinationally.
- When `pathway == 4'b1100`: 2-cycle latency (bias register + relu register).
- When `pathway == 4'b0001`: 1-cycle latency (lr_d register only).
- When `pathway == 4'b1111`: 4-cycle latency.
- The `last_H` cache is only active when `pathway[1]=1` (loss stage enabled); else `lr_d_H_in` comes from the UB `H_in` ports.

**Assertions:**

| ID | Name | What it checks |
|----|------|----------------|
| VPU-A1 | `p_rst_clears_valid_out` | `rst \|=> (!vpu_valid_out_1 && !vpu_valid_out_2)` |
| VPU-A2 | `p_rst_clears_data_out` | `rst \|=> (vpu_data_out_1 == 0 && vpu_data_out_2 == 0)` |
| VPU-A3 | `p_zero_pathway_combinational_passthrough_valid` | `vpu_data_pathway == 4'b0000 \|-> (vpu_valid_out_1 == vpu_valid_in_1 && vpu_valid_out_2 == vpu_valid_in_2)` — immediate (no clock delay) |
| VPU-A4 | `p_zero_pathway_combinational_passthrough_data` | `vpu_data_pathway == 4'b0000 \|-> (vpu_data_out_1 == vpu_data_in_1 && vpu_data_out_2 == vpu_data_in_2)` |
| VPU-A5 | `p_forward_path_two_cycle_latency` | `(vpu_data_pathway == 4'b1100 && vpu_valid_in_1) \|=> ##1 vpu_valid_out_1` — 2-cycle delay |
| VPU-A6 | `p_backward_path_one_cycle_latency` | `(vpu_data_pathway == 4'b0001 && vpu_valid_in_1) \|=> vpu_valid_out_1` — 1-cycle delay |
| VPU-A7 | `p_transition_path_four_cycle_latency` | `(vpu_data_pathway == 4'b1111 && vpu_valid_in_1) \|=> ##3 vpu_valid_out_1` — 4-cycle delay |
| VPU-A8 | `p_no_output_when_no_input` | `(!vpu_valid_in_1 && vpu_data_pathway == 4'b0000) \|-> !vpu_valid_out_1` |
| VPU-A9 | `p_bias_disabled_no_bias_stage` | `!vpu_data_pathway[3] \|-> (bias_data_1_in == 0 && bias_data_2_in == 0)` — bias inputs are zero (bind to internal) |
| VPU-A10 | `p_last_H_cached_when_loss_active` | When `vpu_data_pathway[1]`, on posedge: `last_H_data_1_out == $past(last_H_data_1_in)` — H is registered |

**Cover properties:**

| ID | Scenario |
|----|----------|
| VPU-C1 | Forward pass pathway (`1100`) completes |
| VPU-C2 | Transition pathway (`1111`) completes |
| VPU-C3 | Backward pass pathway (`0001`) completes |
| VPU-C4 | Zero pathway — direct passthrough |
| VPU-C5 | Both columns active simultaneously |

---

## 4. Bind Strategy

Each assertion module is bound in simulation only — no synthesis impact.

```systemverilog
// example for pe:
bind pe pe_assertions u_pe_assert (
    .clk           (clk),
    .rst           (rst),
    .pe_psum_in    (pe_psum_in),
    .pe_weight_in  (pe_weight_in),
    .pe_accept_w_in(pe_accept_w_in),
    .pe_input_in   (pe_input_in),
    .pe_valid_in   (pe_valid_in),
    .pe_switch_in  (pe_switch_in),
    .pe_enabled    (pe_enabled),
    .pe_psum_out   (pe_psum_out),
    .pe_weight_out (pe_weight_out),
    .pe_input_out  (pe_input_out),
    .pe_valid_out  (pe_valid_out),
    .pe_switch_out (pe_switch_out)
);
```

Internal signals (e.g., `mul_out`, `mac_out`, `final_gradient`, `last_H_data_1_in`) are reached via **hierarchical reference** inside the bind module using `$root.dut_top.pe_inst.mul_out` or directly when the bind module is inside the DUT scope.

---

## 5. Gap Analysis — What SVA Cannot Fully Cover Here

| Gap | Reason | Mitigation |
|-----|--------|-----------|
| Exact fixed-point arithmetic result | `fxp_mul`/`fxp_add` rounding depends on the `ROUND` parameter inside `fixedpoint.sv`. A pure SVA correctness check would need a reference model. | Re-enable cocotb assertions with `NOASSERT=0` for numerical accuracy |
| UB memory content correctness | 128-word array write/read correctness is hard to fully specify with SVA without a shadow model | Add a UB reference model as a SystemVerilog checker module |
| Full forward+backward numerical result | End-to-end result requires multi-cycle golden model | Cocotb `test_tpu.py` with all asserts uncommented |
| Weight update accumulation (bias mode) | Multi-cycle loop in gradient_descent makes temporal assertions complex | Verify with cocotb `test_gradient_descent.py` with asserts uncommented |
| Stale `gradient_out` when `valid_in=0` in loss_child | By design, `gradient_out` always updates — this is a design choice, not a bug | Document and cover that consumer checks `valid_out` |

---

## 6. Files Created

All SVA assertion bind modules have been created under `sva/`:

```
sva/
    pe_assertions.sv                          ✅  13 assertions + 3 cover properties
    systolic_assertions.sv                    ✅   9 assertions + 5 cover properties
    bias_child_assertions.sv                  ✅   5 assertions + 3 cover properties
    leaky_relu_child_assertions.sv            ✅   7 assertions + 4 cover properties
    leaky_relu_derivative_child_assertions.sv ✅   6 assertions + 4 cover properties
    loss_child_assertions.sv                  ✅   7 assertions + 4 cover properties
    gradient_descent_assertions.sv            ✅   8 assertions + 3 cover properties
    control_unit_assertions.sv                ✅  14 assertions + 9 cover properties
    vpu_assertions.sv                         ✅  10 assertions + 5 cover properties
```

**Total: 79 assertions + 40 cover properties across 9 modules.**

---

## 7. Priority Order for Implementation

| Priority | Module | Reason |
|----------|--------|--------|
| 1 (Critical) | `pe` | Foundational compute unit; all higher modules depend on it |
| 2 (Critical) | `bias_child` / `leaky_relu_child` / `loss_child` / `leaky_relu_derivative_child` | All have identical structural pattern; quick to verify |
| 3 (High) | `gradient_descent` | Learning stability depends on correct weight update |
| 4 (High) | `control_unit` | Purely combinational — assertions are trivial to implement and instantly give confidence |
| 5 (Medium) | `systolic` | Integration of 4 PEs; valid chain timing |
| 6 (Medium) | `vpu` | Routing logic; pathway timing |
| 7 (Lower) | `unified_buffer` | Most complex; needs shadow memory model |
