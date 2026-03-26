# tiny-tpu â€” Formal Verification Plan

**Document ID:** FV-TTPU-001
**Version:** 1.0
**Status:** Released
**Date:** 2026-03-12
**Author:** Verification Team
**Reviewed By:** â€”
**Approved By:** â€”

---

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1 | 2026-03-01 | Verification Team | Initial draft |
| 1.0 | 2026-03-12 | Verification Team | Full property catalog, sign-off criteria, coverage plan |

---

## Table of Contents

1. [Scope and Objectives](#1-scope-and-objectives)
2. [Design Under Verification](#2-design-under-verification)
3. [Formal Verification Methodology](#3-formal-verification-methodology)
4. [Tool and Flow Setup](#4-tool-and-flow-setup)
5. [Clocking, Reset, and Interface Constraints](#5-clocking-reset-and-interface-constraints)
6. [Module-Level Verification Plan](#6-module-level-verification-plan)
   - 6.1 Processing Element (pe)
   - 6.2 Systolic Array (systolic)
   - 6.3 Bias Child (bias_child)
   - 6.4 Leaky ReLU Child (leaky_relu_child)
   - 6.5 Leaky ReLU Derivative Child (leaky_relu_derivative_child)
   - 6.6 Loss Child (loss_child)
   - 6.7 Gradient Descent (gradient_descent)
   - 6.8 Control Unit (control_unit)
   - 6.9 Vector Processing Unit (vpu)
   - 6.10 Unified Buffer (unified_buffer)
7. [Property Catalog â€” Master Table](#7-property-catalog--master-table)
8. [Constraint (Assume) Catalog](#8-constraint-assume-catalog)
9. [Cover Property Catalog](#9-cover-property-catalog)
10. [Abstraction and Complexity Management](#10-abstraction-and-complexity-management)
11. [Coverage Plan](#11-coverage-plan)
12. [Known Gaps and Waivers](#12-known-gaps-and-waivers)
13. [Glossary](#13-glossary)

---

## 1. Scope and Objectives

### 1.1 Scope

This document defines the formal verification (FV) plan for the **tiny-tpu** design â€” a minimal Tensor Processing Unit implementing a 2Ã—2 systolic array with a Vector Processing Unit (VPU) capable of executing forward and backward neural-network passes in hardware.

The plan covers:
- All RTL modules in `src/`
- SystemVerilog Assertion (SVA) bind modules in `sva/`
- Assume/Assert/Cover (AAC) methodology per module
- Formal tool flow using JasperGold / OneSpin / SymbiYosys (tool-agnostic where possible)

Out of scope:
- Gate-level netlist verification
- Power-aware formal (UPF/CPF)
- Security property verification

### 1.2 Objectives

| ID | Objective | Success Metric |
|----|-----------|----------------|
| OBJ-01 | Prove all reset properties on every register in the design | Zero unbounded-proof failures for RESET category assertions |
| OBJ-02 | Prove valid-chain protocol correctness across the pipeline | All VALID-PROTOCOL assertions proven or bounded (k â‰¥ pipeline depth) |
| OBJ-03 | Prove control-unit instruction decoding is lossless and non-overlapping | All CU assertions proven combinationally |
| OBJ-04 | Prove systolic array timing relationships (output latency = 2 cycles for col-1, 3 cycles for col-2) | S-A5 and S-A6 proven with k â‰¥ 4 |
| OBJ-05 | Prove VPU pathway latency for all four defined pathways | VPU-A3 through VPU-A7 proven |
| OBJ-06 | Achieve â‰¥ 90 % toggle coverage on all module IOs | Post-simulation toggle coverage report |
| OBJ-07 | All cover properties must be reachable (no vacuous coverage) | FV tool confirms all `cover` goals reached |
| OBJ-08 | Zero unresolved assumption conflicts | `assume` consistency check passes for all modules |

---

## 2. Design Under Verification

### 2.1 Design Summary

| Attribute | Value |
|-----------|-------|
| Top module | `tpu` |
| Language | SystemVerilog (IEEE 1800-2017) |
| Clock domains | Single clock (`clk`, synchronous positive-edge) |
| Reset | Synchronous active-high (`rst`) |
| Data format | Q8.8 signed 16-bit fixed-point (2's complement) |
| Systolic array size | 2 Ã— 2 (parameterised via `SYSTOLIC_ARRAY_WIDTH`) |
| Memory | 128 Ã— 16-bit unified buffer |
| Arithmetic library | `fixedpoint.sv` â€” `fxp_mul`, `fxp_add`, `fxp_addsub` (configurable `ROUND` parameter) |
| Instruction word width | 130 bits |

### 2.2 Module Hierarchy

```
tpu (top)
â”œâ”€â”€ unified_buffer
â”‚ â”” gradient_descent (Ã—2)
â”œâ”€â”€ systolic
â”‚   â”œâ”€â”€ pe (pe11)
â”‚   â”œâ”€â”€ pe (pe12)
â”‚   â”œâ”€â”€ pe (pe21)
â”‚   â””â”€â”€ pe (pe22)
â””â”€â”€ vpu
    â”œâ”€â”€ bias_child (Ã—2)
    â”œâ”€â”€ leaky_relu_child (Ã—2)
    â”œâ”€â”€ loss_child (Ã—2)
    â””â”€â”€ leaky_relu_derivative_child (Ã—2)
```

### 2.3 RTL File Inventory

| File | Module | Type | Lines (approx.) |
|------|--------|------|-----------------|
| `src/pe.sv` | `pe` | Sequential | ~90 |
| `src/systolic.sv` | `systolic` | Sequential | ~140 |
| `src/bias_child.sv` | `bias_child` | Sequential | ~40 |
| `src/bias_parent.sv` | `bias_parent` | Structural | ~30 |
| `src/leaky_relu_child.sv` | `leaky_relu_child` | Sequential | ~45 |
| `src/leaky_relu_parent.sv` | `leaky_relu_parent` | Structural | ~30 |
| `src/leaky_relu_derivative_child.sv` | `leaky_relu_derivative_child` | Sequential | ~50 |
| `src/leaky_relu_derivative_parent.sv` | `leaky_relu_derivative_parent` | Structural | ~30 |
| `src/loss_child.sv` | `loss_child` | Sequential | ~55 |
| `src/loss_parent.sv` | `loss_parent` | Structural | ~30 |
| `src/gradient_descent.sv` | `gradient_descent` | Sequential | ~75 |
| `src/control_unit.sv` | `control_unit` | Combinational | ~55 |
| `src/vpu.sv` | `vpu` | Sequential | ~250 |
| `src/unified_buffer.sv` | `unified_buffer` | Sequential | ~400 |
| `src/fixedpoint.sv` | `fxp_*` | Combinational (library) | ~600 |
| `src/tpu.sv` | `tpu` | Structural (top) | ~200 |

### 2.4 VPU Data Pathways

| `vpu_data_pathway` | Name | Stages Active | Pipeline Latency |
|--------------------|------|---------------|-----------------|
| `4'b0000` | Passthrough | None | 1 cycle (output register) |
| `4'b1100` | Forward pass | Bias → LeakyReLU | 3 cycles |
| `4'b1111` | Transition | Bias → LeakyReLU → Loss → LRDerivative | 5 cycles |
| `4'b0001` | Backward pass | LRDerivative only | 2 cycles |

### 2.5 Instruction Word Bit-Field Map

| Bits | Width | Signal | Description |
|------|-------|--------|-------------|
| [0] | 1 | `sys_switch_in` | Trigger systolic weight switch |
| [1] | 1 | `ub_rd_start_in` | Start UB read sequence |
| [2] | 1 | `ub_rd_transpose` | Transpose matrix on UB read |
| [3] | 1 | `ub_wr_host_valid_in_1` | Host write valid, port 1 |
| [4] | 1 | `ub_wr_host_valid_in_2` | Host write valid, port 2 |
| [20:5] | 16 | `ub_rd_col_size` | Number of active systolic columns |
| [36:21] | 16 | `ub_rd_row_size` | Number of matrix rows to read |
| [52:37] | 16 | `ub_rd_addr_in` | UB read address |
| [61:53] | 9 | `ub_ptr_select` | UB pointer selector |
| [77:62] | 16 | `ub_wr_host_data_in_1` | Host write data, port 1 |
| [93:78] | 16 | `ub_wr_host_data_in_2` | Host write data, port 2 |
| [97:94] | 4 | `vpu_data_pathway` | VPU pipeline routing |
| [113:98] | 16 | `inv_batch_size_times_two_in` | 2/N constant for MSE |
| [129:114] | 16 | `vpu_leak_factor_in` | Leaky ReLU alpha factor |

---

## 3. Formal Verification Methodology

### 3.1 Approach

The formal verification uses the **Assume-Assert-Cover (AAC)** methodology:

- **`assume`** â€” Constraints that restrict the formal engine's input space to legal stimulus only. Must be consistent (no vacuity).
- **`assert`** â€” Properties that must hold for all reachable states. A counterexample (CEX) from the tool indicates a real design bug.
- **`cover`** â€” Reachability goals. Confirms that a target state or sequence is achievable under the given assumptions.

### 3.2 Assertion Categories

| Category | ID Prefix | SVA Construct | Formal Goal |
|----------|-----------|---------------|-------------|
| Reset | RST | `property â€¦ rst \|=> â€¦` | Unbounded proof â€” holds after any number of cycles |
| Valid Protocol | VP | `property` on handshake signals | Bounded proof (k â‰¥ pipeline depth + 2) |
| Data Path | DP | `$past`-based data capture check | Bounded proof (k â‰¥ register depth + 1) |
| Functional Arithmetic | FA | `$past`-based arithmetic equality | Bounded proof â€” exact formula check |
| Structural / Decode | SD | Combinational implication (`\|->`) | Combinational proof (k = 0) |
| Mutual Exclusion | ME | Concurrent signal conflict check | Unbounded proof |
| Liveness / Reachability | LV | `cover property` | Reachability (cover goal) |

### 3.3 Proof Strategy

| Module type | Strategy | Bound (k) |
|-------------|----------|-----------|
| Purely combinational (`control_unit`) | Combinational proof | 0 |
| Shallow pipeline (1â€“2 registers deep) | Bounded Model Checking (BMC) | 4â€“8 |
| Deeper pipeline (`vpu` 5-stage, including output register) | BMC + induction | 10 |
| Memory-heavy (`unified_buffer`) | BMC with abstracted memory | 32 |
| Full top-level (`tpu`) | Black-box / connectivity only | 4 |

### 3.4 Assertion Bind Strategy

Each module's assertions reside in a dedicated bind file under `sva/`. The bind instantiation is:

```systemverilog
bind <module_name> <module_name>_assertions u_<module_name>_fv (.*);
```

This keeps the RTL unchanged and allows assertions to be enabled or disabled without modifying source files.

### 3.5 Formal Verification Flow

```
RTL Sources (src/)
       â”‚
       â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  Elaboration + Lint         â”‚  (Synopsys DC / Icarus / Verilator)
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚
             â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  Compile Assertion Binds    â”‚  sva/*.sv compiled alongside DUT
â”‚  (sva/*.sv)                 â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚
             â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  Formal Engine              â”‚  JasperGold / OneSpin / SymbiYosys
â”‚  - Load assume constraints  â”‚
â”‚  - Run assert proofs        â”‚
â”‚  - Evaluate cover goals     â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
             â”‚
       â”Œâ”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”
       â”‚            â”‚
   PROVEN        FAILED / CEX
       â”‚            â”‚
  Log result    Debug waveform
  in FV DB      â†’ Fix RTL / Assert
                â†’ Re-run
             â”‚
             â–¼
â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
â”‚  Sign-Off Report            â”‚
â”‚  (see Section 12)           â”‚
â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

---

## 4. Tool and Flow Setup

### 4.1 Supported Formal Tools

| Tool | Vendor | Usage |
|------|--------|-------|
| JasperGold FPV | Cadence | Primary â€” full ABV, cover, unreachability |
| OneSpin 360 DV | OneSpin / Siemens | Alternate â€” full ABV |
| SymbiYosys + Boolector/z3 | YosysHQ (open-source) | Open-source option for bounded proofs |
| Verilator + CocoTB | Open-source | Simulation-based cross-check |

### 4.2 File Compilation Order

```
fixedpoint.sv
pe.sv
bias_child.sv
bias_parent.sv
leaky_relu_child.sv
leaky_relu_parent.sv
leaky_relu_derivative_child.sv
leaky_relu_derivative_parent.sv
loss_child.sv
loss_parent.sv
gradient_descent.sv
control_unit.sv
systolic.sv
vpu.sv
unified_buffer.sv
tpu.sv
sva/pe_assertions.sv                          (bind)
sva/systolic_assertions.sv                    (bind)
sva/bias_child_assertions.sv                  (bind)
sva/leaky_relu_child_assertions.sv            (bind)
sva/leaky_relu_derivative_child_assertions.sv (bind)
sva/loss_child_assertions.sv                  (bind)
sva/gradient_descent_assertions.sv            (bind)
sva/control_unit_assertions.sv                (bind)
sva/vpu_assertions.sv                         (bind)
sva/unified_buffer_assertions.sv              (bind)
```

---

## 5. Clocking, Reset, and Interface Constraints

### 5.1 Global Clock and Reset Assumptions

```systemverilog
// Single clock, no gating
assume property (@(posedge clk) 1'b1);

// Reset releases after at least 2 cycles at simulation start.
// rst is held for exactly 2 cycles then released and never re-asserted
// within the formal proof window — prevents paradoxical re-assertion
// that would vacuously prove all post-reset assertions.
assume property (@(posedge clk) $rose(rst) |=> rst);             // rst held ≥ 1 cycle after rising
assume property (@(posedge clk) rst |-> $past(rst) || $rose(rst)); // rst never rises after falling
assume property (@(posedge clk) ##2 !rst throughout (##[0:$] 1'b1) |-> ##[0:$] !rst);
// Simplified portable form (tool-agnostic):
// assume property (@(posedge clk) $fell(rst) |-> ##[0:$] !rst);  // once fallen, stays low
```

> **Note (v1.1):** The original `assume property (@(posedge clk) ##2 !rst)` fires unconditionally every cycle,
> constraining `rst` to be 0 two cycles after *every* clock edge — this makes `rst` permanently 0 regardless
> of initial conditions and collapses the reset assumption space.  The corrected form above uses
> `$fell(rst) |-> ##[0:$] !rst` to express that once reset deasserts it stays deasserted.

### 5.2 Fixed-Point Data Validity

All 16-bit data inputs are free (unconstrained) unless the specific property under proof narrows the range. The Q8.8 interpretation is only relevant for functional arithmetic assertions; structural and protocol assertions treat data as opaque bit vectors.

### 5.3 VPU Pathway Constraint

During a proof run targeting a specific pathway, the pathway register is constrained to a single value to prevent state explosion:

```systemverilog
assume property (@(posedge clk) vpu_data_pathway == 4'b1100);  // forward pass proof run
```

Separate proof runs are executed for each of the four defined pathways.

---

## 6. Module-Level Verification Plan

---

### 6.1 Processing Element (`pe`)

**Source:** `src/pe.sv`
**Assertion file:** `sva/pe_assertions.sv`
**Verification approach:** Bounded proof, k = 6

#### RTL Summary

| Register | Reset value | Update condition |
|----------|-------------|-----------------|
| `pe_psum_out` | 0 | `pe_valid_in` â†’ `mac_out`; else 0 |
| `pe_valid_out` | 0 | Always = `pe_valid_in` (both branches) |
| `pe_switch_out` | 0 | Always = `pe_switch_in`; cleared to 0 on `rst` **or** `!pe_enabled` |
| `pe_weight_out` | 0 | `pe_accept_w_in` → `pe_weight_in`; else 0; cleared to 0 on `rst` **or** `!pe_enabled` |
| `pe_input_out` | 0 | `pe_valid_in` → `pe_input_in`; else cleared to 0; also cleared on `rst` or `!pe_enabled` |
| `weight_reg_inactive` | 0 | `pe_accept_w_in` → `pe_weight_in`; cleared on `rst` or `!pe_enabled` |
| `weight_reg_active` | 0 | `pe_switch_in` → `weight_reg_inactive`; cleared on `rst` or `!pe_enabled` |

Both `rst` and `!pe_enabled` force **all** registers to 0 (the RTL `if (rst || !pe_enabled)` branch covers both conditions simultaneously).

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| PE-A01 | `p_rst_clears_psum` | RST | `rst \|=> pe_psum_out == 0` | Unbounded | P1 | Open |
| PE-A02 | `p_rst_clears_valid` | RST | `rst \|=> !pe_valid_out` | Unbounded | P1 | Open |
| PE-A03 | `p_rst_clears_switch` | RST | `rst \|=> !pe_switch_out` | Unbounded | P1 | Open |
| PE-A04 | `p_rst_clears_weight_out` | RST | `rst \|=> pe_weight_out == 0` | Unbounded | P1 | Open |
| PE-A05 | `p_rst_clears_input_out` | RST | `rst \|=> pe_input_out == 0` | Unbounded | P1 | Open |
| PE-A06 | `p_disabled_clears_outputs` | RST | `!pe_enabled \|=> (pe_psum_out==0 && !pe_valid_out && !pe_switch_out && pe_weight_out==0)` | Unbounded | P1 | Open |
| PE-A07 | `p_valid_out_registered` | VP | `1'b1 \|=> pe_valid_out == $past(pe_valid_in)` | BMC k=4 | P1 | Open |
| PE-A08 | `p_switch_out_registered` | VP | `1'b1 \|=> pe_switch_out == $past(pe_switch_in)` | BMC k=4 | P1 | Open |
| PE-A09 | `p_weight_out_when_accepting` | DP | `pe_accept_w_in \|=> pe_weight_out == $past(pe_weight_in)` | BMC k=4 | P1 | Open |
| PE-A10 | `p_weight_out_zero_when_idle` | DP | `!pe_accept_w_in \|=> pe_weight_out == 0` | BMC k=4 | P1 | Open |
| PE-A11 | `p_input_out_captured_on_valid` | DP | `pe_valid_in \|=> pe_input_out == $past(pe_input_in)` | BMC k=4 | P2 | Open |
| PE-A12 | `p_psum_zero_when_invalid` | DP | `!pe_valid_in \|=> pe_psum_out == 0` | BMC k=4 | P1 | Open |
| PE-A13 | `p_valid_out_low_when_in_low` | VP | `!pe_valid_in \|=> !pe_valid_out` — explicit port-level statement that valid cannot appear without a valid input; derived from PE-A07 but stated as a separate check for clarity | BMC k=4 | P1 | Open |
| PE-A14 | `p_rst_clears_weight_reg_active / inactive` | RST | `(rst \|\| !pe_enabled) \|=> weight_reg_active==0 && weight_reg_inactive==0` (internal shadow registers) | Unbounded | P1 | Open |
| PE-A15 | `p_weight_switch` | DP | `pe_switch_in \|=> weight_reg_active == $past(weight_reg_inactive)` | BMC k=4 | P1 | Open |
| PE-A16 | `p_input_out_clear_when_invalid` | DP | `!pe_valid_in \|=> pe_input_out == 16'b0` — when not valid, input passthrough register is zeroed (RTL `else pe_input_out <= 16'b0`) | BMC k=4 | P1 | Open |
| PE-A17 | `p_rst_clears_overflow` | RST | `(rst \|\| !pe_enabled) \|=> !pe_overflow_out` — hardware overflow flag is cleared on reset or PE disable | Unbounded | P1 | Open |
| PE-A18 | `p_overflow_is_sticky` | FA | `pe_overflow_out \|=> pe_overflow_out` — once overflow is set it stays set until rst; sticky accumulator behaviour | BMC k=4 | P1 | Open |
| PE-A19 | `p_mac_zero_input_passthrough_psum` | FA | `(pe_valid_in && pe_input_in==0) \|=> pe_psum_out == $past(pe_psum_in)` — port-observable MAC proxy; see PE-W01 | BMC k=4 | P2 | Open |

#### Assumptions (Constraints)

| Assume ID | Description |
|-----------|-------------|
| PE-C01 | `pe_enabled` is held constant after initial assertion (no mid-computation disable in standard use) |
| PE-C02 | `pe_psum_in` is 0 for the first PE in a column (pe11, pe12 top cells) |

---

### 6.2 Systolic Array (`systolic`)

**Source:** `src/systolic.sv`
**Assertion file:** `sva/systolic_assertions.sv`
**Verification approach:** Bounded proof, k = 8 (covers 3-cycle latency with margin)

#### RTL Summary

| Signal | Derivation |
|--------|-----------|
| `pe_enabled` | Registered: `(1 << ub_rd_col_size_in) - 1` on `ub_rd_col_size_valid_in` |
| `sys_valid_out_21` | `pe_valid_out_11` → `pe21.pe_valid_out` = 1 clock cycle from `sys_start_2` |
| `sys_valid_out_22` | `sys_start_1` → pe11 → pe12 → pe22 (3 register stages) = **3 clock cycles** from `sys_start_1` |
| `sys_data_out_21` | `pe21.pe_psum_out` |
| `sys_data_out_22` | `pe22.pe_psum_out` |

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| SYS-A01 | `p_rst_clears_valid_out_21` | RST | `rst \|=> !sys_valid_out_21` | Unbounded | P1 | Open |
| SYS-A02 | `p_rst_clears_valid_out_22` | RST | `rst \|=> !sys_valid_out_22` | Unbounded | P1 | Open |
| SYS-A03 | `p_rst_clears_data_out_21` | RST | `rst \|=> sys_data_out_21 == 0` | Unbounded | P1 | Open |
| SYS-A04 | `p_rst_clears_data_out_22` | RST | `rst \|=> sys_data_out_22 == 0` | Unbounded | P1 | Open |
| SYS-A05 | `p_valid_21_one_cycle_delay` | VP | `sys_start_2 \|=> sys_valid_out_21` | BMC k=8 | P1 | Open |
| SYS-A06 | `p_valid_22_three_cycles_after_start1` | VP | `sys_start_1 \|=> ##2 sys_valid_out_22` — 3 register stages: pe11→pe12→pe22 | BMC k=8 | P1 | Open |
| SYS-A07 | `p_no_valid_without_start` | VP | `!sys_start_2 \|=> !sys_valid_out_21` | BMC k=8 | P2 | Open |
| SYS-A08 | `p_col_size_1_disables_col2` | ME | `(ub_rd_col_size_valid_in && ub_rd_col_size_in==1) \|=> !sys_valid_out_22` | BMC k=8 | P1 | Open |
| SYS-A09 | `p_col_size_encodes_as_mask` | SD | `(ub_rd_col_size_valid_in && ub_rd_col_size_in==2) \|=> (pe_enabled == 2'b11)` | BMC k=4 | P2 | Open |
| SYS-A10 | `p_accept_w_cols_independent` | ME | `sys_accept_w_1 && !sys_accept_w_2 â€” no spurious weight update on col2` | BMC k=4 | P2 | Open |

#### Assumptions

| Assume ID | Description |
|-----------|-------------|
| SYS-C01 | `ub_rd_col_size_in` is constrained to `{1, 2}` â€” values outside the valid range are illegal |
| SYS-C02 | `sys_start` is deasserted for at least 1 cycle between consecutive batches |

---

### 6.3 Bias Child (`bias_child`)

**Source:** `src/bias_child.sv`
**Assertion file:** `sva/bias_child_assertions.sv`
**Verification approach:** Bounded proof, k = 4

#### RTL Summary

| Stage | Type | Description |
|-------|------|-------------|
| `z_pre_activation` | Combinational | `fxp_add(bias_sys_data_in, bias_scalar_in)` |
| `bias_z_data_out` | Sequential | Latches `z_pre_activation` when `bias_sys_valid_in=1`; clears to 0 when `bias_sys_valid_in=0` |
| `bias_Z_valid_out` | Sequential | Mirrors `bias_sys_valid_in` (1-cycle delay) |

No hold behaviour on data â€” both data and valid clear when `valid_in = 0`.

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| BC-A01 | `p_rst_clears_valid` | RST | `rst \|=> !bias_Z_valid_out` | Unbounded | P1 | Open |
| BC-A02 | `p_rst_clears_data` | RST | `rst \|=> bias_z_data_out == 0` | Unbounded | P1 | Open |
| BC-A03 | `p_valid_out_mirrors_valid_in` | VP | `1'b1 \|=> bias_Z_valid_out == $past(bias_sys_valid_in)` | BMC k=4 | P1 | Open |
| BC-A04 | `p_data_zero_when_invalid` | DP | `!bias_sys_valid_in \|=> bias_z_data_out == 0` | BMC k=4 | P1 | Open |
| BC-A05 | `p_data_latches_pre_activation` | FA | `bias_sys_valid_in \|=> bias_z_data_out == $past(z_pre_activation)` | BMC k=4 | P2 | Open |

---

### 6.4 Leaky ReLU Child (`leaky_relu_child`)

**Source:** `src/leaky_relu_child.sv`
**Assertion file:** `sva/leaky_relu_child_assertions.sv`
**Verification approach:** Bounded proof, k = 4

#### RTL Summary

| Condition | `lr_data_out` value | `lr_valid_out` |
|-----------|--------------------|-|
| `!lr_valid_in` | 0 | 0 |
| `lr_valid_in && lr_data_in >= 0` | `lr_data_in` (passthrough) | 1 |
| `lr_valid_in && lr_data_in < 0` | `fxp_mul(lr_data_in, lr_leak_factor_in)` | 1 |

Sign check is performed on the wire value at the clock edge (`bit[15]` = sign bit for Q8.8).

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| LRC-A01 | `p_rst_clears_outputs` | RST | `rst \|=> (!lr_valid_out && lr_data_out==0)` | Unbounded | P1 | Open |
| LRC-A02 | `p_valid_out_mirrors_valid_in` | VP | `1'b1 \|=> lr_valid_out == $past(lr_valid_in)` | BMC k=4 | P1 | Open |
| LRC-A03 | `p_data_zero_when_invalid` | DP | `!lr_valid_in \|=> lr_data_out == 0` | BMC k=4 | P1 | Open |
| LRC-A04 | `p_positive_passes_through` | FA | `(lr_valid_in && !lr_data_in[15]) \|=> lr_data_out == $past(lr_data_in)` | BMC k=4 | P1 | Open |
| LRC-A05 | `p_negative_is_scaled` | FA | `(lr_valid_in && lr_data_in[15]) \|=> lr_data_out == $past(mul_out)` | BMC k=4 | P1 | Open |
| LRC-A06 | `p_sign_preserved_for_positive` | SD | `(lr_valid_in && !lr_data_in[15]) \|=> !lr_data_out[15]` | BMC k=4 | P2 | Open |
| LRC-A07 | `p_zero_input_zero_output` | FA | `(lr_valid_in && lr_data_in==0) \|=> lr_data_out==0` | BMC k=4 | P2 | Open |

---

### 6.5 Leaky ReLU Derivative Child (`leaky_relu_derivative_child`)

**Source:** `src/leaky_relu_derivative_child.sv`
**Assertion file:** `sva/leaky_relu_derivative_child_assertions.sv`
**Verification approach:** Bounded proof, k = 4

#### RTL Summary

| Condition | `lr_d_data_out` | `lr_d_valid_out` |
|-----------|----------------|-----------------|
| `!lr_d_valid_in` | 0 | `lr_d_valid_in` (plain register, no gating) |
| `lr_d_valid_in && lr_d_H_data_in >= 0` | `lr_d_data_in` (passthrough) | 1 |
| `lr_d_valid_in && lr_d_H_data_in < 0` | `fxp_mul(lr_d_data_in, lr_leak_factor_in)` | 1 |

**Key distinction from `leaky_relu_child`:** `lr_d_valid_out` is an unconditional register of `lr_d_valid_in` â€” no override to 0 in the `else` branch. Routing decision is based on **H** (stored forward-pass activation), not the gradient itself.

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| LRD-A01 | `p_rst_clears_outputs` | RST | `rst \|=> (!lr_d_valid_out && lr_d_data_out==0)` | Unbounded | P1 | Open |
| LRD-A02 | `p_valid_out_plain_register` | VP | `1'b1 \|=> lr_d_valid_out == $past(lr_d_valid_in)` | BMC k=4 | P1 | Open |
| LRD-A03 | `p_data_zero_when_invalid` | DP | `!lr_d_valid_in \|=> lr_d_data_out == 0` | BMC k=4 | P1 | Open |
| LRD-A04 | `p_positive_H_passes_gradient` | FA | `(lr_d_valid_in && !lr_d_H_data_in[15]) \|=> lr_d_data_out == $past(lr_d_data_in)` | BMC k=4 | P1 | Open |
| LRD-A05 | `p_negative_H_scales_gradient` | FA | `(lr_d_valid_in && lr_d_H_data_in[15]) \|=> lr_d_data_out == $past(mul_out)` | BMC k=4 | P1 | Open |
| LRD-A06 | `p_zero_H_passes_gradient` | FA | `(lr_d_valid_in && lr_d_H_data_in==0) \|=> lr_d_data_out == $past(lr_d_data_in)` | BMC k=4 | P2 | Open |

---

### 6.6 Loss Child (`loss_child`)

**Source:** `src/loss_child.sv`
**Assertion file:** `sva/loss_child_assertions.sv`
**Verification approach:** Bounded proof, k = 4

#### RTL Summary

| Stage | Type | Expression |
|-------|------|-----------|
| `diff_stage1` | Combinational | `fxp_addsub(H_in, Y_in, sub=1)` = H âˆ’ Y |
| `final_gradient` | Combinational | `fxp_mul(diff_stage1, inv_batch_size_times_two_in)` = (2/N)Â·(Hâˆ’Y) |
| `gradient_out` | Sequential | `= final_gradient` when `valid_in=1`; **cleared to 0** when `valid_in=0` |
| `valid_out` | Sequential | Always = `valid_in` (1-cycle registered mirror) |

**Note (v1.1 correction):** `gradient_out` IS gated on `valid_in` — the RTL clears `gradient_out` to 0 in the
`else` branch. The previous description ("no valid gating on data") was based on a pre-fix RTL version.
GAP-05 in Section 12.1 is now resolved — see Section 12.2 update.

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| LC-A01 | `p_rst_clears_gradient` | RST | `rst \|=> gradient_out == 0` | Unbounded | P1 | Open |
| LC-A02 | `p_rst_clears_valid` | RST | `rst \|=> !valid_out` | Unbounded | P1 | Open |
| LC-A03 | `p_valid_out_registered` | VP | `1'b1 \|=> valid_out == $past(valid_in)` | BMC k=4 | P1 | Open |
| LC-A04 | `p_data_zero_when_invalid` | DP | `!valid_in \|=> gradient_out == 0` — RTL explicitly clears `gradient_out` to 0 in the `else` branch when `valid_in=0` | BMC k=4 | P1 | Open |
| LC-A05 | `p_gradient_sign_H_gt_Y` | FA | `(valid_in && H_in > Y_in) \|=> !gradient_out[15]` | BMC k=4 | P2 | Open |
| LC-A06 | `p_gradient_sign_H_lt_Y` | FA | `(valid_in && H_in < Y_in) \|=> gradient_out[15]` | BMC k=4 | P2 | Open |
| LC-A07 | `p_gradient_zero_when_H_eq_Y` | FA | `(valid_in && H_in == Y_in) \|=> gradient_out == 0` | BMC k=4 | P2 | Open |

---

### 6.7 Gradient Descent (`gradient_descent`)

**Source:** `src/gradient_descent.sv`
**Assertion file:** `sva/gradient_descent_assertions.sv`
**Verification approach:** Bounded proof, k = 6

#### RTL Summary

| Signal | Type | Description |
|--------|------|-------------|
| `mul_out` | Combinational | `fxp_mul(grad_in, lr_in)` = gradient Ã— learning rate |
| `sub_in_a` | Combinational mux | Weight mode: `value_old_in`; Bias mode: `value_updated_out` if done, else `value_old_in` |
| `sub_value_out` | Combinational | `fxp_addsub(sub_in_a, mul_out, sub=1)` |
| `value_updated_out` | Sequential | `sub_value_out` when `grad_descent_valid_in`; else 0 |
| `grad_descent_done_out` | Sequential | Always = `grad_descent_valid_in` (1-cycle delay, no gating) |

The bias mode creates a **feedback loop** (`value_updated_out â†’ sub_in_a`) enabling multi-cycle accumulation across a batch dimension.

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| GD-A01 | `p_rst_clears_output` | RST | `rst \|=> value_updated_out == 0` | Unbounded | P1 | Open |
| GD-A02 | `p_rst_clears_done` | RST | `rst \|=> !grad_descent_done_out` | Unbounded | P1 | Open |
| GD-A03 | `p_done_one_cycle_delay` | VP | `1'b1 \|=> grad_descent_done_out == $past(grad_descent_valid_in)` | BMC k=6 | P1 | Open |
| GD-A04 | `p_output_holds_when_invalid` | DP | `!grad_descent_valid_in \|=> value_updated_out == $past(value_updated_out)` | BMC k=6 | P1 | Open |
| GD-A05 | `p_weight_mode_update_formula` | FA | `(grad_descent_valid_in && grad_bias_or_weight) \|=> value_updated_out == $past(value_old_in) - $past(mul_out)` | BMC k=6 | P1 | Open |
| GD-A06 | `p_done_implies_valid_was_set` | VP | `grad_descent_done_out \|-> $past(grad_descent_valid_in)` | BMC k=6 | P1 | Open |
| GD-A07 | `p_not_done_implies_valid_was_clear` | VP | `!grad_descent_done_out \|-> !$past(grad_descent_valid_in)` | BMC k=6 | P1 | Open |

#### Assumptions

| Assume ID | Description |
|-----------|-------------|
| GD-C01 | In weight mode (`grad_bias_or_weight=1`), `grad_descent_done_out` feedback path is not exercised (combinational bypass) |
| GD-C02 | In bias mode (`grad_bias_or_weight=0`), proof run constrains batch size â‰¤ 4 to bound state space |

---

### 6.8 Control Unit (`control_unit`)

**Source:** `src/control_unit.sv`
**Assertion file:** `sva/control_unit_assertions.sv`
**Verification approach:** Combinational proof (k = 0) â€” module is purely combinational

#### RTL Summary

The control unit decodes a 130-bit instruction word (`[129:0]`) into named field outputs using continuous `assign` statements. There is no clock, no state, and no reset.

#### Assertions

| Assert ID | Name | Category | Bit Range | Property | Proof Type | Priority | Status |
|-----------|------|----------|-----------|----------|------------|----------|--------|
| CU-A01 | `p_sys_switch_bit` | SD | [0] | `sys_switch_in === instruction[0]` | Comb | P1 | Open |
| CU-A02 | `p_ub_rd_start_bit` | SD | [1] | `ub_rd_start_in === instruction[1]` | Comb | P1 | Open |
| CU-A03 | `p_ub_rd_transpose_bit` | SD | [2] | `ub_rd_transpose === instruction[2]` | Comb | P1 | Open |
| CU-A04 | `p_ub_wr_host_valid_1_bit` | SD | [3] | `ub_wr_host_valid_in_1 === instruction[3]` | Comb | P1 | Open |
| CU-A05 | `p_ub_wr_host_valid_2_bit` | SD | [4] | `ub_wr_host_valid_in_2 === instruction[4]` | Comb | P1 | Open |
| CU-A06 | `p_ub_rd_col_size_field` | SD | [20:5] | `ub_rd_col_size === instruction[20:5]` | Comb | P1 | Open |
| CU-A07 | `p_ub_rd_row_size_field` | SD | [36:21] | `ub_rd_row_size === instruction[36:21]` | Comb | P1 | Open |
| CU-A08 | `p_ub_rd_addr_field` | SD | [52:37] | `ub_rd_addr_in === instruction[52:37]` | Comb | P1 | Open |
| CU-A09 | `p_ub_ptr_select_field` | SD | [61:53] | `ub_ptr_select === instruction[61:53]` | Comb | P1 | Open |
| CU-A10 | `p_host_data_1_field` | SD | [77:62] | `ub_wr_host_data_in_1 === instruction[77:62]` | Comb | P1 | Open |
| CU-A11 | `p_host_data_2_field` | SD | [93:78] | `ub_wr_host_data_in_2 === instruction[93:78]` | Comb | P1 | Open |
| CU-A12 | `p_vpu_data_pathway_field` | SD | [97:94] | `vpu_data_pathway === instruction[97:94]` | Comb | P1 | Open |
| CU-A13 | `p_inv_batch_size_field` | SD | [113:98] | `inv_batch_size_times_two_in === instruction[113:98]` | Comb | P1 | Open |
| CU-A14 | `p_vpu_leak_factor_field` | SD | [129:114] | `vpu_leak_factor_in === instruction[129:114]` | Comb | P1 | Open |
| CU-A15 | `p_bit_field_no_overlap` | SD | [129:0] | All named fields together cover bits [129:0] with no gap and no overlap (static structural check) | Comb | P1 | Open |

---

### 6.9 Vector Processing Unit (`vpu`)

**Source:** `src/vpu.sv`
**Assertion file:** `sva/vpu_assertions.sv`
**Verification approach:** Bounded proof, k = 10 (covers 5-stage pipeline including output register)

#### RTL Summary

| `vpu_data_pathway` bit | Stage | Pipeline depth contribution |
|------------------------|-------|-----------------------------|
| [3] | `bias_child` | +1 cycle |
| [2] | `leaky_relu_child` | +1 cycle |
| [1] | `loss_child` | +1 cycle |
| [0] | `leaky_relu_derivative_child` | +1 cycle |

When a pathway bit is 0, the combinational mux bypasses that stage entirely (zero latency contribution from that stage). The VPU always adds +1 cycle for the output register (`always_ff` BUG-VPU-1 fix). Total latency = (number of set bits in `vpu_data_pathway`) + 1.

The `last_H` cache is active only when `pathway[1]=1` (loss stage engaged); otherwise `lr_d_H_data_in` is sourced from UB `H_in` ports.

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| VPU-A01 | `p_rst_clears_valid_out` | RST | `rst \|=> (!vpu_valid_out_1 && !vpu_valid_out_2)` | Unbounded | P1 | Open |
| VPU-A02 | `p_rst_clears_data_out` | RST | `rst \|=> (vpu_data_out_1==0 && vpu_data_out_2==0)` | Unbounded | P1 | Open |
| VPU-A03 | `p_zero_pathway_reg_valid` | VP | `vpu_data_pathway==4'b0000 \|=> (vpu_valid_out_1==$past(vpu_valid_in_1) && vpu_valid_out_2==$past(vpu_valid_in_2))` | BMC k=4 | P1 | Open |
| VPU-A04 | `p_zero_pathway_reg_data` | DP | `vpu_data_pathway==4'b0000 \|=> (vpu_data_out_1==$past(vpu_data_in_1) && vpu_data_out_2==$past(vpu_data_in_2))` | BMC k=4 | P1 | Open |
| VPU-A05 | `p_forward_path_3cy_latency` | VP | `(vpu_data_pathway==4'b1100 && vpu_valid_in_1) \|=> ##2 vpu_valid_out_1` | BMC k=8 | P1 | Open |
| VPU-A06 | `p_backward_path_2cy_latency` | VP | `(vpu_data_pathway==4'b0001 && vpu_valid_in_1) \|=> ##1 vpu_valid_out_1` | BMC k=6 | P1 | Open |
| VPU-A07 | `p_transition_path_5cy_latency` | VP | `(vpu_data_pathway==4'b1111 && vpu_valid_in_1) \|=> ##4 vpu_valid_out_1` | BMC k=10 | P1 | Open |
| VPU-A08 | `p_no_output_without_input_reg` | VP | `(vpu_data_pathway==4'b0000 && !vpu_valid_in_1) \|=> !vpu_valid_out_1` | BMC k=4 | P2 | Open |
| VPU-A09 | `p_dual_column_simultaneous` | VP | `(vpu_valid_in_1 && vpu_valid_in_2) \|=> (vpu_valid_out_1 == vpu_valid_out_2)` (non-zero pathway; both columns share same pipeline stages so valid timing must match) | BMC k=4 | P2 | Open |
| VPU-A10 | `p_last_H_registered_when_loss_active` | DP | `vpu_data_pathway[1] && vpu_valid_in_1 \|=> last_H_data_1_out == $past(last_H_data_1_in)` | BMC k=6 | P2 | Open |

#### Assumptions

| Assume ID | Description |
|-----------|-------------|
| VPU-C01 | `vpu_data_pathway` is constrained to one of the four defined values per proof run: `0000`, `1100`, `1111`, `0001` |
| VPU-C02 | For latency proofs, `vpu_valid_in_1` is held high for the complete pipeline depth |

---

### 6.10 Unified Buffer (`unified_buffer`)

**Source:** `src/unified_buffer.sv`
**Assertion file:** `sva/unified_buffer_assertions.sv`
**Verification approach:** BMC with abstracted memory model, k = 32

#### RTL Summary

| Sub-component | Description |
|---------------|-------------|
| `ub_memory[0:127]` | 128 Ã— 16-bit SRAM-style array |
| `wr_ptr` | Write pointer â€” incremented on VPU write back |
| `rd_*_ptr` registers | Independent read sequencers per data type (input, weight, bias, Y, H, grad_bias, grad_weight) |
| `ub_rd_col_size_out` | Forwarded to systolic to mask PE columns |
| Gradient descent | Two `gradient_descent` instances embedded for bias and weight updates |

#### Assertions

| Assert ID | Name | Category | Property | Proof Type | Priority | Status |
|-----------|------|----------|----------|------------|----------|--------|
| UB-A01 | `p_rst_clears_wr_ptr` | RST | `rst \|=> wr_ptr == 0` | Unbounded | P1 | Open |
| UB-A02 | `p_rst_clears_col_size_valid` | RST | `rst \|=> !ub_rd_col_size_valid_out` | Unbounded | P1 | Open |
| UB-A03 | `p_rst_clears_input_valid` | RST | `rst \|=> (!ub_rd_input_valid_out_0 && !ub_rd_input_valid_out_1)` | Unbounded | P1 | Open |
| UB-A04 | `p_rst_clears_weight_valid` | RST | `rst \|=> (!ub_rd_weight_valid_out_0 && !ub_rd_weight_valid_out_1)` | Unbounded | P1 | Open |
| UB-A05 | `p_host_wr_no_collision` | ME | `!(ub_wr_host_valid_in[0] && ub_wr_valid_in[0])` â€” host write and VPU write to same port never simultaneously active | BMC k=8 | P1 | Open |
| UB-A06 | `p_col_size_valid_follows_rd_start` | VP | `ub_rd_start_in \|=> ub_rd_col_size_valid_out` | BMC k=8 | P1 | Open |
| UB-A07 | `p_wr_ptr_increments_on_vpu_write` | DP | `(ub_wr_valid_in[0] && ub_wr_valid_in[1]) \|=> wr_ptr == $past(wr_ptr) + 2` — RTL writes both channels simultaneously and advances by 2 | BMC k=8 | P2 | Open |
| UB-A08 | `p_read_ptrs_bounded` | SD | `rd_input_ptr < UNIFIED_BUFFER_WIDTH` | BMC k=32 | P2 | Open |
| UB-A09 | `p_gradient_done_propagates_to_output` | VP | `grad_descent_done_out (inst0) \|=> ub write-back triggers` | BMC k=8 | P2 | Open |

#### Assumptions

| Assume ID | Description |
|-----------|-------------|
| UB-C01 | `ub_ptr_select` is constrained to the valid pointer range for the current proof run |
| UB-C02 | Host writes and VPU writes are mutually exclusive by assumption (protocol guarantee) |
| UB-C03 | `ub_rd_row_size` and `ub_rd_col_size` are constrained to non-zero values â‰¤ `SYSTOLIC_ARRAY_WIDTH` |

---

## 7. Property Catalog â€” Master Table

> This table is the single source of truth for all formal assertions. Export to Excel/CSV for tracking.

| Assert ID | Module | Name | Category | Priority | SVA Construct | Proof Type | Bound (k) | Waiver | Status |
|-----------|--------|------|----------|----------|---------------|------------|-----------|--------|--------|
| PE-A01 | pe | p_rst_clears_psum | RST | P1 | `rst \|=> pe_psum_out==0` | Unbounded | â€” | None | Open |
| PE-A02 | pe | p_rst_clears_valid | RST | P1 | `rst \|=> !pe_valid_out` | Unbounded | â€” | None | Open |
| PE-A03 | pe | p_rst_clears_switch | RST | P1 | `rst \|=> !pe_switch_out` | Unbounded | â€” | None | Open |
| PE-A04 | pe | p_rst_clears_weight_out | RST | P1 | `rst \|=> pe_weight_out==0` | Unbounded | â€” | None | Open |
| PE-A05 | pe | p_rst_clears_input_out | RST | P1 | `rst \|=> pe_input_out==0` | Unbounded | â€” | None | Open |
| PE-A06 | pe | p_disabled_clears_outputs | RST | P1 | `!pe_enabled \|=> (psum=0 && !valid && !switch && weight=0)` | Unbounded | â€” | None | Open |
| PE-A07 | pe | p_valid_out_registered | VP | P1 | `1'b1 \|=> pe_valid_out==$past(pe_valid_in)` | BMC | 4 | None | Open |
| PE-A08 | pe | p_switch_out_registered | VP | P1 | `1'b1 \|=> pe_switch_out==$past(pe_switch_in)` | BMC | 4 | None | Open |
| PE-A09 | pe | p_weight_out_when_accepting | DP | P1 | `pe_accept_w_in \|=> pe_weight_out==$past(pe_weight_in)` | BMC | 4 | None | Open |
| PE-A10 | pe | p_weight_out_zero_when_idle | DP | P1 | `!pe_accept_w_in \|=> pe_weight_out==0` | BMC | 4 | None | Open |
| PE-A11 | pe | p_input_out_captured_on_valid | DP | P2 | `pe_valid_in \|=> pe_input_out==$past(pe_input_in)` | BMC | 4 | None | Open |
| PE-A12 | pe | p_psum_zero_when_invalid | DP | P1 | `!pe_valid_in \|=> pe_psum_out==0` | BMC | 4 | None | Open |
| PE-A13 | pe | p_valid_out_low_when_in_low | VP | P1 | `!pe_valid_in \|=> !pe_valid_out` | BMC | 4 | None | Open |
| PE-A14 | pe | p_rst_clears_weight_regs | RST | P1 | `(rst\|\|!pe_enabled) \|=> weight_regs==0` | Unbounded | — | None | Open |
| PE-A15 | pe | p_weight_switch | DP | P1 | `pe_switch_in \|=> weight_reg_active==$past(weight_reg_inactive)` | BMC | 4 | None | Open |
| PE-A16 | pe | p_input_out_clear_when_invalid | DP | P1 | `!pe_valid_in \|=> pe_input_out==16'b0` | BMC | 4 | None | Open |
| PE-A17 | pe | p_rst_clears_overflow | RST | P1 | `(rst\|\|!pe_enabled) \|=> !pe_overflow_out` | Unbounded | — | None | Open |
| PE-A18 | pe | p_overflow_is_sticky | FA | P1 | `pe_overflow_out \|=> pe_overflow_out` | BMC | 4 | None | Open |
| PE-A19 | pe | p_mac_zero_input_passthrough_psum | FA | P2 | `(pe_valid_in&&pe_input_in==0) \|=> pe_psum_out==$past(pe_psum_in)` | BMC | 4 | PE-W01 | Open |
| SYS-A01 | systolic | p_rst_clears_valid_out_21 | RST | P1 | `rst \|=> !sys_valid_out_21` | Unbounded | â€” | None | Open |
| SYS-A02 | systolic | p_rst_clears_valid_out_22 | RST | P1 | `rst \|=> !sys_valid_out_22` | Unbounded | â€” | None | Open |
| SYS-A03 | systolic | p_rst_clears_data_out_21 | RST | P1 | `rst \|=> sys_data_out_21==0` | Unbounded | â€” | None | Open |
| SYS-A04 | systolic | p_rst_clears_data_out_22 | RST | P1 | `rst \|=> sys_data_out_22==0` | Unbounded | â€” | None | Open |
| SYS-A05 | systolic | p_valid_21_one_cycle_delay | VP | P1 | `sys_start_2 \|=> sys_valid_out_21` | BMC | 8 | None | Open |
| SYS-A06 | systolic | p_valid_22_three_cycles_after_start1 | VP | P1 | `sys_start_1 \|=> ##2 sys_valid_out_22` | BMC | 8 | None | Open |
| SYS-A07 | systolic | p_no_valid_without_start | VP | P2 | `!sys_start_2 \|=> !sys_valid_out_21` | BMC | 8 | None | Open |
| SYS-A08 | systolic | p_col_size_1_disables_col2 | ME | P1 | `(ub_rd_col_size_valid_in&&col==1) \|=> !sys_valid_out_22` | BMC | 8 | None | Open |
| SYS-A09 | systolic | p_col_size_encodes_as_mask | SD | P2 | `(ub_rd_col_size_valid_in&&col==2) \|=> pe_enabled==2'b11` | BMC | 4 | None | Open |
| SYS-A10 | systolic | p_accept_w_cols_independent | ME | P2 | Weight load on col1 does not affect col2 registers | BMC | 4 | None | Open |
| BC-A01 | bias_child | p_rst_clears_valid | RST | P1 | `rst \|=> !bias_Z_valid_out` | Unbounded | â€” | None | Open |
| BC-A02 | bias_child | p_rst_clears_data | RST | P1 | `rst \|=> bias_z_data_out==0` | Unbounded | â€” | None | Open |
| BC-A03 | bias_child | p_valid_out_mirrors_valid_in | VP | P1 | `1'b1 \|=> bias_Z_valid_out==$past(bias_sys_valid_in)` | BMC | 4 | None | Open |
| BC-A04 | bias_child | p_data_zero_when_invalid | DP | P1 | `!bias_sys_valid_in \|=> bias_z_data_out==0` | BMC | 4 | None | Open |
| BC-A05 | bias_child | p_data_latches_pre_activation | FA | P2 | `bias_sys_valid_in \|=> bias_z_data_out==$past(z_pre_activation)` | BMC | 4 | None | Open |
| LRC-A01 | leaky_relu_child | p_rst_clears_outputs | RST | P1 | `rst \|=> (!lr_valid_out && lr_data_out==0)` | Unbounded | â€” | None | Open |
| LRC-A02 | leaky_relu_child | p_valid_out_mirrors_valid_in | VP | P1 | `1'b1 \|=> lr_valid_out==$past(lr_valid_in)` | BMC | 4 | None | Open |
| LRC-A03 | leaky_relu_child | p_data_zero_when_invalid | DP | P1 | `!lr_valid_in \|=> lr_data_out==0` | BMC | 4 | None | Open |
| LRC-A04 | leaky_relu_child | p_positive_passes_through | FA | P1 | `(lr_valid_in&&!lr_data_in[15]) \|=> lr_data_out==$past(lr_data_in)` | BMC | 4 | None | Open |
| LRC-A05 | leaky_relu_child | p_negative_is_scaled | FA | P1 | `(lr_valid_in&&lr_data_in[15]) \|=> lr_data_out==$past(mul_out)` | BMC | 4 | None | Open |
| LRC-A06 | leaky_relu_child | p_sign_preserved_for_positive | SD | P2 | `(lr_valid_in&&!lr_data_in[15]) \|=> !lr_data_out[15]` | BMC | 4 | None | Open |
| LRC-A07 | leaky_relu_child | p_zero_input_zero_output | FA | P2 | `(lr_valid_in&&lr_data_in==0) \|=> lr_data_out==0` | BMC | 4 | None | Open |
| LRD-A01 | lr_deriv_child | p_rst_clears_outputs | RST | P1 | `rst \|=> (!lr_d_valid_out && lr_d_data_out==0)` | Unbounded | â€” | None | Open |
| LRD-A02 | lr_deriv_child | p_valid_out_plain_register | VP | P1 | `1'b1 \|=> lr_d_valid_out==$past(lr_d_valid_in)` | BMC | 4 | None | Open |
| LRD-A03 | lr_deriv_child | p_data_zero_when_invalid | DP | P1 | `!lr_d_valid_in \|=> lr_d_data_out==0` | BMC | 4 | None | Open |
| LRD-A04 | lr_deriv_child | p_positive_H_passes_gradient | FA | P1 | `(lr_d_valid_in&&!lr_d_H_data_in[15]) \|=> lr_d_data_out==$past(lr_d_data_in)` | BMC | 4 | None | Open |
| LRD-A05 | lr_deriv_child | p_negative_H_scales_gradient | FA | P1 | `(lr_d_valid_in&&lr_d_H_data_in[15]) \|=> lr_d_data_out==$past(mul_out)` | BMC | 4 | None | Open |
| LRD-A06 | lr_deriv_child | p_zero_H_passes_gradient | FA | P2 | `(lr_d_valid_in&&lr_d_H_data_in==0) \|=> lr_d_data_out==$past(lr_d_data_in)` | BMC | 4 | None | Open |
| LC-A01 | loss_child | p_rst_clears_gradient | RST | P1 | `rst \|=> gradient_out==0` | Unbounded | â€” | None | Open |
| LC-A02 | loss_child | p_rst_clears_valid | RST | P1 | `rst \|=> !valid_out` | Unbounded | â€” | None | Open |
| LC-A03 | loss_child | p_valid_out_registered | VP | P1 | `1'b1 \|=> valid_out==$past(valid_in)` | BMC | 4 | None | Open |
| LC-A04 | loss_child | p_data_zero_when_invalid | DP | P1 | `!valid_in \|=> gradient_out==0` | BMC | 4 | None | Open |
| LC-A05 | loss_child | p_gradient_sign_H_gt_Y | FA | P2 | `(valid_in&&H_in>Y_in) \|=> !gradient_out[15]` | BMC | 4 | None | Open |
| LC-A06 | loss_child | p_gradient_sign_H_lt_Y | FA | P2 | `(valid_in&&H_in<Y_in) \|=> gradient_out[15]` | BMC | 4 | None | Open |
| LC-A07 | loss_child | p_gradient_zero_H_eq_Y | FA | P2 | `(valid_in&&H_in==Y_in) \|=> gradient_out==0` | BMC | 4 | None | Open |
| GD-A01 | gradient_descent | p_rst_clears_output | RST | P1 | `rst \|=> value_updated_out==0` | Unbounded | â€” | None | Open |
| GD-A02 | gradient_descent | p_rst_clears_done | RST | P1 | `rst \|=> !grad_descent_done_out` | Unbounded | â€” | None | Open |
| GD-A03 | gradient_descent | p_done_one_cycle_delay | VP | P1 | `1'b1 \|=> done==$past(valid_in)` | BMC | 6 | None | Open |
| GD-A04 | gradient_descent | p_output_holds_when_invalid | DP | P1 | `!valid_in \|=> value_updated_out==$past(value_updated_out)` | BMC | 6 | None | Open |
| GD-A05 | gradient_descent | p_weight_mode_update_formula | FA | P1 | `(valid_in&&mode=weight) \|=> out==$past(old)-$past(mul_out)` | BMC | 6 | None | Open |
| GD-A06 | gradient_descent | p_done_implies_valid_was_set | VP | P1 | `done \|-> $past(valid_in)` | BMC | 6 | None | Open |
| GD-A07 | gradient_descent | p_not_done_implies_valid_clear | VP | P1 | `!done \|-> !$past(valid_in)` | BMC | 6 | None | Open |
| CU-A01 | control_unit | p_sys_switch_bit | SD | P1 | `sys_switch_in===instruction[0]` | Comb | 0 | None | Open |
| CU-A02 | control_unit | p_ub_rd_start_bit | SD | P1 | `ub_rd_start_in===instruction[1]` | Comb | 0 | None | Open |
| CU-A03 | control_unit | p_ub_rd_transpose_bit | SD | P1 | `ub_rd_transpose===instruction[2]` | Comb | 0 | None | Open |
| CU-A04 | control_unit | p_ub_wr_host_valid_1_bit | SD | P1 | `ub_wr_host_valid_in_1===instruction[3]` | Comb | 0 | None | Open |
| CU-A05 | control_unit | p_ub_wr_host_valid_2_bit | SD | P1 | `ub_wr_host_valid_in_2===instruction[4]` | Comb | 0 | None | Open |
| CU-A06 | control_unit | p_ub_rd_col_size_field | SD | P1 | `ub_rd_col_size===instruction[20:5]` | Comb | 0 | None | Open |
| CU-A07 | control_unit | p_ub_rd_row_size_field | SD | P1 | `ub_rd_row_size===instruction[36:21]` | Comb | 0 | None | Open |
| CU-A08 | control_unit | p_ub_rd_addr_field | SD | P1 | `ub_rd_addr_in===instruction[52:37]` | Comb | 0 | None | Open |
| CU-A09 | control_unit | p_ub_ptr_select_field | SD | P1 | `ub_ptr_select===instruction[61:53]` | Comb | 0 | None | Open |
| CU-A10 | control_unit | p_host_data_1_field | SD | P1 | `ub_wr_host_data_in_1===instruction[77:62]` | Comb | 0 | None | Open |
| CU-A11 | control_unit | p_host_data_2_field | SD | P1 | `ub_wr_host_data_in_2===instruction[93:78]` | Comb | 0 | None | Open |
| CU-A12 | control_unit | p_vpu_data_pathway_field | SD | P1 | `vpu_data_pathway===instruction[97:94]` | Comb | 0 | None | Open |
| CU-A13 | control_unit | p_inv_batch_size_field | SD | P1 | `inv_batch_size_times_two_in===instruction[113:98]` | Comb | 0 | None | Open |
| CU-A14 | control_unit | p_vpu_leak_factor_field | SD | P1 | `vpu_leak_factor_in===instruction[129:114]` | Comb | 0 | None | Open |
| CU-A15 | control_unit | p_bit_field_no_overlap | SD | P1 | Full 130-bit field coverage and uniqueness check | Comb | 0 | None | Open |
| VPU-A01 | vpu | p_rst_clears_valid_out | RST | P1 | `rst \|=> (!vpu_valid_out_1&&!vpu_valid_out_2)` | Unbounded | â€” | None | Open |
| VPU-A02 | vpu | p_rst_clears_data_out | RST | P1 | `rst \|=> (data_out_1==0&&data_out_2==0)` | Unbounded | â€” | None | Open |
| VPU-A03 | vpu | p_zero_pathway_reg_valid | VP | P1 | `pathway==0 \|=> valid_out==$past(valid_in)` | BMC | 4 | None | Open |
| VPU-A04 | vpu | p_zero_pathway_reg_data | DP | P1 | `pathway==0 \|=> data_out==$past(data_in)` | BMC | 4 | None | Open |
| VPU-A05 | vpu | p_forward_path_3cy_latency | VP | P1 | `(pathway==1100&&valid_in) \|=> ##2 valid_out` | BMC | 8 | None | Open |
| VPU-A06 | vpu | p_backward_path_2cy_latency | VP | P1 | `(pathway==0001&&valid_in) \|=> ##1 valid_out` | BMC | 6 | None | Open |
| VPU-A07 | vpu | p_transition_path_5cy_latency | VP | P1 | `(pathway==1111&&valid_in) \|=> ##4 valid_out` | BMC | 10 | None | Open |
| VPU-A08 | vpu | p_no_output_without_input_reg | VP | P2 | `(pathway==0&&!valid_in) \|=> !valid_out` | BMC | 4 | None | Open |
| VPU-A09 | vpu | p_dual_column_simultaneous | VP | P2 | `(vpu_valid_in_1 && vpu_valid_in_2) \|=> (vpu_valid_out_1 == vpu_valid_out_2)` — both channels produce equal timing since they share the same pathway configuration | BMC | 4 | None | Open |
| VPU-A10 | vpu | p_last_H_registered_when_loss | DP | P2 | `pathway[1]&&valid_in \|=> last_H_out==$past(last_H_in)` | BMC | 6 | None | Open |
| UB-A01 | unified_buffer | p_rst_clears_wr_ptr | RST | P1 | `rst \|=> wr_ptr==0` | Unbounded | â€” | None | Open |
| UB-A02 | unified_buffer | p_rst_clears_col_size_valid | RST | P1 | `rst \|=> !ub_rd_col_size_valid_out` | Unbounded | â€” | None | Open |
| UB-A03 | unified_buffer | p_rst_clears_input_valid | RST | P1 | `rst \|=> (!ub_rd_input_valid_out_0&&!ub_rd_input_valid_out_1)` | Unbounded | â€” | None | Open |
| UB-A04 | unified_buffer | p_rst_clears_weight_valid | RST | P1 | `rst \|=> (!ub_rd_weight_valid_out_0&&!ub_rd_weight_valid_out_1)` | Unbounded | â€” | None | Open |
| UB-A05 | unified_buffer | p_host_wr_no_collision | ME | P1 | Host write and VPU write never simultaneously active on same port | BMC | 8 | UB-W01 | Open |
| UB-A06 | unified_buffer | p_col_size_valid_follows_rd_start | VP | P1 | `ub_rd_start_in \|=> ub_rd_col_size_valid_out` | BMC | 8 | None | Open |
| UB-A07 | unified_buffer | p_wr_ptr_increments_on_vpu_write | DP | P2 | `(ub_wr_valid_in[0] && ub_wr_valid_in[1]) \|=> wr_ptr==$past(wr_ptr)+2` | BMC | 8 | None | Open |
| UB-A08 | unified_buffer | p_read_ptrs_bounded | SD | P2 | `rd_input_ptr < UNIFIED_BUFFER_WIDTH` | BMC | 32 | None | Open |
| UB-A09 | unified_buffer | p_gradient_done_triggers_writeback | VP | P2 | Gradient done propagates to write-back sequence | BMC | 8 | None | Open |

**Total assertions: 91 (P1: 72, P2: 19)**

---

## 8. Constraint (Assume) Catalog

| Assume ID | Module | Description | Rationale |
|-----------|--------|-------------|-----------|
| PE-C01 | pe | `pe_enabled` is held constant once asserted | Protocol: PE enable set once per configuration |
| PE-C02 | pe | `pe_psum_in == 0` for row-1 PEs | Structural: no input psum to top row |
| SYS-C01 | systolic | `ub_rd_col_size_in âˆˆ {1, 2}` | 2-wide array only; other values are undefined behaviour |
| SYS-C02 | systolic | `sys_start` deasserted â‰¥ 1 cycle between batches | Prevents ambiguous multi-batch valid overlap |
| GD-C01 | gradient_descent | Weight-mode proof: `grad_bias_or_weight` held to 1 | Isolates feedback loop |
| GD-C02 | gradient_descent | Bias-mode proof: batch depth â‰¤ 4 | Bounds state space for accumulation loop |
| VPU-C01 | vpu | `vpu_data_pathway` constrained per proof run | Reduces state explosion; separate runs per pathway |
| VPU-C02 | vpu | `vpu_valid_in_1` held for full pipeline depth | Ensures output stage is exercised |
| UB-C01 | unified_buffer | `ub_ptr_select` constrained to one pointer per run | Each pointer independently verified |
| UB-C02 | unified_buffer | Host and VPU writes are mutually exclusive | Protocol guarantee from higher-level orchestration |
| UB-C03 | unified_buffer | `ub_rd_row_size`, `ub_rd_col_size` â‰  0 and â‰¤ 2 | Hardware parameterisation constraint |

---

## 9. Cover Property Catalog

| Cover ID | Module | Scenario | Reachability | Status |
|----------|--------|----------|--------------|--------|
| PE-COV01 | pe | MAC active: `pe_valid_in && pe_switch_in` (fresh weight compute) | Must reach | Open |
| PE-COV02 | pe | Weight load then switch: `pe_accept_w_in ##1 !pe_accept_w_in ##1 pe_switch_in` | Must reach | Open |
| PE-COV03 | pe | `pe_enabled` deasserted mid-computation | Must reach | Open |
| SYS-COV01 | systolic | 4 consecutive `sys_start` cycles producing 4 output pairs | Must reach | Open |
| SYS-COV02 | systolic | Weight switch during active computation | Must reach | Open |
| SYS-COV03 | systolic | col_size transitions from 2 to 1 | Must reach | Open |
| BC-COV01 | bias_child | Positive input + positive bias: `z_pre_activation > 0` | Must reach | Open |
| BC-COV02 | bias_child | Sign change: negative input + positive bias crosses zero | Must reach | Open |
| BC-COV03 | bias_child | `bias_sys_valid_in` deasserted after 3 cycles of valid data | Must reach | Open |
| LRC-COV01 | leaky_relu_child | Positive input: passthrough path taken | Must reach | Open |
| LRC-COV02 | leaky_relu_child | Negative input: scaled path taken | Must reach | Open |
| LRC-COV03 | leaky_relu_child | Exactly-zero input | Must reach | Open |
| LRC-COV04 | leaky_relu_child | `lr_valid_in` deasserted after a run | Must reach | Open |
| LRD-COV01 | lr_deriv_child | H â‰¥ 0: gradient passes through unscaled | Must reach | Open |
| LRD-COV02 | lr_deriv_child | H < 0: gradient scaled by leak factor | Must reach | Open |
| LRD-COV03 | lr_deriv_child | H = 0 boundary | Must reach | Open |
| LC-COV01 | loss_child | H > Y (positive gradient produced) | Must reach | Open |
| LC-COV02 | loss_child | H < Y (negative gradient produced) | Must reach | Open |
| LC-COV03 | loss_child | H = Y (zero gradient) | Must reach | Open |
| LC-COV04 | loss_child | `valid_in` deasserted mid-stream | Must reach | Open |
| GD-COV01 | gradient_descent | Weight mode: single-cycle update completes | Must reach | Open |
| GD-COV02 | gradient_descent | Bias mode: multi-cycle accumulation (done cascades) | Must reach | Open |
| GD-COV03 | gradient_descent | `grad_descent_valid_in` deasserted after a run | Must reach | Open |
| CU-COV01 | control_unit | `vpu_data_pathway == 4'b1100` (forward pass) | Must reach | Open |
| CU-COV02 | control_unit | `vpu_data_pathway == 4'b1111` (transition) | Must reach | Open |
| CU-COV03 | control_unit | `vpu_data_pathway == 4'b0001` (backward pass) | Must reach | Open |
| CU-COV04 | control_unit | `sys_switch_in == 1` | Must reach | Open |
| CU-COV05 | control_unit | `ub_rd_transpose == 1` | Must reach | Open |
| CU-COV06 | control_unit | Both `ub_wr_host_valid_in_1` and `ub_wr_host_valid_in_2` asserted | Must reach | Open |
| VPU-COV01 | vpu | Forward pathway (`1100`) completes after 3 cycles — both columns | Must reach | Open |
| VPU-COV02 | vpu | Transition pathway (`1111`) completes after 5 cycles — both columns | Must reach | Open |
| VPU-COV03 | vpu | Backward pathway (`0001`) completes after 2 cycles — both columns | Must reach | Open |
| VPU-COV04 | vpu | Zero pathway passes through with 1-cycle output register delay | Must reach | Open |
| VPU-COV05 | vpu | Both `vpu_valid_in_1` and `vpu_valid_in_2` simultaneously asserted | Must reach | Open |
| UB-COV01 | unified_buffer | Full input read burst (row_size = 2, col_size = 2) completes | Must reach | Open |
| UB-COV02 | unified_buffer | Host write followed immediately by VPU read-back | Must reach | Open |
| UB-COV03 | unified_buffer | Gradient descent write-back cycle triggers | Must reach | Open |

**Total cover properties: 37**

---

## 10. Abstraction and Complexity Management

### 10.1 Fixed-Point Library Abstraction

The `fxp_mul` and `fxp_add` modules in `fixedpoint.sv` are deeply combinational with configurable rounding (`ROUND` parameter). For most structural and protocol assertions, these are treated as **black boxes** â€” the output is only constrained by `$past`-based structural checks, not by the exact arithmetic formula. Exact numerical correctness is delegated to cocotb simulation.

Exception: For sign-based assertions (e.g., LRC-A04, LC-A05, LRC-A06), the monotonicity of the fixed-point operators under the Q8.8 representation is sufficient.

### 10.2 Memory Abstraction (Unified Buffer)

The 128 Ã— 16-bit `ub_memory` array creates significant state space for the formal engine. The following abstraction strategy is applied:

- For read/write pointer assertions, only the pointer registers are tracked; memory content is unconstrained.
- For data correctness, a **shadow memory model** (a parallel checker array updated by the same write logic) is used: `shadow_mem[wr_ptr] <= data_in when valid`.
- The formal tool is instructed to **abstract irrelevant pointer ranges** per proof run (one pointer selected via `UB-C01`).

### 10.3 Bound Selection Rationale

| Module | Chosen k | Justification |
|--------|----------|---------------|
| pe | 6 | Covers 1-cycle register depth + weight shadow register (1 cycle) + 4 cycles margin |
| systolic | 8 | Covers 1-cycle valid chain (sys_start_2→valid_out_21) + switch propagation + margin |
| vpu (transition path) | 10 | Covers full 5-stage pipeline (4 stages + output register) + valid propagation + margin |
| unified_buffer | 32 | Covers longest read burst (row_size=2, multiple data types) |
| control_unit | 0 | Purely combinational; no time bound required |

### 10.4 Proof Decomposition Strategy

Rather than attempting full top-level (`tpu`) formal proof (which would be computationally intractable given the UB memory), verification is structured as:

1. **Unit proofs** â€” each module proven independently with appropriate constraints.
2. **Connectivity proof** â€” top-level `tpu` with all sub-modules black-boxed; only port connectivity and `assign` wiring checked.
3. **Integration simulation cross-check** â€” cocotb `test_tpu.py` is run with all asserts enabled to cross-validate the FV results.

---

## 11. Coverage Plan

### 11.1 Formal Coverage Metrics

| Metric | Target | Tool Mechanism |
|--------|--------|----------------|
| Assertion proof rate (P1) | 100 % proven or justified waiver | FV proof run result |
| Assertion proof rate (P2) | 90 % proven | FV proof run result |
| Cover property reachability | 100 % reachable | FV cover goal status |
| Assume consistency | 0 conflicts | Vacuity check on all assume blocks |

### 11.2 Structural Coverage (Post-Simulation)

| Metric | Target | Notes |
|--------|--------|-------|
| Toggle coverage (module IOs) | â‰¥ 90 % | All input/output ports must toggle in sim |
| Condition coverage | â‰¥ 85 % | All branch conditions in `always` blocks |
| FSM state coverage | 100 % | Not applicable â€” no explicit FSMs in this design |
| Line coverage | â‰¥ 95 % | Each RTL line executed at least once |

### 11.3 Functional Coverage Plan

| Cover Point | Module | Description |
|-------------|--------|-------------|
| FCOV-01 | pe | Weight shadow â†’ active switch exercised |
| FCOV-02 | pe | `pe_enabled` toggles during computation |
| FCOV-03 | systolic | Both columns produce simultaneous valid output |
| FCOV-04 | systolic | col_size = 1 and col_size = 2 both exercised |
| FCOV-05 | vpu | All four `vpu_data_pathway` encodings exercised in same run |
| FCOV-06 | gradient_descent | Bias accumulation over â‰¥ 2 cycles |
| FCOV-07 | loss_child | Gradient sign positive and negative both produced |
| FCOV-08 | unified_buffer | Transpose and non-transpose read both exercised |
| FCOV-09 | tpu | Full forward pass: UB load â†’ systolic â†’ VPU â†’ UB writeback |
| FCOV-10 | tpu | Full backward pass: gradient computation â†’ weight update â†’ UB writeback |

---

## 12. Known Gaps and Waivers

### 12.1 Accepted Gaps

| Gap ID | Category | Description | Mitigation |
|--------|----------|-------------|-----------|
| GAP-01 | Numerical accuracy | Exact `fxp_mul` / `fxp_add` rounding depends on `ROUND` parameter â€” SVA cannot express rounding tolerance | cocotb golden-model comparison with `NOASSERT=0` |
| GAP-02 | Memory content correctness | 128-word array content (what is stored at each address) is not fully provable without a shadow model of equal complexity | Shadow model verification + cocotb read-back tests |
| GAP-03 | End-to-end numerical result | Forward + backward pass numerical correctness requires a multi-cycle floating-point reference model | `test_tpu.py` with assertion-enabled run |
| GAP-04 | Bias accumulation over N > 4 cycles | The gradient_descent feedback loop becomes intractable for formal beyond batch depth 4 | Constrained to â‰¤ 4 in FV; larger batch sizes verified via simulation |
| ~~GAP-05~~ | ~~Stale `gradient_out` when `valid_in = 0`~~ | **RESOLVED (v1.1):** RTL (`loss_child.sv`) was corrected — `gradient_out` is now explicitly cleared to 0 in the `else` branch when `valid_in=0`. LC-A04 has been updated to assert this behaviour (`!valid_in \|=> gradient_out==0`). | — |

### 12.2 Waivers

| Waiver ID | Assert ID | Module | Reason | Risk Level | Approved By |
|-----------|-----------|--------|--------|------------|-------------|
| UB-W01 | UB-A05 | unified_buffer | Host/VPU collision is prevented by system-level protocol; not enforced in RTL | Low | â€” || PE-W01 | PE-A13 | pe | Internal wire `mac_out` is not accessible from a bind module under AAC methodology; plan updated to use port-observable zero-input passthrough proxy (`p_mac_zero_input_passthrough_psum`). Full arithmetic correctness is delegated to cocotb simulation (GAP-01). | Low | — |
---

## 13. Glossary

| Term | Definition |
|------|-----------|
| AAC | Assume-Assert-Cover â€” the three types of SVA properties used in formal verification |
| BMC | Bounded Model Checking â€” formal proof up to k clock cycles |
| CEX | Counterexample â€” a trace produced by the formal tool demonstrating a property violation |
| CU | Control Unit |
| DUV | Design Under Verification |
| FV | Formal Verification |
| GD | Gradient Descent |
| LRC | Leaky ReLU Child |
| LRD | Leaky ReLU Derivative Child |
| MAC | Multiply-Accumulate |
| ME | Mutual Exclusion (assertion category) |
| MSE | Mean Squared Error |
| PE | Processing Element |
| Q8.8 | Fixed-point format: 8 integer bits + 8 fractional bits, signed (16-bit total) |
| RST | Reset (assertion category) |
| SD | Structural / Decode (assertion category) |
| SVA | SystemVerilog Assertions |
| UB | Unified Buffer |
| VPU | Vector Processing Unit |
| VP | Valid Protocol (assertion category) |
| DP | Data Path (assertion category) |
| FA | Functional Arithmetic (assertion category) |

---

*End of Document â€” tiny-tpu Formal Verification Plan v1.0*
