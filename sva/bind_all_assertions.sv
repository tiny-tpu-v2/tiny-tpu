// ============================================================
// bind_all_assertions.sv
// Binds all SVA assertion modules to their corresponding RTL modules.
//
// Compile order:
//   1. All RTL files (src/*.sv)
//   2. All SVA files (sva/*_assertions.sv)
//   3. This bind file (sva/bind_all_assertions.sv)
//
// Usage:
//   vlog -sv sva/bind_all_assertions.sv
//   vsim -assertdebug work.tpu work.bind_wrapper
// ============================================================

module bind_wrapper;

// ── PE ──────────────────────────────────────────────────────
bind pe pe_assertions u_pe_assert (.*);

// ── Systolic Array ──────────────────────────────────────────
bind systolic systolic_assertions u_sys_assert (.*);

// ── Bias Child ──────────────────────────────────────────────
bind bias_child bias_child_assertions u_bc_assert (.*);

// ── Leaky ReLU Child ────────────────────────────────────────
bind leaky_relu_child leaky_relu_child_assertions u_lr_assert (.*);

// ── Leaky ReLU Derivative Child ─────────────────────────────
bind leaky_relu_derivative_child leaky_relu_derivative_child_assertions u_lrd_assert (.*);

// ── Loss Child ──────────────────────────────────────────────
bind loss_child loss_child_assertions u_lc_assert (.*);

// ── Gradient Descent ────────────────────────────────────────
bind gradient_descent gradient_descent_assertions u_gd_assert (.*);

// ── Control Unit ────────────────────────────────────────────
// NOTE: control_unit is purely combinational and NOT instantiated inside tpu.
// It is a standalone top-level module.  Uncomment the bind below only when
// simulating a testbench that instantiates control_unit.
// bind control_unit control_unit_assertions u_cu_assert (.*);

// ── VPU ─────────────────────────────────────────────────────
bind vpu vpu_assertions u_vpu_assert (.*);

// ── Unified Buffer ──────────────────────────────────────────
bind unified_buffer unified_buffer_assertions u_ub_assert (.*);

endmodule
