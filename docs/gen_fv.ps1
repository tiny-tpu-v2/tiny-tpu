param([string]$OutputPath = "$PSScriptRoot\tiny_tpu_FV_Plan.xlsx")

function Set-Val($ws,$r,$c,$v){ $ws.Cells.Item($r,$c).Value2=$v }
function RGB2Long($hex){ $r=[Convert]::ToInt32($hex.Substring(0,2),16); $g=[Convert]::ToInt32($hex.Substring(2,2),16); $b=[Convert]::ToInt32($hex.Substring(4,2),16); return $r+$g*256+$b*65536 }
function Fill($rng,$hex){ $rng.Interior.Color=(RGB2Long $hex) }
function FillFont($rng,$hex){ $rng.Font.Color=(RGB2Long $hex) }
function Hdr($ws,$row,$cols,$bgHex){ $r=$ws.Range($ws.Cells.Item($row,1),$ws.Cells.Item($row,$cols)); Fill $r $bgHex; FillFont $r "FFFFFF"; $r.Font.Bold=$true; $r.RowHeight=26; $r.VerticalAlignment=-4108 }
function Border($rng){ foreach($e in 7,8,9,10,11,12){ try{$rng.Borders.Item($e).LineStyle=1;$rng.Borders.Item($e).Weight=2}catch{} } }
function AltRow($ws,$row,$cols,$hex){ Fill $ws.Range($ws.Cells.Item($row,1),$ws.Cells.Item($row,$cols)) $hex }

Write-Host "Starting Excel COM..." -ForegroundColor Cyan
$xl=New-Object -ComObject Excel.Application
$xl.Visible=$false; $xl.DisplayAlerts=$false
$wb=$xl.Workbooks.Add()
while($wb.Sheets.Count -gt 1){ $wb.Sheets.Item($wb.Sheets.Count).Delete() }

# ===== SHEET 1 - COVER =====
Write-Host "Sheet 1: Cover" -ForegroundColor Green
$s=$wb.Sheets.Item(1); $s.Name="Cover"; $s.Tab.Color=(RGB2Long "1F3864")
$t=$s.Range("A1:G1"); $t.Merge(); $t.Value2="TINY-TPU  -  FORMAL VERIFICATION PLAN"
$t.Font.Size=20; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=44
$t=$s.Range("A2:G2"); $t.Merge(); $t.Value2="Document ID: FV-TTPU-001  |  Version: 1.0  |  Status: Released  |  Date: 2026-03-12"
$t.Font.Italic=$true; $t.Font.Size=11; Fill $t "2E75B6"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=22
$t=$s.Range("A4:G4"); $t.Merge(); $t.Value2="Revision History"; Fill $t "2E75B6"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22
$h=@("Version","Date","Author","Description")
for($c=1;$c-le 4;$c++){$s.Cells.Item(5,$c).Value2=$h[$c-1]}
Hdr $s 5 4 "4472C4"
$s.Cells.Item(6,1).Value2="0.1"; $s.Cells.Item(6,2).Value2="2026-03-01"; $s.Cells.Item(6,3).Value2="Verification Team"; $s.Cells.Item(6,4).Value2="Initial draft"
$s.Cells.Item(7,1).Value2="1.0"; $s.Cells.Item(7,2).Value2="2026-03-12"; $s.Cells.Item(7,3).Value2="Verification Team"; $s.Cells.Item(7,4).Value2="Full property catalog, sign-off criteria, coverage plan"
Border $s.Range("A5:D7")
$t=$s.Range("A9:G9"); $t.Merge(); $t.Value2="Verification Objectives"; Fill $t "2E75B6"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22
$h=@("ID","Objective","Success Metric")
for($c=1;$c-le 3;$c++){$s.Cells.Item(10,$c).Value2=$h[$c-1]}
Hdr $s 10 3 "4472C4"
$objs=@(
  @("OBJ-01","Prove all reset properties on every register","Zero unbounded-proof failures for RST category"),
  @("OBJ-02","Prove valid-chain protocol correctness","All VP assertions proven/bounded (k >= pipeline depth)"),
  @("OBJ-03","Prove control-unit instruction decoding is lossless","All CU assertions proven combinationally"),
  @("OBJ-04","Prove systolic timing: output latency = 2 / 3 cycles","SYS-A05 and SYS-A06 proven with k >= 4"),
  @("OBJ-05","Prove VPU pathway latency for all four pathways","VPU-A03 through VPU-A07 proven"),
  @("OBJ-06","Achieve 90%+ toggle coverage on all module IOs","Post-simulation toggle coverage report"),
  @("OBJ-07","All cover properties must be reachable","FV tool confirms all cover goals reached"),
  @("OBJ-08","Zero unresolved assumption conflicts","Assume consistency check passes for all modules")
)
$r=11
foreach($o in $objs){ for($c=1;$c-le 3;$c++){Set-Val $s $r $c $o[$c-1]}; if($r%2-eq 0){AltRow $s $r 3 "D9E1F2"}; $r++ }
Border $s.Range("A10:C$($r-1)")
$s.Columns.Item(1).ColumnWidth=10; $s.Columns.Item(2).ColumnWidth=55; $s.Columns.Item(3).ColumnWidth=55; $s.Columns.Item(4).ColumnWidth=35

