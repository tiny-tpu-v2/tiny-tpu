`timescale 1ns/1ps
`default_nettype none

module control_unit (
    // BUG-CU-1 fix: expanded to 130 bits to match TPU port widths
    // Old encoding was 88 bits; widening ub_rd_col_size (1->16b), ub_rd_row_size (7->16b),
    // ub_rd_addr_in (1->16b), ub_ptr_select (2->9b) adds 42 bits.
    input logic [129:0] instruction,  // 130 bits total (0-129)
    
    // 1-bit signals - 5
    output logic sys_switch_in,
    output logic ub_rd_start_in,
    output logic ub_rd_transpose,
    output logic ub_wr_host_valid_in_1,
    output logic ub_wr_host_valid_in_2,
    
    // 16-bit signals (BUG-CU-1 fix: widened to match TPU ub_rd_col_size [15:0])
    output logic [15:0] ub_rd_col_size,

    // 16-bit signals (BUG-CU-1 fix: widened to match TPU ub_rd_row_size [15:0])
    output logic [15:0] ub_rd_row_size,

    // 16-bit signal (BUG-CU-1 fix: widened to match TPU ub_rd_addr_in [15:0])
    output logic [15:0] ub_rd_addr_in,

    // 9-bit signal (BUG-CU-1 fix: widened + renamed ub_ptr_sel -> ub_ptr_select to match TPU)
    output logic [8:0] ub_ptr_select,

    //16 bit signals
    output logic [15:0] ub_wr_host_data_in_1,
    output logic [15:0] ub_wr_host_data_in_2,

    // 4-bit signal
    output logic [3:0] vpu_data_pathway,

    //16-bit signals
    output logic [15:0] inv_batch_size_times_two_in,
    output logic [15:0] vpu_leak_factor_in
);

    // continuous assignments mapping instruction bits to output signals in sequential order
    // bits 0-4: 1-bit signals (5 bits total)
    assign sys_switch_in         = instruction[0];
    assign ub_rd_start_in        = instruction[1];
    assign ub_rd_transpose       = instruction[2];
    assign ub_wr_host_valid_in_1 = instruction[3];
    assign ub_wr_host_valid_in_2 = instruction[4];
    
    // bits 5-20: ub_rd_col_size [15:0]
    assign ub_rd_col_size = instruction[20:5];
    
    // bits 21-36: ub_rd_row_size [15:0]
    assign ub_rd_row_size = instruction[36:21];
    
    // bits 37-52: ub_rd_addr_in [15:0]
    assign ub_rd_addr_in = instruction[52:37];
    
    // bits 53-61: ub_ptr_select [8:0]
    assign ub_ptr_select = instruction[61:53];
    
    // bits 62-77: ub_wr_host_data_in_1 [15:0]
    assign ub_wr_host_data_in_1 = instruction[77:62];
    
    // bits 78-93: ub_wr_host_data_in_2 [15:0]
    assign ub_wr_host_data_in_2 = instruction[93:78];
    
    // bits 94-97: vpu_data_pathway [3:0]
    assign vpu_data_pathway = instruction[97:94];
    
    // bits 98-113: inv_batch_size_times_two_in [15:0]
    assign inv_batch_size_times_two_in = instruction[113:98];
    
    // bits 114-129: vpu_leak_factor_in [15:0]
    assign vpu_leak_factor_in = instruction[129:114];

endmodule