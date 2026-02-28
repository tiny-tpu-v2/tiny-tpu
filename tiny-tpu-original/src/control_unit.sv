`timescale 1ns/1ps
`default_nettype none

module control_unit (
    input logic [87:0] instruction,  // updated to 88 bits total (0-87)
    
    // 1-bit signals - 5
    output logic sys_switch_in,
    output logic ub_rd_start_in,
    output logic ub_rd_transpose,
    output logic ub_wr_host_valid_in_1,
    output logic ub_wr_host_valid_in_2,
    
    // 2 bit signals
    output logic [1:0] ub_rd_col_size,

    // 8-bit signals
    output logic [7:0] ub_rd_row_size,
    output logic [1:0] ub_rd_addr_in,

    // 3 bit signals
    output logic [2:0] ub_ptr_sel,

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
    assign sys_switch_in = instruction[0];
    assign ub_rd_start_in = instruction[1];
    assign ub_rd_transpose = instruction[2];
    assign ub_wr_host_valid_in_1 = instruction[3];
    assign ub_wr_host_valid_in_2 = instruction[4];
    
    // bits 5-6: 2-bit signal
    assign ub_rd_col_size = instruction[6:5];
    
    // bits 7-14: 8-bit signal
    assign ub_rd_row_size = instruction[14:7];
    
    // bits 15-16: 2-bit signal
    assign ub_rd_addr_in = instruction[16:15];
    
    // bits 17-19: 3-bit signal
    assign ub_ptr_sel = instruction[19:17];
    
    // bits 20-35: 16-bit signal
    assign ub_wr_host_data_in_1 = instruction[35:20];
    
    // bits 36-51: 16-bit signal
    assign ub_wr_host_data_in_2 = instruction[51:36];
    
    // bits 52-55: 4-bit signal
    assign vpu_data_pathway = instruction[55:52];
    
    // bits 56-71: 16-bit signal
    assign inv_batch_size_times_two_in = instruction[71:56];
    
    // bits 72-87: 16-bit signal
    assign vpu_leak_factor_in = instruction[87:72];

endmodule