# ===== SHEET 2 - DESIGN SUMMARY =====
Write-Host "Sheet 2: Design Summary" -ForegroundColor Green
$s2=$wb.Sheets.Add([System.Reflection.Missing]::Value,$wb.Sheets.Item($wb.Sheets.Count))
$s2.Name="Design Summary"; $s2.Tab.Color=(RGB2Long "2E75B6")
$t=$s2.Range("A1:E1"); $t.Merge(); $t.Value2="Design Under Verification - Summary"; $t.Font.Size=14; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=32
$s2.Cells.Item(2,1).Value2="Attribute"; $s2.Cells.Item(2,2).Value2="Value"
Hdr $s2 2 2 "2E75B6"
$ds=@(
  @("Top module","tpu"),
  @("Language","SystemVerilog IEEE 1800-2017"),
  @("Clock domains","Single clock - clk, positive-edge synchronous"),
  @("Reset","Synchronous active-high (rst)"),
  @("Data format","Q8.8 signed 16-bit fixed-point (2s complement)"),
  @("Systolic array size","2 x 2 (parameterised via SYSTOLIC_ARRAY_WIDTH)"),
  @("Unified Buffer","128 x 16-bit"),
  @("Arithmetic library","fixedpoint.sv - fxp_mul, fxp_add, fxp_addsub"),
  @("Instruction word width","88 bits")
)
$r=3; foreach($d in $ds){ $s2.Cells.Item($r,1).Value2=$d[0]; $s2.Cells.Item($r,2).Value2=$d[1]; if($r%2-eq 1){AltRow $s2 $r 2 "D9E1F2"}; $r++ }
Border $s2.Range("A2:B$($r-1)")
$r++
$t=$s2.Range("A$r`:D$r"); $t.Merge(); $t.Value2="VPU Data Pathways"; Fill $t "2E75B6"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22; $r++
$h=@("vpu_data_pathway","Name","Stages Active","Pipeline Latency")
for($c=1;$c-le 4;$c++){$s2.Cells.Item($r,$c).Value2=$h[$c-1]}
Hdr $s2 $r 4 "4472C4"; $fr=$r; $r++
$paths=@(
  @("4b0000","Passthrough","None","0 cycles (combinational)"),
  @("4b1100","Forward pass","Bias then LeakyReLU","2 cycles"),
  @("4b1111","Transition","Bias then LeakyReLU then Loss then LRDerivative","4 cycles"),
  @("4b0001","Backward pass","LRDerivative only","1 cycle")
)
foreach($p in $paths){ for($c=1;$c-le 4;$c++){$s2.Cells.Item($r,$c).Value2=$p[$c-1]}; if(($r-$fr)%2-eq 1){AltRow $s2 $r 4 "D9E1F2"}; $r++ }
Border $s2.Range("A$fr`:D$($r-1)"); $r++
$t=$s2.Range("A$r`:E$r"); $t.Merge(); $t.Value2="Instruction Word Bit-Field Map (88-bit)"; Fill $t "2E75B6"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22; $r++
$h=@("Bits","Width","Signal","Description")
for($c=1;$c-le 4;$c++){$s2.Cells.Item($r,$c).Value2=$h[$c-1]}
Hdr $s2 $r 4 "4472C4"; $fi=$r; $r++
$imap=@(
  @("[0]","1","sys_switch_in","Trigger systolic weight switch"),
  @("[1]","1","ub_rd_start_in","Start UB read sequence"),
  @("[2]","1","ub_rd_transpose","Transpose matrix on UB read"),
  @("[3]","1","ub_wr_host_valid_in_1","Host write valid port 1"),
  @("[4]","1","ub_wr_host_valid_in_2","Host write valid port 2"),
  @("[6:5]","2","ub_rd_col_size","Number of active systolic columns"),
  @("[14:7]","8","ub_rd_row_size","Number of matrix rows to read"),
  @("[16:15]","2","ub_rd_addr_in","UB read address"),
  @("[19:17]","3","ub_ptr_sel","UB pointer selector"),
  @("[35:20]","16","ub_wr_host_data_in_1","Host write data port 1"),
  @("[51:36]","16","ub_wr_host_data_in_2","Host write data port 2"),
  @("[55:52]","4","vpu_data_pathway","VPU pipeline routing"),
  @("[71:56]","16","inv_batch_size_times_two_in","2/N constant for MSE"),
  @("[87:72]","16","vpu_leak_factor_in","Leaky ReLU alpha factor")
)
foreach($im in $imap){ for($c=1;$c-le 4;$c++){$s2.Cells.Item($r,$c).Value2=$im[$c-1]}; if(($r-$fi)%2-eq 1){AltRow $s2 $r 4 "D9E1F2"}; $r++ }
Border $s2.Range("A$fi`:D$($r-1)")
$s2.Columns.Item(1).ColumnWidth=10; $s2.Columns.Item(2).ColumnWidth=8; $s2.Columns.Item(3).ColumnWidth=32; $s2.Columns.Item(4).ColumnWidth=50

