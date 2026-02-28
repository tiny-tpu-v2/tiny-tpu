// ABOUTME: DE1-SoC top-level wrapper for the tiny-tpu XOR demo.
// ABOUTME: It debounces a start button, runs one forward pass, and latches the displayed result.
`timescale 1ns/1ps
`default_nettype none

module de1_soc_tiny_tpu_xor_top #(
    parameter integer DEBOUNCE_LIMIT = 50000
) (
    input wire CLOCK_50,
    input wire [3:0] KEY,
    input wire [9:0] SW,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [9:0] LEDR
);
    localparam [3:0] ST_IDLE      = 4'd0;
    localparam [3:0] ST_TPU_RESET = 4'd1;
    localparam [3:0] ST_LOAD      = 4'd2;
    localparam [3:0] ST_CMD_W1    = 4'd3;
    localparam [3:0] ST_GAP_W1    = 4'd4;
    localparam [3:0] ST_CMD_X     = 4'd5;
    localparam [3:0] ST_SWITCH_1  = 4'd6;
    localparam [3:0] ST_CMD_B1    = 4'd7;
    localparam [3:0] ST_WAIT_1    = 4'd8;
    localparam [3:0] ST_CMD_W2    = 4'd9;
    localparam [3:0] ST_GAP_W2    = 4'd10;
    localparam [3:0] ST_CMD_H1    = 4'd11;
    localparam [3:0] ST_SWITCH_2  = 4'd12;
    localparam [3:0] ST_CMD_B2    = 4'd13;
    localparam [3:0] ST_WAIT_2    = 4'd14;

    localparam [6:0] SEG_0 = 7'b1000000;
    localparam [6:0] SEG_1 = 7'b1111001;
    localparam [6:0] SEG_BLANK = 7'b1111111;

    reg [3:0] state;
    reg [3:0] load_step;
    reg [1:0] sampled_switches;
    reg display_result;
    reg display_valid;
    reg run_result;
    reg run_result_valid;
    reg wait_seen_valid;

    reg key_sync_0;
    reg key_sync_1;
    reg key_stable;
    reg key_prev;
    reg [19:0] debounce_counter;

    wire start_pulse;
    wire tpu_reset;
    wire [15:0] x_value_0;
    wire [15:0] x_value_1;

    reg [15:0] ub_wr_host_data_in_0;
    reg [15:0] ub_wr_host_data_in_1;
    reg ub_wr_host_valid_in_0;
    reg ub_wr_host_valid_in_1;
    reg ub_rd_start_in;
    reg ub_rd_transpose;
    reg [8:0] ub_ptr_select;
    reg [15:0] ub_rd_addr_in;
    reg [15:0] ub_rd_row_size;
    reg [15:0] ub_rd_col_size;
    reg [3:0] vpu_data_pathway;
    reg sys_switch_in;

    wire [15:0] sys_data_out_21;
    wire [15:0] sys_data_out_22;
    wire sys_valid_out_21;
    wire sys_valid_out_22;
    wire [15:0] vpu_data_out_1;
    wire [15:0] vpu_data_out_2;
    wire vpu_valid_out_1;
    wire vpu_valid_out_2;
    wire [15:0] ub_rd_input_data_out_0;
    wire [15:0] ub_rd_input_data_out_1;
    wire ub_rd_input_valid_out_0;
    wire ub_rd_input_valid_out_1;
    wire [15:0] ub_rd_weight_data_out_0;
    wire [15:0] ub_rd_weight_data_out_1;
    wire ub_rd_weight_valid_out_0;
    wire ub_rd_weight_valid_out_1;
    wire [15:0] ub_rd_bias_data_out_0;
    wire [15:0] ub_rd_bias_data_out_1;
    wire [15:0] ub_rd_Y_data_out_0;
    wire [15:0] ub_rd_Y_data_out_1;
    wire [15:0] ub_rd_H_data_out_0;
    wire [15:0] ub_rd_H_data_out_1;
    wire [15:0] ub_rd_col_size_out;
    wire ub_rd_col_size_valid_out;

    assign start_pulse = key_prev & ~key_stable;
    assign tpu_reset = (~KEY[3]) | (state == ST_TPU_RESET);
    assign x_value_0 = sampled_switches[0] ? 16'h0100 : 16'h0000;
    assign x_value_1 = sampled_switches[1] ? 16'h0100 : 16'h0000;

    tpu dut (
        .clk(CLOCK_50),
        .rst(tpu_reset),
        .ub_wr_host_data_in_0(ub_wr_host_data_in_0),
        .ub_wr_host_data_in_1(ub_wr_host_data_in_1),
        .ub_wr_host_valid_in_0(ub_wr_host_valid_in_0),
        .ub_wr_host_valid_in_1(ub_wr_host_valid_in_1),
        .ub_rd_start_in(ub_rd_start_in),
        .ub_rd_transpose(ub_rd_transpose),
        .ub_ptr_select(ub_ptr_select),
        .ub_rd_addr_in(ub_rd_addr_in),
        .ub_rd_row_size(ub_rd_row_size),
        .ub_rd_col_size(ub_rd_col_size),
        .learning_rate_in(16'h00C0),
        .vpu_data_pathway(vpu_data_pathway),
        .sys_switch_in(sys_switch_in),
        .vpu_leak_factor_in(16'h0003),
        .inv_batch_size_times_two_in(16'h0080),
        .sys_data_out_21(sys_data_out_21),
        .sys_data_out_22(sys_data_out_22),
        .sys_valid_out_21(sys_valid_out_21),
        .sys_valid_out_22(sys_valid_out_22),
        .vpu_data_out_1(vpu_data_out_1),
        .vpu_data_out_2(vpu_data_out_2),
        .vpu_valid_out_1(vpu_valid_out_1),
        .vpu_valid_out_2(vpu_valid_out_2),
        .ub_rd_input_data_out_0(ub_rd_input_data_out_0),
        .ub_rd_input_data_out_1(ub_rd_input_data_out_1),
        .ub_rd_input_valid_out_0(ub_rd_input_valid_out_0),
        .ub_rd_input_valid_out_1(ub_rd_input_valid_out_1),
        .ub_rd_weight_data_out_0(ub_rd_weight_data_out_0),
        .ub_rd_weight_data_out_1(ub_rd_weight_data_out_1),
        .ub_rd_weight_valid_out_0(ub_rd_weight_valid_out_0),
        .ub_rd_weight_valid_out_1(ub_rd_weight_valid_out_1),
        .ub_rd_bias_data_out_0(ub_rd_bias_data_out_0),
        .ub_rd_bias_data_out_1(ub_rd_bias_data_out_1),
        .ub_rd_Y_data_out_0(ub_rd_Y_data_out_0),
        .ub_rd_Y_data_out_1(ub_rd_Y_data_out_1),
        .ub_rd_H_data_out_0(ub_rd_H_data_out_0),
        .ub_rd_H_data_out_1(ub_rd_H_data_out_1),
        .ub_rd_col_size_out(ub_rd_col_size_out),
        .ub_rd_col_size_valid_out(ub_rd_col_size_valid_out)
    );

    always @(*) begin
        ub_wr_host_data_in_0 = 16'h0000;
        ub_wr_host_data_in_1 = 16'h0000;
        ub_wr_host_valid_in_0 = 1'b0;
        ub_wr_host_valid_in_1 = 1'b0;
        ub_rd_start_in = 1'b0;
        ub_rd_transpose = 1'b0;
        ub_ptr_select = 9'd0;
        ub_rd_addr_in = 16'd0;
        ub_rd_row_size = 16'd0;
        ub_rd_col_size = 16'd0;
        vpu_data_pathway = 4'b0000;
        sys_switch_in = 1'b0;

        case (state)
            ST_LOAD: begin
                case (load_step)
                    4'd0: begin
                        ub_wr_host_data_in_0 = x_value_0;
                        ub_wr_host_valid_in_0 = 1'b1;
                    end
                    4'd1,
                    4'd2,
                    4'd3: begin
                        ub_wr_host_data_in_0 = x_value_0;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = x_value_1;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    4'd4: begin
                        ub_wr_host_data_in_0 = 16'h0000;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = x_value_1;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    4'd5,
                    4'd6,
                    4'd7: begin
                        ub_wr_host_data_in_0 = 16'h0000;
                        ub_wr_host_valid_in_0 = 1'b1;
                    end
                    4'd8: begin
                        ub_wr_host_data_in_0 = 16'h00E2;
                        ub_wr_host_valid_in_0 = 1'b1;
                    end
                    4'd9: begin
                        ub_wr_host_data_in_0 = 16'hFEEF;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = 16'hFF1E;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    4'd10: begin
                        ub_wr_host_data_in_0 = 16'h0040;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = 16'h0111;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    4'd11: begin
                        ub_wr_host_data_in_0 = 16'h0126;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = 16'h0000;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    4'd12: begin
                        ub_wr_host_data_in_0 = 16'hFFB6;
                        ub_wr_host_valid_in_0 = 1'b1;
                        ub_wr_host_data_in_1 = 16'h0137;
                        ub_wr_host_valid_in_1 = 1'b1;
                    end
                    default: begin
                    end
                endcase
            end
            ST_CMD_W1: begin
                ub_rd_start_in = 1'b1;
                ub_rd_transpose = 1'b1;
                ub_ptr_select = 9'd1;
                ub_rd_addr_in = 16'd12;
                ub_rd_row_size = 16'd2;
                ub_rd_col_size = 16'd2;
            end
            ST_CMD_X: begin
                ub_rd_start_in = 1'b1;
                ub_ptr_select = 9'd0;
                ub_rd_addr_in = 16'd0;
                ub_rd_row_size = 16'd4;
                ub_rd_col_size = 16'd2;
                vpu_data_pathway = 4'b1100;
            end
            ST_SWITCH_1: begin
                vpu_data_pathway = 4'b1100;
                sys_switch_in = 1'b1;
            end
            ST_CMD_B1: begin
                ub_rd_start_in = 1'b1;
                ub_ptr_select = 9'd2;
                ub_rd_addr_in = 16'd16;
                ub_rd_row_size = 16'd4;
                ub_rd_col_size = 16'd2;
                vpu_data_pathway = 4'b1100;
            end
            ST_WAIT_1: begin
                vpu_data_pathway = 4'b1100;
            end
            ST_CMD_W2: begin
                ub_rd_start_in = 1'b1;
                ub_rd_transpose = 1'b1;
                ub_ptr_select = 9'd1;
                ub_rd_addr_in = 16'd18;
                ub_rd_row_size = 16'd1;
                ub_rd_col_size = 16'd2;
                vpu_data_pathway = 4'b1100;
            end
            ST_GAP_W2: begin
                vpu_data_pathway = 4'b1100;
            end
            ST_CMD_H1: begin
                ub_rd_start_in = 1'b1;
                ub_ptr_select = 9'd0;
                ub_rd_addr_in = 16'd21;
                ub_rd_row_size = 16'd4;
                ub_rd_col_size = 16'd2;
                vpu_data_pathway = 4'b1100;
            end
            ST_SWITCH_2: begin
                vpu_data_pathway = 4'b1100;
                sys_switch_in = 1'b1;
            end
            ST_CMD_B2: begin
                ub_rd_start_in = 1'b1;
                ub_ptr_select = 9'd2;
                ub_rd_addr_in = 16'd20;
                ub_rd_row_size = 16'd4;
                ub_rd_col_size = 16'd1;
                vpu_data_pathway = 4'b1100;
            end
            ST_WAIT_2: begin
                vpu_data_pathway = 4'b1100;
            end
            default: begin
            end
        endcase
    end

    always @(posedge CLOCK_50) begin
        if (!KEY[3]) begin
            key_sync_0 <= 1'b1;
            key_sync_1 <= 1'b1;
            key_stable <= 1'b1;
            key_prev <= 1'b1;
            debounce_counter <= 20'd0;
        end else begin
            key_sync_0 <= KEY[0];
            key_sync_1 <= key_sync_0;
            key_prev <= key_stable;

            if (key_sync_1 != key_stable) begin
                if (debounce_counter >= DEBOUNCE_LIMIT - 1) begin
                    key_stable <= key_sync_1;
                    debounce_counter <= 20'd0;
                end else begin
                    debounce_counter <= debounce_counter + 20'd1;
                end
            end else begin
                debounce_counter <= 20'd0;
            end
        end
    end

    always @(posedge CLOCK_50) begin
        if (!KEY[3]) begin
            state <= ST_IDLE;
            load_step <= 4'd0;
            sampled_switches <= 2'b00;
            display_result <= 1'b0;
            display_valid <= 1'b0;
            run_result <= 1'b0;
            run_result_valid <= 1'b0;
            wait_seen_valid <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    load_step <= 4'd0;
                    wait_seen_valid <= 1'b0;
                    run_result_valid <= 1'b0;
                    if (start_pulse) begin
                        sampled_switches <= SW[1:0];
                        run_result <= display_result;
                        state <= ST_TPU_RESET;
                    end
                end
                ST_TPU_RESET: begin
                    load_step <= 4'd0;
                    wait_seen_valid <= 1'b0;
                    run_result_valid <= 1'b0;
                    state <= ST_LOAD;
                end
                ST_LOAD: begin
                    if (load_step == 4'd12) begin
                        load_step <= 4'd0;
                        state <= ST_CMD_W1;
                    end else begin
                        load_step <= load_step + 4'd1;
                    end
                end
                ST_CMD_W1: begin
                    state <= ST_GAP_W1;
                end
                ST_GAP_W1: begin
                    state <= ST_CMD_X;
                end
                ST_CMD_X: begin
                    state <= ST_SWITCH_1;
                end
                ST_SWITCH_1: begin
                    state <= ST_CMD_B1;
                end
                ST_CMD_B1: begin
                    wait_seen_valid <= 1'b0;
                    state <= ST_WAIT_1;
                end
                ST_WAIT_1: begin
                    if (vpu_valid_out_1 || vpu_valid_out_2) begin
                        wait_seen_valid <= 1'b1;
                    end else if (wait_seen_valid) begin
                        wait_seen_valid <= 1'b0;
                        state <= ST_CMD_W2;
                    end
                end
                ST_CMD_W2: begin
                    state <= ST_GAP_W2;
                end
                ST_GAP_W2: begin
                    state <= ST_CMD_H1;
                end
                ST_CMD_H1: begin
                    state <= ST_SWITCH_2;
                end
                ST_SWITCH_2: begin
                    state <= ST_CMD_B2;
                end
                ST_CMD_B2: begin
                    wait_seen_valid <= 1'b0;
                    run_result_valid <= 1'b0;
                    state <= ST_WAIT_2;
                end
                ST_WAIT_2: begin
                    if (vpu_valid_out_1 || vpu_valid_out_2) begin
                        wait_seen_valid <= 1'b1;

                        if (!run_result_valid && vpu_valid_out_1) begin
                            run_result <= (~vpu_data_out_1[15]) && (vpu_data_out_1 != 16'h0000);
                            run_result_valid <= 1'b1;
                        end
                    end else if (wait_seen_valid) begin
                        wait_seen_valid <= 1'b0;
                        display_result <= run_result;
                        display_valid <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    assign HEX0 = display_valid ? (display_result ? SEG_1 : SEG_0) : SEG_BLANK;
    assign HEX1 = SEG_BLANK;
    assign HEX2 = SEG_BLANK;
    assign HEX3 = SEG_BLANK;
    assign HEX4 = SEG_BLANK;
    assign HEX5 = SEG_BLANK;

    assign LEDR[0] = (state != ST_IDLE);
    assign LEDR[1] = display_result;
    assign LEDR[2] = display_valid;
    assign LEDR[3] = start_pulse;
    assign LEDR[9:4] = 6'b000000;
endmodule
