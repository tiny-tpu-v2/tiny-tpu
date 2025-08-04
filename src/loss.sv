`timescale 1ns/1ps
`default_nettype none

// Module: loss
// Computes either
//   • MSE loss  ( (H−Y)^2 / N )  or
//   • d(MSE)/dH ( 2(H−Y) / N ).
// Uses the project fixed-point primitives:
//   − fxp_addsub  (subtraction)
//   − fxp_mul     (combinational multiplier)
// A small 3-cycle pipeline keeps the combinational depth per stage to
// one multiplier, giving good timing on an FPGA while still sustaining
// two results per clock.

module loss #(
    parameter int DATA_WIDTH = 16,
    parameter int FRAC_BITS  = 8
)(
    input  logic                          clk,
    input  logic                          rst,

    // Dual-port inputs from unified buffer
    input  logic signed [DATA_WIDTH-1:0]  H_in_1,
    input  logic signed [DATA_WIDTH-1:0]  H_in_2,
    input  logic signed [DATA_WIDTH-1:0]  target_Y_in_1,
    input  logic signed [DATA_WIDTH-1:0]  target_Y_in_2,
    input  logic                          valid_in_1,
    input  logic                          valid_in_2,

    // Control (constant while a burst is processed)
    input  logic                          compute_derivative,   // 1 = derivative, 0 = loss
    input  logic signed [DATA_WIDTH-1:0]  num_samples_in,       // N > 0

    // Outputs back to unified buffer
    output logic signed [DATA_WIDTH-1:0]  loss_out_1,
    output logic signed [DATA_WIDTH-1:0]  loss_out_2,
    output logic                          valid_out_1,
    output logic                          valid_out_2
);

    // ------------------------------------------------------------------
    // Scale factors (combinational wires)
    // ------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] scale_factor_deriv =
        (num_samples_in != 0) ? ((16'sd2 << FRAC_BITS) / num_samples_in) : 0; // 2/N
    wire signed [DATA_WIDTH-1:0] scale_factor_loss  =
        (num_samples_in != 0) ? ((16'sd1 << FRAC_BITS) / num_samples_in) : 0; // 1/N

    // ==================================================================
    // Stage 0 -> Stage 1 :  subtract (H − Y)
    // ==================================================================
    wire signed [DATA_WIDTH-1:0] diff_1_s0, diff_2_s0;
    fxp_addsub sub1 (.ina(H_in_1), .inb(target_Y_in_1), .sub(1'b1), .out(diff_1_s0), .overflow());
    fxp_addsub sub2 (.ina(H_in_2), .inb(target_Y_in_2), .sub(1'b1), .out(diff_2_s0), .overflow());

    logic signed [DATA_WIDTH-1:0] diff_1_s1, diff_2_s1;
    logic                         vld_1_s1,  vld_2_s1;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            diff_1_s1 <= '0; diff_2_s1 <= '0;
            vld_1_s1  <= 1'b0; vld_2_s1 <= 1'b0;
        end else begin
            diff_1_s1 <= diff_1_s0;
            diff_2_s1 <= diff_2_s0;
            vld_1_s1  <= valid_in_1;
            vld_2_s1  <= valid_in_2;
        end
    end

    // ==================================================================
    // Stage 2 : one multiplier per path
    //   derivative: diff * (2/N)
    //   loss path : diff²
    // ==================================================================
    wire signed [DATA_WIDTH-1:0] deriv_s2_1, deriv_s2_2;
    fxp_mul mul_deriv_1 (.ina(diff_1_s1), .inb(scale_factor_deriv), .out(deriv_s2_1), .overflow());
    fxp_mul mul_deriv_2 (.ina(diff_2_s1), .inb(scale_factor_deriv), .out(deriv_s2_2), .overflow());

    wire signed [DATA_WIDTH-1:0] diff_sq_s2_1, diff_sq_s2_2;
    fxp_mul mul_square_1 (.ina(diff_1_s1), .inb(diff_1_s1), .out(diff_sq_s2_1), .overflow());
    fxp_mul mul_square_2 (.ina(diff_2_s1), .inb(diff_2_s1), .out(diff_sq_s2_2), .overflow());

    // Register stage 2 outputs -> Stage 3
    logic signed [DATA_WIDTH-1:0] deriv_s3_1, deriv_s3_2;
    logic signed [DATA_WIDTH-1:0] diff_sq_s3_1, diff_sq_s3_2;
    logic                         vld_1_s2, vld_2_s2;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            deriv_s3_1 <= '0; deriv_s3_2 <= '0;
            diff_sq_s3_1 <= '0; diff_sq_s3_2 <= '0;
            vld_1_s2 <= 1'b0; vld_2_s2 <= 1'b0;
        end else begin
            deriv_s3_1 <= deriv_s2_1;
            deriv_s3_2 <= deriv_s2_2;
            diff_sq_s3_1 <= diff_sq_s2_1;
            diff_sq_s3_2 <= diff_sq_s2_2;
            vld_1_s2 <= vld_1_s1;
            vld_2_s2 <= vld_2_s1;
        end
    end

    // ==================================================================
    // Stage 3 : second multiply for loss path   (diff²) * (1/N)
    // ==================================================================
    wire signed [DATA_WIDTH-1:0] loss_s3_1, loss_s3_2;
    fxp_mul mul_scale_1 (.ina(diff_sq_s3_1), .inb(scale_factor_loss), .out(loss_s3_1), .overflow());
    fxp_mul mul_scale_2 (.ina(diff_sq_s3_2), .inb(scale_factor_loss), .out(loss_s3_2), .overflow());

    // Final register (Stage 4) – aligns both modes to same latency
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            loss_out_1 <= '0; loss_out_2 <= '0;
            valid_out_1 <= 1'b0; valid_out_2 <= 1'b0;
        end else begin
            if (compute_derivative) begin
                loss_out_1 <= deriv_s3_1;
                loss_out_2 <= deriv_s3_2;
            end else begin
                loss_out_1 <= loss_s3_1;
                loss_out_2 <= loss_s3_2;
            end
            valid_out_1 <= vld_1_s2; // Stage-3 latency matches
            valid_out_2 <= vld_2_s2;
        end
    end

endmodule