# ===== SHEET 3 - ASSERTIONS =====
Write-Host "Sheet 3: Master Assertions" -ForegroundColor Green
$s3=$wb.Sheets.Add([System.Reflection.Missing]::Value,$wb.Sheets.Item($wb.Sheets.Count))
$s3.Name="Assertions"; $s3.Tab.Color=(RGB2Long "375623")
$t=$s3.Range("A1:J1"); $t.Merge(); $t.Value2="Master Assertion Catalog - tiny-tpu FV Plan v1.0"; $t.Font.Size=14; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=32
$h=@("Assert ID","Module","Property Name","Category","Priority","SVA Construct","Proof Type","Bound k","Waiver","Status")
for($c=1;$c-le 10;$c++){$s3.Cells.Item(2,$c).Value2=$h[$c-1]}
Hdr $s3 2 10 "375623"
$catClr=@{ "RST"="E2EFDA"; "VP"="D9E1F2"; "DP"="FCE4D6"; "FA"="EAD9F7"; "SD"="F2F2F2"; "ME"="FFF2CC"; "LV"="CCFFCC" }
$asn=@(
  @("PE-A01","pe","p_rst_clears_psum","RST","P1","rst |=> pe_psum_out==0","Unbounded","N/A","None","Open"),
  @("PE-A02","pe","p_rst_clears_valid","RST","P1","rst |=> !pe_valid_out","Unbounded","N/A","None","Open"),
  @("PE-A03","pe","p_rst_clears_switch","RST","P1","rst |=> !pe_switch_out","Unbounded","N/A","None","Open"),
  @("PE-A04","pe","p_rst_clears_weight_out","RST","P1","rst |=> pe_weight_out==0","Unbounded","N/A","None","Open"),
  @("PE-A05","pe","p_rst_clears_input_out","RST","P1","rst |=> pe_input_out==0","Unbounded","N/A","None","Open"),
  @("PE-A06","pe","p_disabled_clears_outputs","RST","P1","!pe_enabled |=> (psum=0 and !valid and weight=0)","Unbounded","N/A","None","Open"),
  @("PE-A07","pe","p_valid_out_registered","VP","P1","1b1 |=> pe_valid_out==past(pe_valid_in)","BMC","4","None","Open"),
  @("PE-A08","pe","p_switch_out_registered","VP","P1","1b1 |=> pe_switch_out==past(pe_switch_in)","BMC","4","None","Open"),
  @("PE-A09","pe","p_weight_out_when_accepting","DP","P1","pe_accept_w_in |=> pe_weight_out==past(pe_weight_in)","BMC","4","None","Open"),
  @("PE-A10","pe","p_weight_out_zero_when_idle","DP","P1","!pe_accept_w_in |=> pe_weight_out==0","BMC","4","None","Open"),
  @("PE-A11","pe","p_input_out_captured_on_valid","DP","P2","pe_valid_in |=> pe_input_out==past(pe_input_in)","BMC","4","None","Open"),
  @("PE-A12","pe","p_psum_zero_when_invalid","DP","P1","!pe_valid_in |=> pe_psum_out==0","BMC","4","None","Open"),
  @("PE-A13","pe","p_mac_result_registered","FA","P2","pe_valid_in |=> pe_psum_out==past(mac_out)","BMC","4","None","Open"),
  @("PE-A14a","pe","p_rst_clears_weight_reg_active","RST","P1","(rst or !enabled) |=> weight_reg_active==0","Unbounded","N/A","None","Open"),
  @("PE-A14b","pe","p_rst_clears_weight_reg_inactive","RST","P1","(rst or !enabled) |=> weight_reg_inactive==0","Unbounded","N/A","None","Open"),
  @("SYS-A01","systolic","p_rst_clears_valid_out_21","RST","P1","rst |=> !sys_valid_out_21","Unbounded","N/A","None","Open"),
  @("SYS-A02","systolic","p_rst_clears_valid_out_22","RST","P1","rst |=> !sys_valid_out_22","Unbounded","N/A","None","Open"),
  @("SYS-A03","systolic","p_rst_clears_data_out_21","RST","P1","rst |=> sys_data_out_21==0","Unbounded","N/A","None","Open"),
  @("SYS-A04","systolic","p_rst_clears_data_out_22","RST","P1","rst |=> sys_data_out_22==0","Unbounded","N/A","None","Open"),
  @("SYS-A05","systolic","p_valid_21_two_cycle_delay","VP","P1","sys_start |=> ##1 sys_valid_out_21","BMC","8","None","Open"),
  @("SYS-A06","systolic","p_valid_22_one_cycle_after_21","VP","P1","sys_valid_out_21 |=> sys_valid_out_22","BMC","8","None","Open"),
  @("SYS-A07","systolic","p_no_valid_without_start","VP","P2","!sys_start |=> ##[0:1] !sys_valid_out_21","BMC","8","None","Open"),
  @("SYS-A08","systolic","p_col_size_1_disables_col2","ME","P1","(col_size_valid and col==1) |=> !sys_valid_out_22","BMC","8","None","Open"),
  @("SYS-A09","systolic","p_col_size_encodes_as_mask","SD","P2","(col_size_valid and col==2) |=> pe_enabled==2b11","BMC","4","None","Open"),
  @("SYS-A10","systolic","p_rst_clears_pe_enabled","RST","P1","rst |=> pe_enabled==2b00","Unbounded","N/A","None","Open"),
  @("SYS-A11","systolic","p_pe_enabled_mask_col_size_1","SD","P1","(col_size_valid and col==1) |=> pe_enabled==2b01","BMC","4","None","Open"),
  @("SYS-A12","systolic","p_pe_enabled_mask_col_size_2","SD","P1","(col_size_valid and col==2) |=> pe_enabled==2b11","BMC","4","None","Open"),
  @("BC-A01","bias_child","p_rst_clears_valid","RST","P1","rst |=> !bias_Z_valid_out","Unbounded","N/A","None","Open"),
  @("BC-A02","bias_child","p_rst_clears_data","RST","P1","rst |=> bias_z_data_out==0","Unbounded","N/A","None","Open"),
  @("BC-A03","bias_child","p_valid_out_mirrors_valid_in","VP","P1","1b1 |=> bias_Z_valid_out==past(bias_sys_valid_in)","BMC","4","None","Open"),
  @("BC-A04","bias_child","p_data_zero_when_invalid","DP","P1","!bias_sys_valid_in |=> bias_z_data_out==0","BMC","4","None","Open"),
  @("BC-A05","bias_child","p_data_latches_pre_activation","FA","P2","bias_sys_valid_in |=> bias_z_data_out==past(z_pre_activation)","BMC","4","None","Open"),
  @("LRC-A01","leaky_relu_child","p_rst_clears_outputs","RST","P1","rst |=> (!lr_valid_out and lr_data_out==0)","Unbounded","N/A","None","Open"),
  @("LRC-A02","leaky_relu_child","p_valid_out_mirrors_valid_in","VP","P1","1b1 |=> lr_valid_out==past(lr_valid_in)","BMC","4","None","Open"),
  @("LRC-A03","leaky_relu_child","p_data_zero_when_invalid","DP","P1","!lr_valid_in |=> lr_data_out==0","BMC","4","None","Open"),
  @("LRC-A04","leaky_relu_child","p_positive_passes_through","FA","P1","(lr_valid_in and !lr_data_in[15]) |=> lr_data_out==past(lr_data_in)","BMC","4","None","Open"),
  @("LRC-A05","leaky_relu_child","p_negative_is_scaled","FA","P1","(lr_valid_in and lr_data_in[15]) |=> lr_data_out==past(mul_out)","BMC","4","None","Open"),
  @("LRC-A06","leaky_relu_child","p_sign_preserved_for_positive","SD","P2","(lr_valid_in and !lr_data_in[15]) |=> !lr_data_out[15]","BMC","4","None","Open"),
  @("LRC-A07","leaky_relu_child","p_zero_input_zero_output","FA","P2","(lr_valid_in and lr_data_in==0) |=> lr_data_out==0","BMC","4","None","Open"),
  @("LRD-A01","lr_deriv_child","p_rst_clears_outputs","RST","P1","rst |=> (!lr_d_valid_out and lr_d_data_out==0)","Unbounded","N/A","None","Open"),
  @("LRD-A02","lr_deriv_child","p_valid_out_plain_register","VP","P1","1b1 |=> lr_d_valid_out==past(lr_d_valid_in)","BMC","4","None","Open"),
  @("LRD-A03","lr_deriv_child","p_data_zero_when_invalid","DP","P1","!lr_d_valid_in |=> lr_d_data_out==0","BMC","4","None","Open"),
  @("LRD-A04","lr_deriv_child","p_positive_H_passes_gradient","FA","P1","(lr_d_valid_in and !lr_d_H_data_in[15]) |=> lr_d_data_out==past(lr_d_data_in)","BMC","4","None","Open"),
  @("LRD-A05","lr_deriv_child","p_negative_H_scales_gradient","FA","P1","(lr_d_valid_in and lr_d_H_data_in[15]) |=> lr_d_data_out==past(mul_out)","BMC","4","None","Open"),
  @("LRD-A06","lr_deriv_child","p_zero_H_passes_gradient","FA","P2","(lr_d_valid_in and lr_d_H_data_in==0) |=> lr_d_data_out==past(lr_d_data_in)","BMC","4","None","Open"),
  @("LC-A01","loss_child","p_rst_clears_gradient","RST","P1","rst |=> gradient_out==0","Unbounded","N/A","None","Open"),
  @("LC-A02","loss_child","p_rst_clears_valid","RST","P1","rst |=> !valid_out","Unbounded","N/A","None","Open"),
  @("LC-A03","loss_child","p_valid_out_registered","VP","P1","1b1 |=> valid_out==past(valid_in)","BMC","4","None","Open"),
  @("LC-A04","loss_child","p_gradient_always_registered","DP","P1","1b1 |=> gradient_out==past(final_gradient)","BMC","4","None","Open"),
  @("LC-A05","loss_child","p_gradient_sign_H_gt_Y","FA","P2","(valid_in and H_in>Y_in) |=> !gradient_out[15]","BMC","4","None","Open"),
  @("LC-A06","loss_child","p_gradient_sign_H_lt_Y","FA","P2","(valid_in and H_in<Y_in) |=> gradient_out[15]","BMC","4","None","Open"),
  @("LC-A07","loss_child","p_gradient_zero_H_eq_Y","FA","P2","(valid_in and H_in==Y_in) |=> gradient_out==0","BMC","4","None","Open"),
  @("GD-A01","gradient_descent","p_rst_clears_output","RST","P1","rst |=> value_updated_out==0","Unbounded","N/A","None","Open"),
  @("GD-A02","gradient_descent","p_rst_clears_done","RST","P1","rst |=> !grad_descent_done_out","Unbounded","N/A","None","Open"),
  @("GD-A03","gradient_descent","p_done_one_cycle_delay","VP","P1","1b1 |=> done==past(valid_in)","BMC","6","None","Open"),
  @("GD-A04","gradient_descent","p_output_zero_when_invalid","DP","P1","!grad_descent_valid_in |=> value_updated_out==0","BMC","6","None","Open"),
  @("GD-A05","gradient_descent","p_weight_mode_update_formula","FA","P1","(valid_in and mode=weight) |=> out==past(old)-past(mul_out)","BMC","6","None","Open"),
  @("GD-A06","gradient_descent","p_done_implies_valid_was_set","VP","P1","done |-> past(valid_in)","BMC","6","None","Open"),
  @("GD-A07","gradient_descent","p_not_done_implies_valid_clear","VP","P1","!done |-> !past(valid_in)","BMC","6","None","Open"),
  @("CU-A01","control_unit","p_sys_switch_bit","SD","P1","sys_switch_in === instruction[0]","Comb","0","None","Open"),
  @("CU-A02","control_unit","p_ub_rd_start_bit","SD","P1","ub_rd_start_in === instruction[1]","Comb","0","None","Open"),
  @("CU-A03","control_unit","p_ub_rd_transpose_bit","SD","P1","ub_rd_transpose === instruction[2]","Comb","0","None","Open"),
  @("CU-A04","control_unit","p_ub_wr_host_valid_1_bit","SD","P1","ub_wr_host_valid_in_1 === instruction[3]","Comb","0","None","Open"),
  @("CU-A05","control_unit","p_ub_wr_host_valid_2_bit","SD","P1","ub_wr_host_valid_in_2 === instruction[4]","Comb","0","None","Open"),
  @("CU-A06","control_unit","p_ub_rd_col_size_field","SD","P1","ub_rd_col_size === instruction[6:5]","Comb","0","None","Open"),
  @("CU-A07","control_unit","p_ub_rd_row_size_field","SD","P1","ub_rd_row_size === instruction[14:7]","Comb","0","None","Open"),
  @("CU-A08","control_unit","p_ub_rd_addr_field","SD","P1","ub_rd_addr_in === instruction[16:15]","Comb","0","None","Open"),
  @("CU-A09","control_unit","p_ub_ptr_sel_field","SD","P1","ub_ptr_sel === instruction[19:17]","Comb","0","None","Open"),
  @("CU-A10","control_unit","p_host_data_1_field","SD","P1","ub_wr_host_data_in_1 === instruction[35:20]","Comb","0","None","Open"),
  @("CU-A11","control_unit","p_host_data_2_field","SD","P1","ub_wr_host_data_in_2 === instruction[51:36]","Comb","0","None","Open"),
  @("CU-A12","control_unit","p_vpu_data_pathway_field","SD","P1","vpu_data_pathway === instruction[55:52]","Comb","0","None","Open"),
  @("CU-A13","control_unit","p_inv_batch_size_field","SD","P1","inv_batch_size_times_two_in === instruction[71:56]","Comb","0","None","Open"),
  @("CU-A14","control_unit","p_vpu_leak_factor_field","SD","P1","vpu_leak_factor_in === instruction[87:72]","Comb","0","None","Open"),
  @("CU-A15","control_unit","p_bit_field_no_overlap","SD","P1","Full 88-bit field coverage and uniqueness check","Comb","0","None","Open"),
  @("VPU-A01","vpu","p_rst_clears_valid_out","RST","P1","rst |=> (!vpu_valid_out_1 and !vpu_valid_out_2)","Unbounded","N/A","None","Open"),
  @("VPU-A02","vpu","p_rst_clears_data_out","RST","P1","rst |=> (data_out_1==0 and data_out_2==0)","Unbounded","N/A","None","Open"),
  @("VPU-A03","vpu","p_zero_pathway_comb_valid","VP","P1","pathway==0 |-> valid_out==valid_in","Comb","0","None","Open"),
  @("VPU-A04","vpu","p_zero_pathway_comb_data","DP","P1","pathway==0 |-> data_out==data_in","Comb","0","None","Open"),
  @("VPU-A05","vpu","p_forward_path_2cy_latency","VP","P1","(pathway==1100 and valid_in) |=> ##1 valid_out","BMC","8","None","Open"),
  @("VPU-A06","vpu","p_backward_path_1cy_latency","VP","P1","(pathway==0001 and valid_in) |=> valid_out","BMC","6","None","Open"),
  @("VPU-A07","vpu","p_transition_path_4cy_latency","VP","P1","(pathway==1111 and valid_in) |=> ##3 valid_out","BMC","10","None","Open"),
  @("VPU-A08","vpu","p_no_output_without_input_comb","VP","P2","(pathway==0 and !valid_in) |-> !valid_out","Comb","0","None","Open"),
  @("VPU-A09","vpu","p_dual_column_simultaneous","VP","P2","Both columns active simultaneously produce outputs","Comb","0","None","Open"),
  @("VPU-A10","vpu","p_last_H_registered_when_loss","DP","P2","pathway[1] and valid_in |=> last_H_out==past(last_H_in)","BMC","6","None","Open"),
  @("VPU-A11","vpu","p_rst_clears_last_H_cache","RST","P1","rst |=> (last_H_1==0 and last_H_2==0)","Unbounded","N/A","None","Open"),
  @("VPU-A12","vpu","p_last_H_clears_when_loss_inactive","DP","P1","!pathway[1] |=> last_H==0","BMC","6","None","Open"),
  @("VPU-A13","vpu","p_last_H_registers_when_loss_active","LV","P2","pathway[1] and valid_in |=> last_H!=0","BMC","6","None","Open"),
  @("UB-A01","unified_buffer","p_rst_clears_wr_ptr","RST","P1","rst |=> wr_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A02","unified_buffer","p_rst_clears_col_size_valid","RST","P1","rst |=> !ub_rd_col_size_valid_out","Unbounded","N/A","None","Open"),
  @("UB-A03","unified_buffer","p_rst_clears_input_valid","RST","P1","rst |=> (!ub_rd_input_valid_out_0 and !ub_rd_input_valid_out_1)","Unbounded","N/A","None","Open"),
  @("UB-A04","unified_buffer","p_rst_clears_weight_valid","RST","P1","rst |=> (!ub_rd_weight_valid_out_0 and !ub_rd_weight_valid_out_1)","Unbounded","N/A","None","Open"),
  @("UB-A05","unified_buffer","p_col_size_valid_comb_decode","SD","P1","col_size_valid == (ub_rd_start_in and ptr_select==1)","BMC","8","None","Open"),
  @("UB-A06","unified_buffer","p_wr_ptr_increments_on_vpu_write","DP","P2","ub_wr_valid_in[0]+[1] |=> wr_ptr==past(wr_ptr)+2","BMC","8","None","Open"),
  @("UB-A07a","unified_buffer","p_rd_input_ptr_in_range","SD","P2","rd_input_ptr < UNIFIED_BUFFER_WIDTH","BMC","32","None","Open"),
  @("UB-A07b","unified_buffer","p_rd_weight_ptr_in_range","SD","P2","rd_weight_ptr < UNIFIED_BUFFER_WIDTH","BMC","32","None","Open"),
  @("UB-A07c","unified_buffer","p_wr_ptr_in_range","SD","P2","wr_ptr < UNIFIED_BUFFER_WIDTH","BMC","32","None","Open"),
  @("UB-A08a","unified_buffer","p_no_vpu_host_write_collision_ch0","ME","P1","!(ub_wr_valid_in[0] and ub_wr_host_valid_in[0])","BMC","8","UB-W01","Open"),
  @("UB-A08b","unified_buffer","p_no_vpu_host_write_collision_ch1","ME","P1","!(ub_wr_valid_in[1] and ub_wr_host_valid_in[1])","BMC","8","UB-W01","Open"),
  @("UB-A09a","unified_buffer","p_col_size_out_correct_non_transpose","SD","P1","(col_size_valid and !transpose) |-> col_size_out==ub_rd_col_size","Comb","0","None","Open"),
  @("UB-A09b","unified_buffer","p_col_size_out_correct_transpose","SD","P1","(col_size_valid and transpose) |-> col_size_out==ub_rd_row_size","Comb","0","None","Open"),
  @("UB-A10","unified_buffer","p_col_size_out_zero_when_not_valid","SD","P1","!col_size_valid |-> col_size_out==0","Comb","0","None","Open"),
  @("UB-A11","unified_buffer","p_rst_clears_rd_bias_ptr","RST","P1","rst |=> rd_bias_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A12","unified_buffer","p_rst_clears_rd_Y_ptr","RST","P1","rst |=> rd_Y_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A13","unified_buffer","p_rst_clears_rd_H_ptr","RST","P1","rst |=> rd_H_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A14","unified_buffer","p_rst_clears_rd_grad_bias_ptr","RST","P1","rst |=> rd_grad_bias_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A15","unified_buffer","p_rst_clears_rd_grad_weight_ptr","RST","P1","rst |=> rd_grad_weight_ptr==0","Unbounded","N/A","None","Open"),
  @("UB-A16","unified_buffer","p_rst_clears_grad_descent_ptr","RST","P1","rst |=> grad_descent_ptr==0","Unbounded","N/A","None","Open")
)
$r=3
foreach($a in $asn){
  for($c=1;$c-le 10;$c++){Set-Val $s3 $r $c $a[$c-1]}
  $cat=$a[3]
  if($catClr.ContainsKey($cat)){ AltRow $s3 $r 10 $catClr[$cat] }
  elseif($r%2-eq 0){ AltRow $s3 $r 10 "F2F2F2" }
  $r++
}
Border $s3.Range("A2:J$($r-1)")
$s3.Cells.Item(1,$s3.Columns.Count).Select() | Out-Null
$s3.Range("A3").Select() | Out-Null
$s3.Application.ActiveWindow.SplitRow=2; $s3.Application.ActiveWindow.FreezePanes=$true
$s3.Columns.Item(1).ColumnWidth=11; $s3.Columns.Item(2).ColumnWidth=18; $s3.Columns.Item(3).ColumnWidth=40
$s3.Columns.Item(4).ColumnWidth=8; $s3.Columns.Item(5).ColumnWidth=8; $s3.Columns.Item(6).ColumnWidth=52
$s3.Columns.Item(7).ColumnWidth=12; $s3.Columns.Item(8).ColumnWidth=8; $s3.Columns.Item(9).ColumnWidth=9; $s3.Columns.Item(10).ColumnWidth=8
$leg=$s3.Range("A$r`:J$r"); $leg.Merge()
$leg.Value2="Category Legend:  RST=Reset  VP=Valid Protocol  DP=Data Path  FA=Functional Arithmetic  SD=Structural/Decode  ME=Mutual Exclusion  LV=Liveness"
$leg.Font.Italic=$true; $leg.Font.Size=9; Fill $leg "FFFFF0"

