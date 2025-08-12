`timescale 1ns/1ps
`default_nettype none

module control_unit (
    input logic [155:0] instruction,
    
    // 1-bit signals
    output logic sys_switch_in,
    output logic ub_rd_weight_transpose,
    output logic ub_rd_weight_start_in,
    output logic ub_rd_input_transpose,
    output logic ub_rd_input_start_in,
    output logic ub_rd_bias_start_in,
    output logic ub_rd_H_start_in,
    output logic ub_rd_Y_start_in,
    output logic ub_wr_host_valid_in_1,
    output logic ub_wr_host_valid_in_2,
    output logic ub_wr_addr_valid_in,
    
    // 16-bit signals
    output logic [15:0] inv_batch_size_times_two_in,
    output logic [15:0] vpu_leak_factor_in,
    output logic [15:0] ub_wr_host_data_in_1,
    output logic [15:0] ub_wr_host_data_in_2,
    
    // 4-bit signal
    output logic [3:0] vpu_data_pathway,
    
    // 7-bit signals  
    output logic [6:0] ub_rd_input_loc_in,
    output logic [6:0] ub_rd_weight_loc_in,
    output logic [6:0] ub_rd_bias_loc_in,
    output logic [6:0] ub_rd_H_loc_in,
    output logic [6:0] ub_rd_Y_loc_in,
    output logic [6:0] ub_wr_addr_in,
    output logic [6:0] ub_rd_input_addr_in,
    output logic [6:0] ub_rd_weight_addr_in,
    output logic [6:0] ub_rd_bias_addr_in,
    output logic [6:0] ub_rd_H_addr_in,
    output logic [6:0] ub_rd_Y_addr_in
);

    // continuous assignments mapping instruction bits to output signals
    assign sys_switch_in = instruction[0];
    assign ub_rd_weight_transpose = instruction[1];
    assign ub_rd_weight_start_in = instruction[2];
    assign ub_rd_input_transpose = instruction[3];
    assign ub_rd_input_start_in = instruction[4];
    assign ub_rd_bias_start_in = instruction[5];
    assign ub_rd_H_start_in = instruction[6];
    assign ub_rd_Y_start_in = instruction[7];
    assign ub_wr_host_valid_in_1 = instruction[8];
    assign ub_wr_host_valid_in_2 = instruction[9];
    assign ub_wr_addr_valid_in = instruction[10];

    assign inv_batch_size_times_two_in = instruction[26:11];
    assign vpu_leak_factor_in = instruction[42:27];
    assign vpu_data_pathway = instruction[46:43];
    assign ub_wr_host_data_in_1 = instruction[62:47];
    assign ub_wr_host_data_in_2 = instruction[78:63];

    assign ub_rd_input_loc_in = instruction[85:79];
    assign ub_rd_weight_loc_in = instruction[92:86];
    assign ub_rd_bias_loc_in = instruction[99:93];
    assign ub_rd_H_loc_in = instruction[106:100];
    assign ub_rd_Y_loc_in = instruction[113:107];
    assign ub_wr_addr_in = instruction[120:114];
    assign ub_rd_input_addr_in = instruction[127:121];
    assign ub_rd_weight_addr_in = instruction[134:128];
    assign ub_rd_bias_addr_in = instruction[141:135];
    assign ub_rd_H_addr_in = instruction[148:142];
    assign ub_rd_Y_addr_in = instruction[155:149];

endmodule