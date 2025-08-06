`timescale 1ns/1ps
`default_nettype none

// three data pathways:
// (forward pass hidden layer computations) input from sys --> bias --> leaky relu --> output
// (transition) input from sys --> bias --> leaky relu --> loss --> leaky relu derivative --> output
// (backward pass) input from sys --> leaky relu derivative --> output
// during the transition pathway we need to store the H matrices that come out of the leaky relu modules AND pass them to the loss modules

/* 
|bias control bit| |lr control bit| |loss control bit| |lr_d control bit|

0000: activate no modules
1100: forward pass pathway (sys --> bias --> leaky relu --> output)
1111: transistion pathway (sys --> bias --> leaky relu --> loss --> leaky relu derivative --> output)
0001: backward pass pathway (sys --> leaky relu derivative --> output)
*/

module vpu (
    input logic clk,
    input logic rst,

    input logic [3:0] data_pathway, // 4-bits to signify which modules to route the inputs to (1 bit for each module)

    // Inputs from systolic array
    input logic signed [15:0] vpu_data_in_1,
    input logic signed [15:0] vpu_data_in_2,
    input logic vpu_valid_in_1,
    input logic vpu_valid_in_2,

    // Inputs from UB
    input logic signed [15:0] bias_scalar_in_1,             // For bias modules
    input logic signed [15:0] bias_scalar_in_2,             // For bias modules
    input logic signed [15:0] lr_leak_factor_in,            // For leaky relu modules
    input logic signed [15:0] Y_in_1,                       // For loss modules
    input logic signed [15:0] Y_in_2,                       // For loss modules
    input logic signed [15:0] inv_batch_size_times_two_in,  // For loss modules
    input logic signed [15:0] H_in_1,                       // For leaky relu derivative modules
    input logic signed [15:0] H_in_2,                       // For leaky relu derivative modules

    // Outputs to UB
    output logic signed [15:0] vpu_data_out_1,
    output logic signed [15:0] vpu_data_out_2,
    output logic vpu_valid_out_1,
    output logic vpu_valid_out_2
);

    // bias
    logic [15:0] bias_data_1_in; 
    logic bias_valid_1_in;
    logic [15:0] bias_data_2_in;
    logic bias_valid_2_in;
    logic [15:0] bias_z_data_out_1;
    logic bias_valid_1_out;
    logic [15:0] bias_z_data_out_2;
    logic bias_valid_2_out;

    // bias to lr intermediate values
    logic [15:0] b_to_lr_data_in_1;
    logic b_to_lr_valid_in_1;
    logic [15:0] b_to_lr_data_in_2;
    logic b_to_lr_valid_in_2;

    // lr
    logic [15:0] lr_data_1_in; 
    logic lr_valid_1_in;
    logic [15:0] lr_data_2_in;
    logic lr_valid_2_in;
    logic [15:0] lr_data_1_out;
    logic lr_valid_1_out;
    logic [15:0] lr_data_2_out;
    logic lr_valid_2_out;

    // lr to loss intermediate values
    logic [15:0] lr_to_loss_data_in_1;
    logic lr_to_loss_valid_in_1;
    logic [15:0] lr_to_loss_data_in_2;
    logic lr_to_loss_valid_in_2;

    // loss
    logic [15:0] loss_data_1_in; 
    logic loss_valid_1_in;
    logic [15:0] loss_data_2_in;
    logic loss_valid_2_in;
    logic [15:0] loss_data_1_out;
    logic loss_valid_1_out;
    logic [15:0] loss_data_2_out;
    logic loss_valid_2_out;

    // loss to lrd intermediate values
    logic [15:0] loss_to_lrd_data_in_1;
    logic loss_to_lrd_valid_in_1;
    logic [15:0] loss_to_lrd_data_in_2;
    logic loss_to_lrd_valid_in_2;

    // lr_d
    logic [15:0] lr_d_data_1_in; 
    logic lr_d_valid_1_in;
    logic [15:0] lr_d_data_2_in;
    logic lr_d_valid_2_in;
    logic [15:0] lr_d_data_1_out;
    logic lr_d_valid_1_out;
    logic [15:0] lr_d_data_2_out;
    logic lr_d_valid_2_out;
    logic [15:0] lr_d_H_1_in;
    logic [15:0] lr_d_H_2_in;

    // temp 'last H matrix' cache
    logic [15:0] last_H_data_1_in;
    logic [15:0] last_H_data_2_in;
    logic [15:0] last_H_data_1_out;
    logic [15:0] last_H_data_2_out;

    bias_parent bias_parent_inst (  
        .clk(clk),
        .rst(rst),
        .bias_sys_data_in_1(bias_data_1_in),    // input
        .bias_sys_data_in_2(bias_data_2_in),    // input
        .bias_sys_valid_in_1(bias_valid_1_in),  // input
        .bias_sys_valid_in_2(bias_valid_2_in),  // input

        .bias_scalar_in_1(bias_scalar_in_1),    // input from UB
        .bias_scalar_in_2(bias_scalar_in_2),    // input from UB 

        .bias_Z_valid_out_1(bias_valid_1_out),  // output
        .bias_Z_valid_out_2(bias_valid_2_out),  // output
        .bias_z_data_out_1(bias_z_data_out_1),  // output
        .bias_z_data_out_2(bias_z_data_out_2)   // output
    );


    leaky_relu_parent leaky_relu_parent_inst (
        .clk(clk),
        .rst(rst),

        .lr_data_1_in(lr_data_1_in),                // input
        .lr_data_2_in(lr_data_2_in),                // input
        .lr_valid_1_in(lr_valid_1_in),              // input
        .lr_valid_2_in(lr_valid_2_in),              // input

        .lr_leak_factor_in(lr_leak_factor_in),      // input from UB
        
        .lr_data_1_out(lr_data_1_out),              // output 
        .lr_data_2_out(lr_data_2_out),              // output
        .lr_valid_1_out(lr_valid_1_out),            // output
        .lr_valid_2_out(lr_valid_2_out)             // output
    );

    loss_parent loss_parent_inst (
        .clk(clk),
        .rst(rst),
        .H_1_in(loss_data_1_in),        // input
        .H_2_in(loss_data_2_in),        // input
        .valid_1_in(loss_valid_1_in),   // input
        .valid_2_in(loss_valid_2_in),   // input

        .Y_1_in(Y_in_1),                // input from UB
        .Y_2_in(Y_in_2),                // input from UB
        .inv_batch_size_times_two_in(inv_batch_size_times_two_in),

        .gradient_1_out(loss_data_1_out), // output
        .gradient_2_out(loss_data_2_out), // output
        .valid_1_out(loss_valid_1_out),
        .valid_2_out(loss_valid_2_out)
    );

    leaky_relu_derivative_parent leaky_relu_derivative_parent_inst (
        .clk(clk),
        .rst(rst),
        .lr_d_data_1_in(lr_d_data_1_in),    // input
        .lr_d_data_2_in(lr_d_data_2_in),    // input
        .lr_d_valid_1_in(lr_d_valid_1_in),  // input
        .lr_d_valid_2_in(lr_d_valid_2_in),  // input

        .lr_d_H_1_in(lr_d_H_1_in),              // input from UB or temp 'last H matrix' cache
        .lr_d_H_2_in(lr_d_H_2_in),              // input from UB or temp 'last H matrix' cache
        .lr_leak_factor_in(lr_leak_factor_in),
        
        .lr_d_data_1_out(lr_d_data_1_out),      // output
        .lr_d_data_2_out(lr_d_data_2_out),      // output
        .lr_d_valid_1_out(lr_d_valid_1_out),    // output
        .lr_d_valid_2_out(lr_d_valid_2_out)     // output
    );

    always_comb begin
        if (rst) begin
            vpu_data_out_1 = 16'b0;
            vpu_data_out_2 = 16'b0;
            vpu_valid_out_1 = 1'b0;
            vpu_valid_out_2 = 1'b0;
            
            // default internal wire assignments during reset
            bias_data_1_in = 16'b0;
            bias_data_2_in = 16'b0;
            bias_valid_1_in = 1'b0;
            bias_valid_2_in = 1'b0;
            lr_data_1_in = 16'b0;
            lr_data_2_in = 16'b0;
            lr_valid_1_in = 1'b0;
            lr_valid_2_in = 1'b0;
            loss_data_1_in = 16'b0;
            loss_data_2_in = 16'b0;
            loss_valid_1_in = 1'b0;
            loss_valid_2_in = 1'b0;
            lr_d_data_1_in = 16'b0;
            lr_d_data_2_in = 16'b0;
            lr_d_valid_1_in = 1'b0;
            lr_d_valid_2_in = 1'b0;
        end else begin
            // bias module
            if(data_pathway[3]) begin
                // connect vpu inputs to bias module
                bias_data_1_in = vpu_data_in_1;
                bias_data_2_in = vpu_data_in_2;
                bias_valid_1_in = vpu_valid_in_1;
                bias_valid_2_in = vpu_valid_in_2;

                // connect bias output to intermediate values
                b_to_lr_data_in_1 = bias_z_data_out_1;
                b_to_lr_data_in_2 = bias_z_data_out_2;
                b_to_lr_valid_in_1 = bias_valid_1_out;
                b_to_lr_valid_in_2 = bias_valid_2_out;
            end else begin
                // disable inputs
                bias_data_1_in = 16'b0;
                bias_data_2_in = 16'b0;
                bias_valid_1_in = 1'b0;
                bias_valid_2_in = 1'b0;

                // connect vpu input to intermediate values
                b_to_lr_data_in_1 = vpu_data_in_1;
                b_to_lr_data_in_2 = vpu_data_in_2;
                b_to_lr_valid_in_1 = vpu_valid_in_1;
                b_to_lr_valid_in_2 = vpu_valid_in_2;
            end

            // leaky relu module
            if(data_pathway[2]) begin
                // connect lr inputs to intermediate values
                lr_data_1_in = b_to_lr_data_in_1;
                lr_data_2_in = b_to_lr_data_in_2;
                lr_valid_1_in = b_to_lr_valid_in_1;
                lr_valid_2_in = b_to_lr_valid_in_2;

                // connect lr outputs to intermediate values
                lr_to_loss_data_in_1 = lr_data_1_out;
                lr_to_loss_data_in_2 = lr_data_2_out;
                lr_to_loss_valid_in_1 = lr_valid_1_out;
                lr_to_loss_valid_in_2 = lr_valid_2_out;

            end else begin
                // disable inputs
                lr_data_1_in = 16'b0;
                lr_data_2_in = 16'b0;
                lr_valid_1_in = 1'b0;
                lr_valid_2_in = 1'b0;

                // connect intermediate values to each other
                lr_to_loss_data_in_1 = b_to_lr_data_in_1;
                lr_to_loss_data_in_2 = b_to_lr_data_in_2;
                lr_to_loss_valid_in_1 = b_to_lr_valid_in_1;
                lr_to_loss_valid_in_2 = b_to_lr_valid_in_2;
            end

            // loss module
            if(data_pathway[1]) begin
                // connect loss inputs to intermediate values
                loss_data_1_in = lr_to_loss_data_in_1;
                loss_data_2_in = lr_to_loss_data_in_2;
                loss_valid_1_in = lr_to_loss_valid_in_1;
                loss_valid_2_in = lr_to_loss_valid_in_2;

                // connect loss outputs to intermediate values
                loss_to_lrd_data_in_1 = loss_data_1_out;
                loss_to_lrd_data_in_2 = loss_data_2_out;
                loss_to_lrd_valid_in_1 = loss_valid_1_out;
                loss_to_lrd_valid_in_2 = loss_valid_2_out;

                // Cache and use 'last H matrix'
                last_H_data_1_in = lr_data_1_out;
                last_H_data_2_in = lr_data_2_out;
                lr_d_H_1_in = last_H_data_1_out;
                lr_d_H_2_in = last_H_data_2_out;
            end else begin
                // disable inputs
                loss_data_1_in = 16'b0;
                loss_data_2_in = 16'b0;
                loss_valid_1_in = 1'b0;
                loss_valid_2_in = 1'b0;

                // connect intermediate values to each other
                loss_to_lrd_data_in_1 = lr_to_loss_data_in_1;
                loss_to_lrd_data_in_2 = lr_to_loss_data_in_2;
                loss_to_lrd_valid_in_1 = lr_to_loss_valid_in_1;
                loss_to_lrd_valid_in_2 = lr_to_loss_valid_in_2;

                // Don't cache and use 'last H matrix'
                lr_d_H_1_in = H_in_1;
                lr_d_H_2_in = H_in_2;
            end

            // leaky relu derivative module
            if(data_pathway[0]) begin
                lr_d_data_1_in = loss_to_lrd_data_in_1;
                lr_d_data_2_in = loss_to_lrd_data_in_2;
                lr_d_valid_1_in = loss_to_lrd_valid_in_1;
                lr_d_valid_2_in = loss_to_lrd_valid_in_2;

                // connect lr_d outputs to vpu output
                vpu_data_out_1 = lr_d_data_1_out;
                vpu_data_out_2 = lr_d_data_2_out;
                vpu_valid_out_1 = lr_d_valid_1_out;
                vpu_valid_out_2 = lr_d_valid_2_out;
            end else begin
                // disable inputs
                lr_d_data_1_in = loss_to_lrd_data_in_1;
                lr_d_data_2_in = loss_to_lrd_data_in_2;
                lr_d_valid_1_in = loss_to_lrd_valid_in_1;
                lr_d_valid_2_in = loss_to_lrd_valid_in_2;

                // connect intermediate values to vpu output
                vpu_data_out_1 = loss_to_lrd_data_in_1;
                vpu_data_out_2 = loss_to_lrd_data_in_2;
                vpu_valid_out_1 = loss_to_lrd_valid_in_1;
                vpu_valid_out_2 = loss_to_lrd_valid_in_2;
            end
        end
    end

    // sequential logic to cache last H???
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            last_H_data_1_in <= 0;
            last_H_data_2_in <= 0;
            last_H_data_1_out <= 0;
            last_H_data_2_out <= 0;
        end else begin
            if (data_pathway[1]) begin
                last_H_data_1_out <= last_H_data_1_in;
                last_H_data_2_out <= last_H_data_2_in;
            end else begin
                last_H_data_1_out <= 0;
                last_H_data_2_out <= 0;
            end 
        end
    end