# ===== SHEET 4 - ASSUMES =====
Write-Host "Sheet 4: Assumes" -ForegroundColor Green
$s4=$wb.Sheets.Add([System.Reflection.Missing]::Value,$wb.Sheets.Item($wb.Sheets.Count))
$s4.Name="Assumes"; $s4.Tab.Color=(RGB2Long "833C00")
$t=$s4.Range("A1:D1"); $t.Merge(); $t.Value2="Constraint (Assume) Catalog - tiny-tpu FV Plan v1.0"; $t.Font.Size=14; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=32
$h=@("Assume ID","Module","Description","Rationale")
for($c=1;$c-le 4;$c++){$s4.Cells.Item(2,$c).Value2=$h[$c-1]}
Hdr $s4 2 4 "833C00"
$asm=@(
  @("PE-ASM-01","pe","pe_enabled held constant once asserted - no mid-computation disable","PE enable is a configuration not a control signal"),
  @("PE-ASM-02","pe","pe_psum_in == 0 for row-1 PEs (top cells pe11 and pe12)","Structural: no input psum to top-row PEs"),
  @("SYS-ASM-01","systolic","ub_rd_col_size_in constrained to 1 or 2","2-wide array only - other values are undefined behaviour"),
  @("SYS-ASM-02","systolic","sys_start deasserted at least 1 cycle between consecutive batches","Prevent overlapping valid chains"),
  @("SYS-ASM-03","systolic","sys_accept_w_1 and sys_accept_w_2 never simultaneously asserted","Each column is loaded independently"),
  @("GD-ASM-01","gradient_descent","Weight-mode proof: grad_bias_or_weight held to 1","Isolates feedback loop in weight mode"),
  @("GD-ASM-02","gradient_descent","Bias-mode proof: batch depth <= 4","Bounds state space for accumulation feedback"),
  @("GD-ASM-04","gradient_descent","Learning rate (lr_in) is always positive (bit[15]==0 and != 0)","Prevents negative step direction which is architecturally illegal"),
  @("VPU-ASM-01","vpu","vpu_data_pathway constrained to one of 0000/1100/1111/0001 per run","Any other encoding is undefined behaviour"),
  @("VPU-ASM-02","vpu","Pathway register is stable during an in-flight burst","No mid-burst pathway change allowed"),
  @("VPU-ASM-04","vpu","Bias scalars are zero when bias stage (pathway[3]) is inactive","Prevents spurious bias addition through disabled path"),
  @("UB-ASM-01","unified_buffer","ub_ptr_select < 8 (valid pointer range 0 to 7)","Pointer values 0-7 are defined - others are undefined"),
  @("UB-ASM-02a","unified_buffer","NOT (ub_wr_valid_in[0] AND ub_wr_host_valid_in[0]) - channel 0 mutex","Protocol: host and VPU never write same port simultaneously"),
  @("UB-ASM-02b","unified_buffer","NOT (ub_wr_valid_in[1] AND ub_wr_host_valid_in[1]) - channel 1 mutex","Same as above for channel 1"),
  @("UB-ASM-03a","unified_buffer","ub_rd_row_size in [1, SYSTOLIC_ARRAY_WIDTH] when rd_start_in asserted","Non-zero bounded row size"),
  @("UB-ASM-03b","unified_buffer","ub_rd_col_size in [1, SYSTOLIC_ARRAY_WIDTH] when rd_start_in asserted","Non-zero bounded col size"),
  @("UB-ASM-04","unified_buffer","learning_rate_in > 0 (positive non-zero)","Architecturally illegal to have zero or negative LR"),
  @("UB-ASM-05","unified_buffer","ub_rd_start_in == 0 on first cycle after rst deasserts","Required for UB-A02: col_size_valid is combinational")
)
$r=3; foreach($a in $asm){ for($c=1;$c-le 4;$c++){Set-Val $s4 $r $c $a[$c-1]}; if($r%2-eq 0){AltRow $s4 $r 4 "FCE4D6"}; $r++ }
Border $s4.Range("A2:D$($r-1)")
$s4.Columns.Item(1).ColumnWidth=14; $s4.Columns.Item(2).ColumnWidth=18; $s4.Columns.Item(3).ColumnWidth=65; $s4.Columns.Item(4).ColumnWidth=52

