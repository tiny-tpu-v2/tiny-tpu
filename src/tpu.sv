`timescale 1ns/1ps
`default_nettype none

// goal of this module is to verify that the systolic array works. 

module tpu (
    // wires n shit
);

// TODO: add writing functionality from Host to UB to write X (input values) and W (weights) matrices into UB memory
unified_buffer unified_buffer_inst (
    
);


vpu_inst(
    clk,
    rst,

    data_pathway, // 4-bits to signify which modules to route the inputs to (1 bit for each module)

    // Inputs from systolic array
    vpu_data_in_1,
    vpu_data_in_2,
    vpu_valid_in_1,
    vpu_valid_in_2,

    // Inputs from UB
    bias_scalar_in_1,             // For bias modules
    bias_scalar_in_2,             // For bias modules
    lr_leak_factor_in,            // For leaky relu modules
    Y_in_1,                       // For loss modules
    Y_in_2,                       // For loss modules
    inv_batch_size_times_two_in,  // For loss modules
    H_in_1,                       // For leaky relu derivative modules
    H_in_2,                       // For leaky relu derivative modules

    // Outputs to UB
    vpu_data_out_1,
    vpu_data_out_2,
    vpu_valid_out_1,
    vpu_valid_out_2

); 





endmodule