endmodule

// `timescale 1ns/1ps
// `default_nettype none

// // three data pathways:
// // (forward pass hidden layer computations) input from sys --> bias --> leaky relu --> output
// // (transition) input from sys --> bias --> leaky relu --> loss --> leaky relu derivative --> output
// // (backward pass) input from sys --> leaky relu derivative --> output
// // during the transition pathway we need to store the H matrices that come out of the leaky relu modules AND pass them to the loss modules



// module vpu (
//     input logic clk,
//     input logic rst,

//     input logic [3:0] data_pathway, // 4-bits to signify which modules to route the inputs to (1 bit for each module)
    
//     // comes from systolic array  VALID SIGNALS HERE CO-EXIST WITH THE DATA 
//     input logic signed [15:0] vpu_data_in_1, 
//     input logic signed [15:0] vpu_data_in_2,
//     input logic vpu_valid_in_1,
//     input logic vpu_valid_in_2,
    
//     // comes from UB
//     input logic signed [15:0] bias_scalar_in_1,             // for bias module
//     input logic signed [15:0] bias_scalar_in_2,             // for bias module
//     input logic signed [15:0] lr_leak_factor_in,            // for Leaky ReLU module                  
//     input logic signed [15:0] Y_in_1,                       // for loss module
//     input logic signed [15:0] Y_in_2,                       // for loss module
//     input logic signed [15:0] H_in_1,                       // for loss module
//     input logic signed [15:0] H_in_2,                       // for loss module
//     input logic signed [15:0] inv_batch_size_times_two_in,  // for loss module