# ===== SHEET 5 - COVER PROPERTIES =====
Write-Host "Sheet 5: Cover Properties" -ForegroundColor Green
$s5=$wb.Sheets.Add([System.Reflection.Missing]::Value,$wb.Sheets.Item($wb.Sheets.Count))
$s5.Name="Cover Properties"; $s5.Tab.Color=(RGB2Long "7030A0")
$t=$s5.Range("A1:E1"); $t.Merge(); $t.Value2="Cover Property Catalog - tiny-tpu FV Plan v1.0"; $t.Font.Size=14; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=32
$h=@("Cover ID","Module","Scenario","Reachability","Status")
for($c=1;$c-le 5;$c++){$s5.Cells.Item(2,$c).Value2=$h[$c-1]}
Hdr $s5 2 5 "7030A0"
$cov=@(
  @("PE-COV01","pe","MAC active: pe_valid_in and pe_switch_in (fresh weight compute)","Must reach","Open"),
  @("PE-COV02","pe","Weight load then switch: pe_accept_w_in ##1 !pe_accept_w_in ##1 pe_switch_in","Must reach","Open"),
  @("PE-COV03","pe","pe_enabled deasserted mid-computation","Must reach","Open"),
  @("SYS-COV01","systolic","4 consecutive sys_start cycles producing 4 output pairs","Must reach","Open"),
  @("SYS-COV02","systolic","Weight switch during active computation","Must reach","Open"),
  @("SYS-COV03","systolic","col_size transitions from 2 to 1","Must reach","Open"),
  @("SYS-COV04","systolic","Column 1 weight load only (accept_w_1 and !accept_w_2)","Must reach","Open"),
  @("SYS-COV05","systolic","Column 2 weight load only (!accept_w_1 and accept_w_2)","Must reach","Open"),
  @("BC-COV01","bias_child","Positive input plus positive bias: z_pre_activation > 0","Must reach","Open"),
  @("BC-COV02","bias_child","Sign change: negative input plus positive bias crosses zero","Must reach","Open"),
  @("BC-COV03","bias_child","bias_sys_valid_in deasserted after 3 cycles of valid data","Must reach","Open"),
  @("LRC-COV01","leaky_relu_child","Positive input: passthrough path taken","Must reach","Open"),
  @("LRC-COV02","leaky_relu_child","Negative input: scaled path taken","Must reach","Open"),
  @("LRC-COV03","leaky_relu_child","Exactly-zero input exercised","Must reach","Open"),
  @("LRC-COV04","leaky_relu_child","lr_valid_in deasserted after a run","Must reach","Open"),
  @("LRD-COV01","lr_deriv_child","H >= 0: gradient passes through unscaled","Must reach","Open"),
  @("LRD-COV02","lr_deriv_child","H < 0: gradient scaled by leak factor","Must reach","Open"),
  @("LRD-COV03","lr_deriv_child","H = 0 boundary exercised","Must reach","Open"),
  @("LC-COV01","loss_child","H > Y (positive gradient produced)","Must reach","Open"),
  @("LC-COV02","loss_child","H < Y (negative gradient produced)","Must reach","Open"),
  @("LC-COV03","loss_child","H = Y (zero gradient)","Must reach","Open"),
  @("LC-COV04","loss_child","valid_in deasserted mid-stream","Must reach","Open"),
  @("GD-COV01","gradient_descent","Weight mode: single-cycle update completes","Must reach","Open"),
  @("GD-COV02","gradient_descent","Bias mode: multi-cycle accumulation (done cascades)","Must reach","Open"),
  @("GD-COV03","gradient_descent","grad_descent_valid_in deasserted after a run","Must reach","Open"),
  @("CU-COV01","control_unit","vpu_data_pathway == 4b1100 (forward pass)","Must reach","Open"),
  @("CU-COV02","control_unit","vpu_data_pathway == 4b1111 (transition)","Must reach","Open"),
  @("CU-COV03","control_unit","vpu_data_pathway == 4b0001 (backward pass)","Must reach","Open"),
  @("CU-COV04","control_unit","sys_switch_in == 1","Must reach","Open"),
  @("CU-COV05","control_unit","ub_rd_transpose == 1","Must reach","Open"),
  @("CU-COV06","control_unit","Both ub_wr_host_valid_in_1 and ub_wr_host_valid_in_2 asserted","Must reach","Open"),
  @("CU-COV07","control_unit","ptr_sel != 0 (non-default pointer)","Must reach","Open"),
  @("VPU-COV01","vpu","Forward pathway (1100) completes - both columns","Must reach","Open"),
  @("VPU-COV02","vpu","Transition pathway (1111) completes - both columns","Must reach","Open"),
  @("VPU-COV03","vpu","Backward pathway (0001) completes - both columns","Must reach","Open"),
  @("VPU-COV04","vpu","Zero pathway direct passthrough","Must reach","Open"),
  @("VPU-COV05","vpu","Both vpu_valid_in_1 and vpu_valid_in_2 simultaneously asserted","Must reach","Open"),
  @("UB-COV01","unified_buffer","Full input read burst (row_size=2 col_size=2) completes","Must reach","Open"),
  @("UB-COV02","unified_buffer","Full weight read burst completes","Must reach","Open"),
  @("UB-COV03","unified_buffer","Host write on port 0 followed by VPU write-back on port 0","Must reach","Open"),
  @("UB-COV04","unified_buffer","Transpose read exercised","Must reach","Open"),
  @("UB-COV05","unified_buffer","Non-transpose read exercised","Must reach","Open"),
  @("UB-COV06","unified_buffer","Column-size valid output asserted (weight pointer selected)","Must reach","Open"),
  @("UB-COV07","unified_buffer","wr_ptr reaches value 4 (2 full 2-column write-back cycles)","Must reach","Open"),
  @("UB-COV08","unified_buffer","Grad-descent write-back chain triggered (both channels done)","Must reach","Open")
)
$r=3; foreach($c in $cov){ for($ci=1;$ci-le 5;$ci++){Set-Val $s5 $r $ci $c[$ci-1]}; if($r%2-eq 0){AltRow $s5 $r 5 "EAD9F7"}; $r++ }
Border $s5.Range("A2:E$($r-1)")
$s5.Columns.Item(1).ColumnWidth=12; $s5.Columns.Item(2).ColumnWidth=18; $s5.Columns.Item(3).ColumnWidth=65; $s5.Columns.Item(4).ColumnWidth=14; $s5.Columns.Item(5).ColumnWidth=10

