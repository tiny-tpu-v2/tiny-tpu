# =============================================================================
#  compile.do — QuestaSim compile + simulate script for tiny-tpu FV
#
#  Usage (QuestaSim transcript or vsim -do):
#      do compile.do
#
#  Assumes QuestaSim is run from the project root:
#      c:\Users\visha\Desktop\FV\tiny-tpu\
# =============================================================================

# --------------------------------------------------------------------------
# 0. Setup — create and map work library
# --------------------------------------------------------------------------
if {[file exists work]} {
    file delete -force work
}
vlib work
vmap work work

# --------------------------------------------------------------------------
# 1. Compile RTL design files
#    Compile order matters: primitives first, then hierarchy bottom-up.
# --------------------------------------------------------------------------
puts "\n===  Compiling RTL (src/)  ==="
vlog -sv +acc -suppress 2892 -work work \
    src/fixedpoint.sv \
    src/pe.sv \
    src/systolic.sv \
    src/bias_child.sv \
    src/bias_parent.sv \
    src/leaky_relu_child.sv \
    src/leaky_relu_parent.sv \
    src/leaky_relu_derivative_child.sv \
    src/leaky_relu_derivative_parent.sv \
    src/loss_child.sv \
    src/loss_parent.sv \
    src/gradient_descent.sv \
    src/control_unit.sv \
    src/vpu.sv \
    src/unified_buffer.sv \
    src/tpu.sv

# --------------------------------------------------------------------------
# 2. Compile SVA assertion modules (sva/*_assertions.sv)
# --------------------------------------------------------------------------
puts "\n===  Compiling SVA assertion modules (sva/)  ==="
vlog -sv +acc +cover -suppress 2892 -work work \
    sva/pe_assertions.sv \
    sva/systolic_assertions.sv \
    sva/bias_child_assertions.sv \
    sva/leaky_relu_child_assertions.sv \
    sva/leaky_relu_derivative_child_assertions.sv \
    sva/loss_child_assertions.sv \
    sva/gradient_descent_assertions.sv \
    sva/control_unit_assertions.sv \
    sva/vpu_assertions.sv \
    sva/unified_buffer_assertions.sv

# --------------------------------------------------------------------------
# 3. Compile bind wrapper and testbench
# --------------------------------------------------------------------------
puts "\n===  Compiling bind wrapper + testbench  ==="
vlog -sv +acc -suppress 2892 -work work \
    sva/bind_all_assertions.sv \
    sva/tb_tpu.sv

# --------------------------------------------------------------------------
# 4. Simulate
# --------------------------------------------------------------------------
puts "\n===  Starting simulation  ==="
vsim -work work \
     -assertdebug \
     -sva \
     -voptargs="+acc=npra" \
     -coverage \
     -onfinish stop \
     -t 1ns \
     work.tb_tpu work.bind_wrapper

# --------------------------------------------------------------------------
# 5. Waveform setup — log everything for inspection
# --------------------------------------------------------------------------
log -r /*

add wave -divider {Clock / Reset}
add wave /tb_tpu/clk
add wave /tb_tpu/rst

add wave -divider {Host Write Ports}
add wave -radix hex /tb_tpu/ub_wr_host_data_in
add wave           /tb_tpu/ub_wr_host_valid_in

add wave -divider {UB Read Control}
add wave           /tb_tpu/ub_rd_start_in
add wave           /tb_tpu/ub_rd_transpose
add wave -radix unsigned /tb_tpu/ub_ptr_select
add wave -radix unsigned /tb_tpu/ub_rd_addr_in
add wave -radix unsigned /tb_tpu/ub_rd_row_size
add wave -radix unsigned /tb_tpu/ub_rd_col_size

add wave -divider {VPU Control}
add wave -radix binary  /tb_tpu/vpu_data_pathway
add wave               /tb_tpu/sys_switch_in
add wave -radix hex     /tb_tpu/vpu_leak_factor_in
add wave -radix hex     /tb_tpu/inv_batch_size_times_two_in
add wave -radix hex     /tb_tpu/learning_rate_in

add wave -divider {VPU Outputs}
add wave -radix hex /tb_tpu/dut/vpu_data_out_1
add wave -radix hex /tb_tpu/dut/vpu_data_out_2
add wave           /tb_tpu/dut/vpu_valid_out_1
add wave           /tb_tpu/dut/vpu_valid_out_2

add wave -divider {Systolic Valid Outputs}
add wave /tb_tpu/dut/sys_valid_out_21
add wave /tb_tpu/dut/sys_valid_out_22

# --------------------------------------------------------------------------
# 6. Enable assertion reporting on all bound modules
# --------------------------------------------------------------------------
assertion enable -on /tb_tpu/dut

# Uncomment to suppress PASS messages (only show failures):
# assertion fail /tb_tpu/dut

# --------------------------------------------------------------------------
# 7. Run simulation
# --------------------------------------------------------------------------
puts "\n===  Running...  ==="
run -all

# --------------------------------------------------------------------------
# 8. Assertion summary report (includes both assert and cover properties)
# --------------------------------------------------------------------------
puts "\n===  Assertion + Cover Summary  ==="
assertion report /tb_tpu/dut

# --------------------------------------------------------------------------
# 9. Coverage reports
# --------------------------------------------------------------------------
puts "\n===  Assertion Pass/Fail Counts  ==="
coverage report -assert -detail
puts "\n===  Cover Property Hit Counts  ==="
coverage report -directive -detail

# --------------------------------------------------------------------------
# 10. Export proof reports to docs/
# --------------------------------------------------------------------------
puts "\n===  Exporting proof reports to docs/  ==="
coverage report -assert    -detail -file /home/vishal/Desktop/tiny-tpu/docs/fv_coverage_assert.txt
coverage report -directive -detail -file /home/vishal/Desktop/tiny-tpu/docs/fv_coverage_covers.txt
puts "===  Written: docs/fv_coverage_assert.txt  ==="
puts "===  Written: docs/fv_coverage_covers.txt  ==="

# --------------------------------------------------------------------------
# 11. Save waveform (GUI only — harmless in batch mode)
# --------------------------------------------------------------------------
catch {write format wave -window .main_pane.wave.interior.cs.body.pw.wf wave.do}
puts "\n===  Done. Check transcript for assertion failures.  ==="
puts "===  Open saved waveform : File > Open > wave.do      ==="