//     // goes to UB
//     output logic signed [15:0] vpu_data_out_1,
//     output logic signed [15:0] vpu_data_out_2,
//     output logic vpu_valid_out_1,
//     output logic vpu_valid_out_2,
//     output logic [15:0] vpu_final_H_out_1,
//     output logic [15:0] vpu_final_H_out_2,
//     output logic vpu_valid_final_H_out_1,
//     output logic vpu_valid_final_H_out_2
// );
    
//     /*
//     000: do nothing
//     001: input from sys --> bias --> leaky relu --> output (forward pass)
//     010: input from sys --> bias --> leaky relu (output to UB) --> loss --> leaky relu derivative --> output to UB (pipeline forward to backward pass)
//     011: input from sys --> leaky relu derivative --> output (backward pass)
//     */

//     /* |bias control bit| |lr control bit| |loss control bit| |lr_d control bit|
//     0000: activate no modules
//     1100: forward pass pathway (sys --> bias --> leaky relu --> output)
//     1111: transistion pathway (sys --> bias --> leaky relu --> loss --> leaky relu derivative --> output)
//     0001: backward pass pathway (sys --> leaky relu derivative --> output)
//     */

//     // bias
//     logic [15:0] bias_data_1_in; 
//     logic bias_valid_1_in;
//     logic [15:0] bias_data_2_in;
//     logic bias_valid_2_in;
//     logic [15:0] bias_z_data_out_1;
//     logic bias_valid_1_out;
//     logic [15:0] bias_z_data_out_2;
//     logic bias_valid_2_out;

