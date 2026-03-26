vlib work
vmap work work

# ── Step 1: Compile RTL design files ─────────────────────────
vlog -sv +acc -suppress 2892 -work work \
    /home/vishal/Desktop/tiny-tpu-main/src/fixedpoint.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/pe.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/systolic.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/bias_child.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/bias_parent.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/leaky_relu_child.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/leaky_relu_parent.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/leaky_relu_derivative_child.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/leaky_relu_derivative_parent.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/loss_child.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/loss_parent.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/gradient_descent.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/control_unit.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/vpu.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/unified_buffer.sv \
    /home/vishal/Desktop/tiny-tpu-main/src/tpu.sv

# ── Step 2: Compile SVA assertion modules ────────────────────
vlog -sv +acc -suppress 2892 -work work \
    /home/vishal/Desktop/tiny-tpu-main/sva/pe_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/systolic_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/bias_child_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/leaky_relu_child_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/leaky_relu_derivative_child_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/loss_child_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/gradient_descent_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/control_unit_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/vpu_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/unified_buffer_assertions.sv

# ── Step 3: Compile bind file and testbench ──────────────────
vlog -sv +acc -suppress 2892 -work work \
    /home/vishal/Desktop/tiny-tpu-main/sva/bind_all_assertions.sv \
    /home/vishal/Desktop/tiny-tpu-main/sva/tb_tpu.sv

# ── Step 4: Elaborate with assertions ────────────────────────
vsim -assertdebug work.tb_tpu work.bind_wrapper
