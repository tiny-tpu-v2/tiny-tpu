// ABOUTME: Runs a two-layer inference by chunking input features in pairs through the Tiny-TPU core.
// ABOUTME: Accumulates raw partial sums externally, then applies bias and ReLU to match the trained model.

`timescale 1ns/1ps
`default_nettype none

module mnist_classifier_core #(
    parameter integer PIXELS = 784,
    parameter integer PIXEL_ADDR_WIDTH = 10,
    parameter integer HIDDEN_NEURONS = 64,
    parameter integer HIDDEN_ADDR_WIDTH = 6,
    parameter integer OUTPUT_NEURONS = 10,
    parameter integer OUTPUT_ADDR_WIDTH = 4,
    parameter integer TILE_WIDTH = 2,
    parameter integer UNIFIED_BUFFER_WIDTH = 128
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] pixel_data_in,
    output wire [PIXEL_ADDR_WIDTH - 1:0] pixel_addr_out,
    output reg busy,
    output reg done,
    output reg [3:0] prediction_out
);
    localparam integer HIDDEN_TILES = (HIDDEN_NEURONS + TILE_WIDTH - 1) / TILE_WIDTH;
    localparam integer OUTPUT_TILES = (OUTPUT_NEURONS + TILE_WIDTH - 1) / TILE_WIDTH;

    localparam [4:0] STATE_IDLE = 5'd0;
    localparam [4:0] STATE_TILE_PREP = 5'd1;
    localparam [4:0] STATE_RESET_ASSERT = 5'd2;
    localparam [4:0] STATE_RESET_RELEASE = 5'd3;
    localparam [4:0] STATE_LOAD_INPUT = 5'd4;
    localparam [4:0] STATE_LOAD_WEIGHT = 5'd5;
    localparam [4:0] STATE_START_WEIGHT = 5'd6;
    localparam [4:0] STATE_START_WEIGHT_GAP = 5'd7;
    localparam [4:0] STATE_START_INPUT = 5'd8;
    localparam [4:0] STATE_SWITCH_WEIGHTS = 5'd9;
    localparam [4:0] STATE_WAIT_OUTPUT = 5'd10;
    localparam [4:0] STATE_NEXT_CHUNK = 5'd11;
    localparam [4:0] STATE_FINALIZE_TILE = 5'd12;
    localparam [4:0] STATE_NEXT_TILE = 5'd13;
    localparam [4:0] STATE_ARGMAX = 5'd14;
    localparam [4:0] STATE_DONE = 5'd15;

    reg [4:0] state;
    reg current_layer;
    reg [HIDDEN_ADDR_WIDTH - 1:0] hidden_tile_index;
    reg [OUTPUT_ADDR_WIDTH - 1:0] output_tile_index;
    reg [15:0] chunk_index;
    reg [15:0] input_load_index;
    reg [15:0] weight_load_index;
    reg [15:0] active_tile_outputs;
    reg [15:0] active_input_words;
    reg output_seen_0;
    reg output_seen_1;
    reg tpu_rst;

    reg signed [15:0] partial_out_0;
    reg signed [15:0] partial_out_1;
    reg signed [15:0] accum_0;
    reg signed [15:0] accum_1;

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

    reg signed [15:0] hidden_buffer [0:HIDDEN_NEURONS - 1];
    reg signed [15:0] logits_buffer [0:OUTPUT_NEURONS - 1];
    reg signed [15:0] w1_mem [0:(PIXELS * HIDDEN_NEURONS) - 1];
    reg signed [15:0] b1_mem [0:HIDDEN_NEURONS - 1];
    reg signed [15:0] w2_mem [0:(HIDDEN_NEURONS * OUTPUT_NEURONS) - 1];
    reg signed [15:0] b2_mem [0:OUTPUT_NEURONS - 1];

    integer clear_index;
    integer compare_index;
    integer best_index;
    reg signed [15:0] best_value;

    assign pixel_addr_out = (state == STATE_LOAD_INPUT && !current_layer)
        ? ((chunk_index << 1) + input_load_index)
        : {PIXEL_ADDR_WIDTH{1'b0}};

    tpu_mnist #(
        .SYSTOLIC_ARRAY_WIDTH(2),
        .UNIFIED_BUFFER_WIDTH(UNIFIED_BUFFER_WIDTH)
    ) tpu_inst (
        .clk(clk),
        .rst(tpu_rst),
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
        .learning_rate_in(16'h0001),
        .vpu_data_pathway(4'b0000),
        .sys_switch_in(sys_switch_in),
        .vpu_leak_factor_in(16'h0000),
        .inv_batch_size_times_two_in(16'h0000),
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

    function [15:0] clipped_tile_outputs;
        input integer remaining;
        begin
            if (remaining >= TILE_WIDTH) begin
                clipped_tile_outputs = TILE_WIDTH;
            end else begin
                clipped_tile_outputs = remaining[15:0];
            end
        end
    endfunction

    function [15:0] clipped_input_words;
        input integer remaining;
        begin
            if (remaining >= 2) begin
                clipped_input_words = 16'd2;
            end else begin
                clipped_input_words = remaining[15:0];
            end
        end
    endfunction

    function signed [15:0] sat_add16;
        input signed [15:0] left;
        input signed [15:0] right;
        reg signed [16:0] sum;
        begin
            sum = left + right;
            if (sum > 17'sd32767) begin
                sat_add16 = 16'sh7fff;
            end else if (sum < -17'sd32768) begin
                sat_add16 = -16'sd32768;
            end else begin
                sat_add16 = sum[15:0];
            end
        end
    endfunction

    function signed [15:0] relu16;
        input signed [15:0] value;
        begin
            if (value[15]) begin
                relu16 = 16'sh0000;
            end else begin
                relu16 = value;
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= STATE_IDLE;
            current_layer <= 1'b0;
            hidden_tile_index <= {HIDDEN_ADDR_WIDTH{1'b0}};
            output_tile_index <= {OUTPUT_ADDR_WIDTH{1'b0}};
            chunk_index <= 16'd0;
            input_load_index <= 16'd0;
            weight_load_index <= 16'd0;
            active_tile_outputs <= 16'd0;
            active_input_words <= 16'd0;
            output_seen_0 <= 1'b0;
            output_seen_1 <= 1'b0;
            tpu_rst <= 1'b1;
            partial_out_0 <= 16'h0000;
            partial_out_1 <= 16'h0000;
            accum_0 <= 16'h0000;
            accum_1 <= 16'h0000;
            busy <= 1'b0;
            done <= 1'b0;
            prediction_out <= 4'd0;

            ub_wr_host_data_in_0 <= 16'h0000;
            ub_wr_host_data_in_1 <= 16'h0000;
            ub_wr_host_valid_in_0 <= 1'b0;
            ub_wr_host_valid_in_1 <= 1'b0;
            ub_rd_start_in <= 1'b0;
            ub_rd_transpose <= 1'b0;
            ub_ptr_select <= 9'd0;
            ub_rd_addr_in <= 16'd0;
            ub_rd_row_size <= 16'd0;
            ub_rd_col_size <= 16'd0;
            sys_switch_in <= 1'b0;

            for (clear_index = 0; clear_index < HIDDEN_NEURONS; clear_index = clear_index + 1) begin
                hidden_buffer[clear_index] <= 16'h0000;
            end
            for (clear_index = 0; clear_index < OUTPUT_NEURONS; clear_index = clear_index + 1) begin
                logits_buffer[clear_index] <= 16'h0000;
            end
        end else begin
            done <= 1'b0;
            ub_wr_host_data_in_0 <= 16'h0000;
            ub_wr_host_data_in_1 <= 16'h0000;
            ub_wr_host_valid_in_0 <= 1'b0;
            ub_wr_host_valid_in_1 <= 1'b0;
            ub_rd_start_in <= 1'b0;
            ub_rd_transpose <= 1'b0;
            ub_ptr_select <= 9'd0;
            ub_rd_addr_in <= 16'd0;
            ub_rd_row_size <= 16'd0;
            ub_rd_col_size <= 16'd0;
            sys_switch_in <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    tpu_rst <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        busy <= 1'b1;
                        current_layer <= 1'b0;
                        hidden_tile_index <= {HIDDEN_ADDR_WIDTH{1'b0}};
                        output_tile_index <= {OUTPUT_ADDR_WIDTH{1'b0}};
                        chunk_index <= 16'd0;
                        input_load_index <= 16'd0;
                        weight_load_index <= 16'd0;
                        active_tile_outputs <= clipped_tile_outputs(HIDDEN_NEURONS);
                        active_input_words <= clipped_input_words(PIXELS);
                        output_seen_0 <= 1'b0;
                        output_seen_1 <= 1'b0;
                        partial_out_0 <= 16'h0000;
                        partial_out_1 <= 16'h0000;
                        accum_0 <= 16'h0000;
                        accum_1 <= 16'h0000;
                        tpu_rst <= 1'b1;
                        for (clear_index = 0; clear_index < HIDDEN_NEURONS; clear_index = clear_index + 1) begin
                            hidden_buffer[clear_index] <= 16'h0000;
                        end
                        for (clear_index = 0; clear_index < OUTPUT_NEURONS; clear_index = clear_index + 1) begin
                            logits_buffer[clear_index] <= 16'h0000;
                        end
                        state <= STATE_TILE_PREP;
                    end
                end

                STATE_TILE_PREP: begin
                    input_load_index <= 16'd0;
                    weight_load_index <= 16'd0;
                    output_seen_0 <= 1'b0;
                    output_seen_1 <= 1'b0;
                    partial_out_0 <= 16'h0000;
                    partial_out_1 <= 16'h0000;
                    state <= STATE_RESET_ASSERT;
                end

                STATE_RESET_ASSERT: begin
                    tpu_rst <= 1'b1;
                    state <= STATE_RESET_RELEASE;
                end

                STATE_RESET_RELEASE: begin
                    tpu_rst <= 1'b0;
                    state <= STATE_LOAD_INPUT;
                end

                STATE_LOAD_INPUT: begin
                    if (input_load_index < active_input_words) begin
                        if (!current_layer) begin
                            ub_wr_host_data_in_0 <= pixel_data_in;
                        end else begin
                            ub_wr_host_data_in_0 <= hidden_buffer[(chunk_index << 1) + input_load_index];
                        end
                        ub_wr_host_valid_in_0 <= 1'b1;
                        input_load_index <= input_load_index + 16'd1;
                    end else begin
                        weight_load_index <= 16'd0;
                        state <= STATE_LOAD_WEIGHT;
                    end
                end

                STATE_LOAD_WEIGHT: begin
                    if (weight_load_index < (active_input_words * active_tile_outputs)) begin
                        if (weight_load_index + 1 < (active_input_words * active_tile_outputs)) begin
                            if (!current_layer) begin
                                ub_wr_host_data_in_1 <= w1_mem[(hidden_tile_index * PIXELS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index];
                                ub_wr_host_data_in_0 <= w1_mem[(hidden_tile_index * PIXELS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index + 1];
                            end else begin
                                ub_wr_host_data_in_1 <= w2_mem[(output_tile_index * HIDDEN_NEURONS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index];
                                ub_wr_host_data_in_0 <= w2_mem[(output_tile_index * HIDDEN_NEURONS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index + 1];
                            end
                            ub_wr_host_valid_in_1 <= 1'b1;
                            ub_wr_host_valid_in_0 <= 1'b1;
                            weight_load_index <= weight_load_index + 16'd2;
                        end else begin
                            if (!current_layer) begin
                                ub_wr_host_data_in_0 <= w1_mem[(hidden_tile_index * PIXELS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index];
                            end else begin
                                ub_wr_host_data_in_0 <= w2_mem[(output_tile_index * HIDDEN_NEURONS * TILE_WIDTH) + (chunk_index * 2 * TILE_WIDTH) + weight_load_index];
                            end
                            ub_wr_host_valid_in_0 <= 1'b1;
                            weight_load_index <= weight_load_index + 16'd1;
                        end
                    end else begin
                        state <= STATE_START_WEIGHT;
                    end
                end

                STATE_START_WEIGHT: begin
                    ub_rd_start_in <= 1'b1;
                    ub_ptr_select <= 9'd1;
                    ub_rd_addr_in <= active_input_words;
                    ub_rd_row_size <= active_input_words;
                    ub_rd_col_size <= active_tile_outputs;
                    ub_rd_transpose <= 1'b1;
                    state <= STATE_START_WEIGHT_GAP;
                end

                STATE_START_WEIGHT_GAP: begin
                    state <= STATE_START_INPUT;
                end

                STATE_START_INPUT: begin
                    ub_rd_start_in <= 1'b1;
                    ub_ptr_select <= 9'd0;
                    ub_rd_addr_in <= 16'd0;
                    ub_rd_row_size <= 16'd1;
                    ub_rd_col_size <= active_input_words;
                    ub_rd_transpose <= 1'b0;
                    state <= STATE_SWITCH_WEIGHTS;
                end

                STATE_SWITCH_WEIGHTS: begin
                    sys_switch_in <= 1'b1;
                    output_seen_0 <= 1'b0;
                    output_seen_1 <= 1'b0;
                    partial_out_0 <= 16'h0000;
                    partial_out_1 <= 16'h0000;
                    state <= STATE_WAIT_OUTPUT;
                end

                STATE_WAIT_OUTPUT: begin
                    if (vpu_valid_out_1) begin
                        output_seen_0 <= 1'b1;
                        partial_out_0 <= vpu_data_out_1;
                    end

                    if (active_tile_outputs > 1 && vpu_valid_out_2) begin
                        output_seen_1 <= 1'b1;
                        partial_out_1 <= vpu_data_out_2;
                    end

                    if (!vpu_valid_out_1 && !vpu_valid_out_2 &&
                        output_seen_0 &&
                        ((active_tile_outputs == 1) || output_seen_1)) begin
                        accum_0 <= sat_add16(accum_0, partial_out_0);
                        if (active_tile_outputs > 1) begin
                            accum_1 <= sat_add16(accum_1, partial_out_1);
                        end
                        state <= STATE_NEXT_CHUNK;
                    end
                end

                STATE_NEXT_CHUNK: begin
                    if (!current_layer) begin
                        if (((chunk_index + 1) << 1) < PIXELS) begin
                            chunk_index <= chunk_index + 16'd1;
                            active_input_words <= clipped_input_words(PIXELS - ((chunk_index + 1) * 2));
                            state <= STATE_TILE_PREP;
                        end else begin
                            state <= STATE_FINALIZE_TILE;
                        end
                    end else begin
                        if (((chunk_index + 1) << 1) < HIDDEN_NEURONS) begin
                            chunk_index <= chunk_index + 16'd1;
                            active_input_words <= clipped_input_words(HIDDEN_NEURONS - ((chunk_index + 1) * 2));
                            state <= STATE_TILE_PREP;
                        end else begin
                            state <= STATE_FINALIZE_TILE;
                        end
                    end
                end

                STATE_FINALIZE_TILE: begin
                    if (!current_layer) begin
                        hidden_buffer[hidden_tile_index * TILE_WIDTH] <= relu16(sat_add16(accum_0, b1_mem[hidden_tile_index * TILE_WIDTH]));
                        if (active_tile_outputs > 1) begin
                            hidden_buffer[(hidden_tile_index * TILE_WIDTH) + 1] <= relu16(sat_add16(accum_1, b1_mem[(hidden_tile_index * TILE_WIDTH) + 1]));
                        end
                    end else begin
                        logits_buffer[output_tile_index * TILE_WIDTH] <= sat_add16(accum_0, b2_mem[output_tile_index * TILE_WIDTH]);
                        if (active_tile_outputs > 1) begin
                            logits_buffer[(output_tile_index * TILE_WIDTH) + 1] <= sat_add16(accum_1, b2_mem[(output_tile_index * TILE_WIDTH) + 1]);
                        end
                    end
                    state <= STATE_NEXT_TILE;
                end

                STATE_NEXT_TILE: begin
                    if (!current_layer) begin
                        if (hidden_tile_index + 1 < HIDDEN_TILES) begin
                            hidden_tile_index <= hidden_tile_index + {{(HIDDEN_ADDR_WIDTH - 1){1'b0}}, 1'b1};
                            chunk_index <= 16'd0;
                            input_load_index <= 16'd0;
                            weight_load_index <= 16'd0;
                            active_tile_outputs <= clipped_tile_outputs(HIDDEN_NEURONS - ((hidden_tile_index + 1) * TILE_WIDTH));
                            active_input_words <= clipped_input_words(PIXELS);
                            accum_0 <= 16'h0000;
                            accum_1 <= 16'h0000;
                            state <= STATE_TILE_PREP;
                        end else begin
                            current_layer <= 1'b1;
                            output_tile_index <= {OUTPUT_ADDR_WIDTH{1'b0}};
                            chunk_index <= 16'd0;
                            input_load_index <= 16'd0;
                            weight_load_index <= 16'd0;
                            active_tile_outputs <= clipped_tile_outputs(OUTPUT_NEURONS);
                            active_input_words <= clipped_input_words(HIDDEN_NEURONS);
                            accum_0 <= 16'h0000;
                            accum_1 <= 16'h0000;
                            state <= STATE_TILE_PREP;
                        end
                    end else begin
                        if (output_tile_index + 1 < OUTPUT_TILES) begin
                            output_tile_index <= output_tile_index + {{(OUTPUT_ADDR_WIDTH - 1){1'b0}}, 1'b1};
                            chunk_index <= 16'd0;
                            input_load_index <= 16'd0;
                            weight_load_index <= 16'd0;
                            active_tile_outputs <= clipped_tile_outputs(OUTPUT_NEURONS - ((output_tile_index + 1) * TILE_WIDTH));
                            active_input_words <= clipped_input_words(HIDDEN_NEURONS);
                            accum_0 <= 16'h0000;
                            accum_1 <= 16'h0000;
                            state <= STATE_TILE_PREP;
                        end else begin
                            state <= STATE_ARGMAX;
                        end
                    end
                end

                STATE_ARGMAX: begin
                    best_index = 0;
                    best_value = logits_buffer[0];
                    for (compare_index = 1; compare_index < OUTPUT_NEURONS; compare_index = compare_index + 1) begin
                        if ($signed(logits_buffer[compare_index]) > $signed(best_value)) begin
                            best_index = compare_index;
                            best_value = logits_buffer[compare_index];
                        end
                    end
                    prediction_out <= best_index[3:0];
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