//     // lr
//     logic [15:0] lr_data_1_in; 
//     logic lr_valid_1_in;
//     logic [15:0] lr_data_2_in;
//     logic lr_valid_2_in;
//     logic [15:0] lr_data_1_out;
//     logic lr_valid_1_out;
//     logic [15:0] lr_data_2_out;
//     logic lr_valid_2_out;

//     // loss
//     logic [15:0] loss_data_1_in; 
//     logic loss_valid_1_in;
//     logic [15:0] loss_data_2_in;
//     logic loss_valid_2_in;
//     logic [15:0] loss_data_1_out;
//     logic loss_valid_1_out;
//     logic [15:0] loss_data_2_out;
//     logic loss_valid_2_out;

//     // lr_d
//     logic [15:0] lr_d_data_1_in; 
//     logic lr_d_valid_1_in;
//     logic [15:0] lr_d_data_2_in;
//     logic lr_d_valid_2_in;
//     logic [15:0] lr_d_data_1_out;
//     logic lr_d_valid_1_out;
//     logic [15:0] lr_d_data_2_out;
//     logic lr_d_valid_2_out;
//     logic [15:0] lr_d_H_1_in;
//     logic [15:0] lr_d_H_2_in;
    

//     // temp H2 cache (last H values from leaky relu during forward pass)
//     logic [15:0] last_H_data_1_in;
//     logic [15:0] last_H_data_2_in;
//     logic [15:0] last_H_data_1_out;
//     logic [15:0] last_H_data_2_out;
    

