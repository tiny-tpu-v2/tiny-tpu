// ABOUTME: Verifies the JTAG MMIO ingress path driving the real classifier core on the tracked MNIST sample.
// ABOUTME: Writes the 28x28 image through MMIO registers, starts inference, and checks the expected prediction.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_jtag_classifier;
    localparam integer PIXELS = 784;
    localparam integer PIXEL_ADDR_WIDTH = 10;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer MAX_WAIT_CYCLES = 2000000;
    localparam [31:0] IMAGE_BASE = 32'h00000100;
    localparam W1_INIT_FILE = "../../model/w1_tiled_q8_8.memh";
    localparam B1_INIT_FILE = "../../model/b1_q8_8.memh";
    localparam W2_INIT_FILE = "../../model/w2_tiled_q8_8.memh";
    localparam B2_INIT_FILE = "../../model/b2_q8_8.memh";

    reg clk;
    reg rst;
    reg [31:0] avs_address;
    reg avs_read;
    reg avs_write;
    reg [31:0] avs_writedata;
    reg [3:0] avs_byteenable;
    wire [31:0] avs_readdata;
    wire avs_readdatavalid;
    wire avs_waitrequest;

    wire classifier_busy;
    wire classifier_done;
    wire [3:0] classifier_prediction;
    wire [PIXEL_ADDR_WIDTH - 1:0] pixel_addr;
    wire [15:0] pixel_data;
    wire start_pulse;
    wire frame_loaded;
    wire done_sticky;
    wire write_while_busy;
    wire [3:0] prediction_latched;

    reg [7:0] sample_bytes [0:(PIXELS / 8) - 1];
    integer pixel_index;
    integer wait_cycles;
    reg [31:0] status_value;
    reg [31:0] result_value;
    integer label_file;
    integer label_scan;
    integer expected_label_int;
    reg [3:0] expected_label;

    mnist_jtag_mmio #(
        .PIXELS(PIXELS),
        .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
        .IMAGE_BASE_ADDR(IMAGE_BASE)
    ) mmio_inst (
        .clk(clk),
        .rst(rst),
        .avs_address(avs_address),
        .avs_read(avs_read),
        .avs_write(avs_write),
        .avs_writedata(avs_writedata),
        .avs_byteenable(avs_byteenable),
        .avs_readdata(avs_readdata),
        .avs_readdatavalid(avs_readdatavalid),
        .avs_waitrequest(avs_waitrequest),
        .busy_in(classifier_busy),
        .done_in(classifier_done),
        .prediction_in(classifier_prediction),
        .pixel_addr_in(pixel_addr),
        .pixel_data_out(pixel_data),
        .start_pulse_out(start_pulse),
        .frame_loaded_out(frame_loaded),
        .done_sticky_out(done_sticky),
        .write_while_busy_out(write_while_busy),
        .prediction_latched_out(prediction_latched)
    );

    mnist_classifier_core #(
        .PIXELS(PIXELS),
        .PIXEL_ADDR_WIDTH(PIXEL_ADDR_WIDTH),
        .HIDDEN_NEURONS(64),
        .HIDDEN_ADDR_WIDTH(6),
        .OUTPUT_NEURONS(10),
        .OUTPUT_ADDR_WIDTH(4),
        .TILE_WIDTH(2),
        .UNIFIED_BUFFER_WIDTH(128),
        .PRELOAD_MODEL(1),
        .W1_INIT_FILE(W1_INIT_FILE),
        .B1_INIT_FILE(B1_INIT_FILE),
        .W2_INIT_FILE(W2_INIT_FILE),
        .B2_INIT_FILE(B2_INIT_FILE)
    ) classifier_inst (
        .clk(clk),
        .rst(rst),
        .start(start_pulse),
        .pixel_data_in(pixel_data),
        .pixel_addr_out(pixel_addr),
        .busy(classifier_busy),
        .done(classifier_done),
        .prediction_out(classifier_prediction)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write32;
        input [31:0] addr;
        input [31:0] value;
        begin
            @(posedge clk);
            avs_address <= addr;
            avs_writedata <= value;
            avs_byteenable <= 4'h1;
            avs_write <= 1'b1;
            avs_read <= 1'b0;
            @(posedge clk);
            avs_write <= 1'b0;
            avs_address <= 32'h0;
            avs_writedata <= 32'h0;
        end
    endtask

    task read32;
        input [31:0] addr;
        output [31:0] value;
        begin
            @(posedge clk);
            avs_address <= addr;
            avs_read <= 1'b1;
            avs_write <= 1'b0;
            @(posedge clk);
            avs_read <= 1'b0;
            avs_address <= 32'h0;
            wait (avs_readdatavalid);
            value = avs_readdata;
        end
    endtask

    initial begin
        rst = 1'b1;
        avs_address = 32'h0;
        avs_read = 1'b0;
        avs_write = 1'b0;
        avs_writedata = 32'h0;
        avs_byteenable = 4'h1;
        expected_label = 4'd0;
        expected_label_int = 0;

        $readmemh("../../model/sample_image_0.memh", sample_bytes);
        label_file = $fopen("../../model/sample_expected_prediction_0.txt", "r");
        if (label_file == 0) begin
            $display("FAIL: could not open expected prediction file");
            $finish(1);
        end
        label_scan = $fscanf(label_file, "%d", expected_label_int);
        $fclose(label_file);
        if (label_scan != 1 || expected_label_int < 0 || expected_label_int > 15) begin
            $display("FAIL: malformed expected prediction value %0d", expected_label_int);
            $finish(1);
        end
        expected_label = expected_label_int[3:0];

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        for (pixel_index = 0; pixel_index < PIXELS; pixel_index = pixel_index + 1) begin
            write32(
                IMAGE_BASE + (pixel_index * 4),
                sample_bytes[pixel_index / 8][pixel_index % 8]
            );
        end

        if (!frame_loaded) begin
            $display("FAIL: frame_loaded should be high after image writes");
            $finish(1);
        end

        write32(32'h00000000, 32'h00000001);

        wait_cycles = 0;
        begin : wait_for_done
            while (wait_cycles < MAX_WAIT_CYCLES) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
                if (classifier_done) begin
                    disable wait_for_done;
                end
            end
        end

        if (!classifier_done) begin
            $display(
                "FAIL: timed out waiting for done after %0d cycles (state=%0d layer=%0d chunk=%0d)",
                wait_cycles,
                classifier_inst.state,
                classifier_inst.current_layer,
                classifier_inst.chunk_index
            );
            $finish(1);
        end

        read32(32'h00000004, status_value);
        read32(32'h00000008, result_value);

        if (!(status_value & 32'h2)) begin
            $display("FAIL: done bit not set in status register: %h", status_value);
            $finish(1);
        end
        if (write_while_busy) begin
            $display("FAIL: write_while_busy should remain low in nominal flow");
            $finish(1);
        end
        if ((result_value[3:0] != expected_label) || (prediction_latched != expected_label)) begin
            $display(
                "FAIL: prediction mismatch expected=%0d result_reg=%0d latched=%0d classifier=%0d",
                expected_label,
                result_value[3:0],
                prediction_latched,
                classifier_prediction
            );
            $finish(1);
        end

        $display(
            "PASS: jtag mmio + classifier predicted expected digit %0d (cycles=%0d)",
            expected_label,
            wait_cycles
        );
        $finish(0);
    end
endmodule
