`timescale 1ns/1ps
`default_nettype none

// 2x2 systolic array
module systolic #(
    parameter int SYSTOLIC_ARRAY_WIDTH = 2
)(
    input logic clk,
    input logic rst,

    // input signals from left side of systolic array
    input logic [15:0] sys_data_in_11,
    input logic [15:0] sys_data_in_21,
    input logic sys_start_1,   // start signal for row 1 (BUG-SYS-2 fix: renamed and split)
    input logic sys_start_2,   // start signal for row 2 (independent channel timing)

    output logic [15:0] sys_data_out_21,
    output logic [15:0] sys_data_out_22,
    output wire sys_valid_out_21, 
    output wire sys_valid_out_22,

    // input signals from top of systolic array
    input logic [15:0] sys_weight_in_11, 
    input logic [15:0] sys_weight_in_12,
    input logic sys_accept_w_1,             // accept weight signal propagates only from top to bottom in column 1
    input logic sys_accept_w_2,             // accept weight signal propagates only from top to bottom in column 2

    input logic sys_switch_in,               // switch signal copies weight from shadow buffer to active buffer. propagates from top left to bottom right

    input logic [15:0] ub_rd_col_size_in,
    input logic ub_rd_col_size_valid_in
);

    // input_out for each PE (left to right)
    logic [15:0] pe_input_out_11;
    logic [15:0] pe_input_out_21;

    // psum_out for each PE (top to bottom)
    logic [15:0] pe_psum_out_11;
    logic [15:0] pe_psum_out_12;

    // weight_out for each PE (top to bottom)
    logic [15:0] pe_weight_out_11;
    logic [15:0] pe_weight_out_12;

    // switch_out for each PE
    logic pe_switch_out_11;
    logic pe_switch_out_12;
    
    // valid_out for each PE (top to bottom)
    wire pe_valid_out_11;   // this wire will connect the valid signal from pe11 to pe12
    wire pe_valid_out_12;   // this wire will connect the valid signal from pe12 to pe22 (BUG-COMMENT-FIX: was incorrectly labelled pe21→pe22)

    // PE columns to enable
    logic [1:0] pe_enabled;

    pe pe11 (
        .clk(clk),
        .rst(rst),
        .pe_enabled(pe_enabled[0]),

        .pe_valid_in(sys_start_1),
        .pe_valid_out(pe_valid_out_11), // valid out signal is now dispatched onto pe_valid_out_11

        .pe_accept_w_in(sys_accept_w_1),
        .pe_switch_in(sys_switch_in),
        .pe_switch_out(pe_switch_out_11),

        .pe_input_in(sys_data_in_11),
        .pe_psum_in(16'b0),
        .pe_weight_in(sys_weight_in_11),
        .pe_input_out(pe_input_out_11),
        .pe_psum_out(pe_psum_out_11),
        .pe_weight_out(pe_weight_out_11),
        .pe_overflow_out()  // BUG-OVF-1: observable via hierarchical reference
    );

    pe pe12 (
        .clk(clk),
        .rst(rst),
        .pe_enabled(pe_enabled[1]),

        .pe_valid_in(pe_valid_out_11),
        .pe_valid_out(pe_valid_out_12),

        .pe_accept_w_in(sys_accept_w_2),
        .pe_switch_in(pe_switch_out_11),
        .pe_switch_out(pe_switch_out_12),

        .pe_input_in(pe_input_out_11),
        .pe_psum_in(16'b0),
        .pe_weight_in(sys_weight_in_12),
        .pe_input_out(),
        .pe_psum_out(pe_psum_out_12),
        .pe_weight_out(pe_weight_out_12),
        .pe_overflow_out()  // BUG-OVF-1: observable via hierarchical reference
    );

    pe pe21 (
        .clk(clk),
        .rst(rst),
        .pe_enabled(pe_enabled[0]),

        .pe_valid_in(sys_start_2),   // BUG-SYS-2 fix: uses independent row-2 start signal
        .pe_valid_out(sys_valid_out_21),

        .pe_accept_w_in(sys_accept_w_1),
        .pe_switch_in(pe_switch_out_11),
        .pe_switch_out(),

        .pe_input_in(sys_data_in_21),
        .pe_psum_in(pe_psum_out_11),
        .pe_weight_in(pe_weight_out_11),
        .pe_input_out(pe_input_out_21),
        .pe_psum_out(sys_data_out_21),
        .pe_weight_out(),
        .pe_overflow_out()  // BUG-OVF-1: observable via hierarchical reference
    );

    pe pe22 ( // pe_valid_in comes from pe12 (same column), pe_enabled controlled by col_size
        .clk(clk),
        .rst(rst),
        .pe_enabled(pe_enabled[1]),

        .pe_valid_in(pe_valid_out_12),
        .pe_valid_out(sys_valid_out_22),

        .pe_accept_w_in(sys_accept_w_2),
        .pe_switch_in(pe_switch_out_12),
        .pe_switch_out(),

        .pe_input_in(pe_input_out_21),
        .pe_psum_in(pe_psum_out_12),
        .pe_weight_in(pe_weight_out_12),
        .pe_input_out(),
        .pe_psum_out(sys_data_out_22),
        .pe_weight_out(),
        .pe_overflow_out()  // BUG-OVF-1: observable via hierarchical reference
    );

    always_ff @(posedge clk or posedge rst) begin  // BUG-SYS-3 fix: always_ff
        if(rst) begin
            pe_enabled <= 2'b11;  // default all columns enabled; col_size command overrides
        end else begin
            if(ub_rd_col_size_valid_in) begin
                // BUG-SYS-1 fix: explicit case prevents silent overflow/underflow
                case (ub_rd_col_size_in[1:0])
                    2'd1:    pe_enabled <= 2'b01;
                    2'd2:    pe_enabled <= 2'b11;
                    default: pe_enabled <= 2'b00;
                endcase
            end
        end
    end

endmodule