// // make combinational always block to decode a "word" to signify data pathway
// always_comb begin   
//     if (rst) begin
//         vpu_data_out_1 = 16'b0;
//         vpu_data_out_2 = 16'b0;
//         vpu_valid_out_1 = 1'b0;
//         vpu_valid_out_2 = 1'b0;
//         vpu_final_H_out_1 = 16'b0;
//         vpu_final_H_out_2 = 16'b0;
//         vpu_valid_final_H_out_1 = 1'b0;
//         vpu_valid_final_H_out_2 = 1'b0;
        
//         // default internal wire assignments during reset
//         bias_data_1_in = 16'b0;
//         bias_data_2_in = 16'b0;
//         bias_valid_1_in = 1'b0;
//         bias_valid_2_in = 1'b0;
//         lr_data_1_in = 16'b0;
//         lr_data_2_in = 16'b0;
//         lr_valid_1_in = 1'b0;
//         lr_valid_2_in = 1'b0;
//         loss_data_1_in = 16'b0;
//         loss_data_2_in = 16'b0;
//         loss_valid_1_in = 1'b0;
//         loss_valid_2_in = 1'b0;
//         lr_d_data_1_in = 16'b0;
//         lr_d_data_2_in = 16'b0;
//         lr_d_valid_1_in = 1'b0;
//         lr_d_valid_2_in = 1'b0;
//     end else begin 
        
//         case (data_pathway) 
            