# ===== SHEET 6 - GAPS AND GLOSSARY =====
Write-Host "Sheet 6: Gaps and Glossary" -ForegroundColor Green
$s7=$wb.Sheets.Add([System.Reflection.Missing]::Value,$wb.Sheets.Item($wb.Sheets.Count))
$s7.Name="Gaps and Glossary"; $s7.Tab.Color=(RGB2Long "404040")
$t=$s7.Range("A1:E1"); $t.Merge(); $t.Value2="Known Gaps, Waivers and Glossary - tiny-tpu FV Plan v1.0"; $t.Font.Size=14; $t.Font.Bold=$true; Fill $t "1F3864"; FillFont $t "FFFFFF"; $t.HorizontalAlignment=-4108; $t.RowHeight=32
$t=$s7.Range("A2:D2"); $t.Merge(); $t.Value2="Accepted Gaps"; Fill $t "404040"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22
$h=@("Gap ID","Category","Description","Mitigation")
for($c=1;$c-le 4;$c++){$s7.Cells.Item(3,$c).Value2=$h[$c-1]}
Hdr $s7 3 4 "404040"
$gaps=@(
  @("GAP-01","Numerical accuracy","fxp_mul/fxp_add rounding depends on ROUND param - SVA cannot express rounding tolerance","cocotb golden-model comparison with NOASSERT=0"),
  @("GAP-02","Memory content","128-word array content not fully provable without a shadow model of equal complexity","Shadow model verification plus cocotb read-back tests"),
  @("GAP-03","End-to-end result","Forward + backward pass numerical correctness requires a multi-cycle floating-point reference model","test_tpu.py with assertion-enabled run"),
  @("GAP-04","Bias accumulation","Gradient-descent feedback loop intractable for formal beyond batch depth 4","Constrained to <=4 in FV - larger batch sizes verified via simulation"),
  @("GAP-05","Stale gradient","loss_child.gradient_out always updates even when invalid - intentional design choice","Documented - LC-COV04 confirms consumer gating on valid_out"),
  @("GAP-06","pe_psum_out reset","pe.sv resets 6 registers but NOT pe_psum_out - real RTL bug","RTL bug filed - PE-A01/PE-A6a intentionally strict to catch this failure")
)
$r=4; foreach($g in $gaps){ for($c=1;$c-le 4;$c++){Set-Val $s7 $r $c $g[$c-1]}; if($r%2-eq 1){AltRow $s7 $r 4 "F2F2F2"}; $r++ }
Border $s7.Range("A3:D$($r-1)"); $r++
$t=$s7.Range("A$r`:E$r"); $t.Merge(); $t.Value2="Waivers"; Fill $t "404040"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22; $r++
$h=@("Waiver ID","Assert IDs","Module","Reason","Risk Level")
for($c=1;$c-le 5;$c++){$s7.Cells.Item($r,$c).Value2=$h[$c-1]}
Hdr $s7 $r 5 "404040"; $fw=$r; $r++
Set-Val $s7 $r 1 "UB-W01"; Set-Val $s7 $r 2 "UB-A08a/b"; Set-Val $s7 $r 3 "unified_buffer"
Set-Val $s7 $r 4 "Host/VPU collision prevented by system-level protocol - not enforced in RTL - assert is documentation only"
Set-Val $s7 $r 5 "Low"; Border $s7.Range("A$fw`:E$r"); $r+=2
$t=$s7.Range("A$r`:B$r"); $t.Merge(); $t.Value2="Glossary"; Fill $t "404040"; FillFont $t "FFFFFF"; $t.Font.Bold=$true; $t.RowHeight=22; $r++
$s7.Cells.Item($r,1).Value2="Term"; $s7.Cells.Item($r,2).Value2="Definition"
Hdr $s7 $r 2 "404040"; $fg=$r; $r++
$glos=@(
  @("AAC","Assume-Assert-Cover - the three types of SVA properties used in formal verification"),
  @("BMC","Bounded Model Checking - formal proof up to k clock cycles"),
  @("CEX","Counterexample - a trace produced by the formal tool demonstrating a property violation"),
  @("CU","Control Unit"),
  @("DUV","Design Under Verification"),
  @("DP","Data Path (assertion category)"),
  @("FA","Functional Arithmetic (assertion category)"),
  @("FV","Formal Verification"),
  @("GD","Gradient Descent"),
  @("LRC","Leaky ReLU Child"),
  @("LRD","Leaky ReLU Derivative Child"),
  @("LV","Liveness / Reachability (assertion category)"),
  @("MAC","Multiply-Accumulate"),
  @("ME","Mutual Exclusion (assertion category)"),
  @("MSE","Mean Squared Error"),
  @("PE","Processing Element"),
  @("Q8.8","Fixed-point format: 8 integer bits plus 8 fractional bits, signed 16-bit total"),
  @("RST","Reset (assertion category)"),
  @("SD","Structural / Decode (assertion category)"),
  @("SVA","SystemVerilog Assertions"),
  @("UB","Unified Buffer"),
  @("VP","Valid Protocol (assertion category)"),
  @("VPU","Vector Processing Unit")
)
foreach($g in $glos){ $s7.Cells.Item($r,1).Value2=$g[0]; $s7.Cells.Item($r,2).Value2=$g[1]; if(($r-$fg)%2-eq 0){AltRow $s7 $r 2 "F2F2F2"}; $r++ }
Border $s7.Range("A$fg`:B$($r-1)")
$s7.Columns.Item(1).ColumnWidth=12; $s7.Columns.Item(2).ColumnWidth=16; $s7.Columns.Item(3).ColumnWidth=18; $s7.Columns.Item(4).ColumnWidth=68; $s7.Columns.Item(5).ColumnWidth=12

# ===== SAVE AND CLOSE =====
Write-Host "Saving $OutputPath ..." -ForegroundColor Cyan
$wb.Sheets.Item("Cover").Select()
$wb.SaveAs($OutputPath, 51)
$wb.Close($false)
$xl.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
Write-Host "Done - file saved: $OutputPath" -ForegroundColor Green