//             3'b000: begin // do nothing
//                 // No operation, no data flow
//                 vpu_data_out_1 = 16'b0;
//                 vpu_data_out_2 = 16'b0;
//                 vpu_valid_out_1 = 1'b0;
//                 vpu_valid_out_2 = 1'b0;
//                 vpu_final_H_out_1 = 16'b0;
//                 vpu_final_H_out_2 = 16'b0;
//                 vpu_valid_final_H_out_1 = 1'b0;
//                 vpu_valid_final_H_out_2 = 1'b0;
                
//                 // disable all internal connections
//                 bias_data_1_in = 16'b0;
//                 bias_data_2_in = 16'b0;
//                 bias_valid_1_in = 1'b0;
//                 bias_valid_2_in = 1'b0;
//                 lr_data_1_in = 16'b0;
//                 lr_data_2_in = 16'b0;
//                 lr_valid_1_in = 1'b0;
//                 lr_valid_2_in = 1'b0;
//                 loss_data_1_in = 16'b0;
//                 loss_data_2_in = 16'b0;
//                 loss_valid_1_in = 1'b0;
//                 loss_valid_2_in = 1'b0;
//                 lr_d_data_1_in = 16'b0;
//                 lr_d_data_2_in = 16'b0;
//                 lr_d_valid_1_in = 1'b0;
//                 lr_d_valid_2_in = 1'b0;
//             end
            
//             3'b001: begin // forward pass: sys -> bias -> leaky_relu -> output
//                 // connect systolic data to bias module
//                 bias_data_1_in = vpu_data_in_1;
//                 bias_data_2_in = vpu_data_in_2;
//                 bias_valid_1_in = vpu_valid_in_1;
//                 bias_valid_2_in = vpu_valid_in_2;
                
//                 // connect bias output to leaky relu
//                 lr_data_1_in = bias_z_data_out_1;
//                 lr_data_2_in = bias_z_data_out_2;
//                 lr_valid_1_in = bias_valid_1_out;
//                 lr_valid_2_in = bias_valid_2_out;
                
//                 // connect leaky relu output to VPU output
//                 vpu_data_out_1 = lr_data_1_out;
//                 vpu_data_out_2 = lr_data_2_out;
//                 vpu_valid_out_1 = lr_valid_1_out;
//                 vpu_valid_out_2 = lr_valid_2_out;
                
//                 // no final H output in forward pass
//                 vpu_final_H_out_1 = 16'b0;
//                 vpu_final_H_out_2 = 16'b0;
//                 vpu_valid_final_H_out_1 = 1'b0;
//                 vpu_valid_final_H_out_2 = 1'b0;
                
//                 // disable unused modules
//                 loss_data_1_in = 16'b0;
//                 loss_data_2_in = 16'b0;
//                 loss_valid_1_in = 1'b0;
//                 loss_valid_2_in = 1'b0;
//                 lr_d_data_1_in = 16'b0;
//                 lr_d_data_2_in = 16'b0;
//                 lr_d_valid_1_in = 1'b0;
//                 lr_d_valid_2_in = 1'b0;
//             end
            
//             3'b010: begin // transition: sys -> bias -> leaky_relu -> loss -> leaky_relu_derivative -> output
//                 // Connect systolic data to bias module
//                 bias_data_1_in = vpu_data_in_1;
//                 bias_data_2_in = vpu_data_in_2;
//                 bias_valid_1_in = vpu_valid_in_1;
//                 bias_valid_2_in = vpu_valid_in_2;
                
//                 // Connect bias output to leaky relu
//                 lr_data_1_in = bias_z_data_out_1;
//                 lr_data_2_in = bias_z_data_out_2;
//                 lr_valid_1_in = bias_valid_1_out;
//                 lr_valid_2_in = bias_valid_2_out;

//                 // Connect leaky relu output to loss module
//                 loss_data_1_in = lr_data_1_out;
//                 loss_data_2_in = lr_data_2_out;
//                 loss_valid_1_in = lr_valid_1_out;
//                 loss_valid_2_in = lr_valid_2_out;
                
//                 // Connect leaky relu output to last H cache
//                 last_H_data_1_in = lr_data_1_out;
//                 last_H_data_2_in = lr_data_2_out;
                
//                 // Connect loss output to leaky relu derivative
//                 lr_d_data_1_in = loss_data_1_out;
//                 lr_d_data_2_in = loss_data_2_out;
//                 lr_d_valid_1_in = loss_valid_1_out;
//                 lr_d_valid_2_in = loss_valid_2_out;
                
//                 // Connect leaky relu derivative output to VPU output
//                 vpu_data_out_1 = lr_d_data_1_out;
//                 vpu_data_out_2 = lr_d_data_2_out;
//                 vpu_valid_out_1 = lr_d_valid_1_out;
//                 vpu_valid_out_2 = lr_d_valid_2_out;

//                 // Connect last H cache output to leaky relu derivative modules
//                 lr_d_H_1_in = last_H_data_1_out;
//                 lr_d_H_2_in = last_H_data_1_out;


//                 // Store H matrices from leaky relu for later use
//                 // vpu_final_H_out_1 = lr_data_1_out;
//                 // vpu_final_H_out_2 = lr_data_2_out;
//                 // vpu_valid_final_H_out_1 = lr_valid_1_out;
//                 // vpu_valid_final_H_out_2 = lr_valid_2_out;
//             end
            
//             3'b011: begin // backward: sys -> leaky_relu_derivative -> output
//                 // sys to leaky relu derivative
//                 lr_d_data_1_in = vpu_data_in_1;
//                 lr_d_data_2_in = vpu_data_in_2;
//                 lr_d_valid_1_in = vpu_valid_in_1;
//                 lr_d_valid_2_in = vpu_valid_in_2;

//                 // connect stored H values to leaky relu derivative
//                 lr_d_H_1_in = H_in_1;
//                 lr_d_H_2_in = H_in_2;

//                 // connect leaky relu derivative output to VPU output
//                 vpu_data_out_1 = lr_d_data_1_out;
//                 vpu_data_out_2 = lr_d_data_2_out;
//                 vpu_valid_out_1 = lr_d_valid_1_out;
//                 vpu_valid_out_2 = lr_d_valid_2_out;
                
//                 // no final H output in backward pass
//                 vpu_final_H_out_1 = 16'b0;
//                 vpu_final_H_out_2 = 16'b0;
//                 vpu_valid_final_H_out_1 = 1'b0;
//                 vpu_valid_final_H_out_2 = 1'b0;
                
//                 // disable unused modules
//                 bias_data_1_in = 16'b0;
//                 bias_data_2_in = 16'b0;
//                 bias_valid_1_in = 1'b0;
//                 bias_valid_2_in = 1'b0;
//                 lr_data_1_in = 16'b0;
//                 lr_data_2_in = 16'b0;
//                 lr_valid_1_in = 1'b0;
//                 lr_valid_2_in = 1'b0;
//                 loss_data_1_in = 16'b0;
//                 loss_data_2_in = 16'b0;
//                 loss_valid_1_in = 1'b0;
//                 loss_valid_2_in = 1'b0;
//             end
            
//             default: begin
//                 // Default case - same as 000
//                 vpu_data_out_1 = 16'b0;
//                 vpu_data_out_2 = 16'b0;
//                 vpu_valid_out_1 = 1'b0;
//                 vpu_valid_out_2 = 1'b0;
//                 vpu_final_H_out_1 = 16'b0;
//                 vpu_final_H_out_2 = 16'b0;
//                 vpu_valid_final_H_out_1 = 1'b0;
//                 vpu_valid_final_H_out_2 = 1'b0;
                
//                 bias_data_1_in = 16'b0;
//                 bias_data_2_in = 16'b0;
//                 bias_valid_1_in = 1'b0;
//                 bias_valid_2_in = 1'b0;
//                 lr_data_1_in = 16'b0;
//                 lr_data_2_in = 16'b0;
//                 lr_valid_1_in = 1'b0;
//                 lr_valid_2_in = 1'b0;
//                 loss_data_1_in = 16'b0;
//                 loss_data_2_in = 16'b0;
//                 loss_valid_1_in = 1'b0;
//                 loss_valid_2_in = 1'b0;
//                 lr_d_data_1_in = 16'b0;
//                 lr_d_data_2_in = 16'b0;
//                 lr_d_valid_1_in = 1'b0;
//                 lr_d_valid_2_in = 1'b0;
//             end

//         endcase
//     end
// end


// bias_parent bias_parent_inst (  
//     .clk(clk),
//     .rst(rst),
//     .bias_scalar_in_1(bias_scalar_in_1), // input from UB
//     .bias_scalar_in_2(bias_scalar_in_2), // input from UB 
//     .bias_Z_valid_out_1(bias_valid_1_out),
//     .bias_Z_valid_out_2(bias_valid_2_out),
//     .bias_sys_data_in_1(bias_data_1_in), // controlled by pathway logic
//     .bias_sys_data_in_2(bias_data_2_in), // controlled by pathway logic
//     .bias_sys_valid_in_1(bias_valid_1_in), // controlled by pathway logic
//     .bias_sys_valid_in_2(bias_valid_2_in), // controlled by pathway logic
//     .bias_z_data_out_1(bias_z_data_out_1), // output to leaky relu
//     .bias_z_data_out_2(bias_z_data_out_2)  // output to leaky relu
// );


// leaky_relu_parent leaky_relu_parent_inst (

//     .clk(clk),
//     .rst(rst),

//     .lr_leak_factor_in(lr_leak_factor_in),

//     .lr_valid_1_in(lr_valid_1_in),
//     .lr_valid_2_in(lr_valid_2_in),

//     .lr_data_1_in(lr_data_1_in), // takes in bias output
//     .lr_data_2_in(lr_data_2_in), // takes in bias output
    
//     .lr_valid_1_out(lr_valid_1_out),
//     .lr_valid_2_out(lr_valid_2_out),
    
//     .lr_data_1_out(lr_data_1_out), // output to loss or (loss and UB) or nothing 
//     .lr_data_2_out(lr_data_2_out) // output to loss or UB
// );

// loss_parent loss_parent_inst (
//     .clk(clk),
//     .rst(rst),
//     .H_1_in(loss_data_1_in), // H values from leaky relu
//     .Y_1_in(Y_in_1), // Expected Y values from UB
//     .H_2_in(loss_data_2_in), // H values from leaky relu
//     .Y_2_in(Y_in_2), // Expected Y values from UB
//     .valid_1_in(loss_valid_1_in),
//     .valid_2_in(loss_valid_2_in),
//     .inv_batch_size_times_two_in(inv_batch_size_times_two_in),
//     .gradient_1_out(loss_data_1_out), // gradient output
//     .gradient_2_out(loss_data_2_out), // gradient output
//     .valid_1_out(loss_valid_1_out),
//     .valid_2_out(loss_valid_2_out)
// );

// leaky_relu_derivative_parent leaky_relu_derivative_parent_inst (
//     .clk(clk),
//     .rst(rst),
//     .lr_leak_factor_in(lr_leak_factor_in),
//     .lr_d_valid_1_in(lr_d_valid_1_in),
//     .lr_d_valid_2_in(lr_d_valid_2_in),
//     .lr_d_data_1_in(lr_d_data_1_in), // controlled by pathway logic
//     .lr_d_data_2_in(lr_d_data_2_in), // controlled by pathway logic
//     .lr_d_data_1_out(lr_d_data_1_out),
//     .lr_d_data_2_out(lr_d_data_2_out),
//     .lr_d_valid_1_out(lr_d_valid_1_out),
//     .lr_d_valid_2_out(lr_d_valid_2_out),
//     .lr_d_H_1_in(lr_d_H_1_in),
//     .lr_d_H_2_in(lr_d_H_2_in)
// );

// // sequential logic to cache last H???
// always @(posedge clk or posedge rst) begin
    
//     if (rst) begin
//         last_H_data_1_in <= 0;
//         last_H_data_2_in <= 0;
//         last_H_data_1_out <= 0;
//         last_H_data_2_out <= 0;

//     end else begin
//         if (data_pathway == 3'b010) begin
//             last_H_data_1_out <= last_H_data_1_in;
//             last_H_data_2_out <= last_H_data_2_in;
//         end else begin
//             last_H_data_1_out <= 0;
//             last_H_data_2_out <= 0;
//         end 
//     end
    
// end 

// endmodule