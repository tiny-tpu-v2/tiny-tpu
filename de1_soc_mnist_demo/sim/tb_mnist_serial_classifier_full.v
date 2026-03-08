// ABOUTME: Verifies the serial classifier runs the tracked 784x64x10 MNIST model on one exported sample.
// ABOUTME: Loads the committed weights and sample frame, sends the UART packet, and checks the predicted digit.

`timescale 1ns/1ps
`default_nettype none

module tb_mnist_serial_classifier_full;
    localparam integer CLOCK_HZ = 50000000;
    localparam integer BAUD = 115200;
    localparam integer CLKS_PER_BIT = CLOCK_HZ / BAUD;
    localparam integer PAYLOAD_BYTES = 98;
    localparam W1_INIT_FILE = "../../model/w1_tiled_q8_8.memh";
    localparam B1_INIT_FILE = "../../model/b1_q8_8.memh";
    localparam W2_INIT_FILE = "../../model/w2_tiled_q8_8.memh";
    localparam B2_INIT_FILE = "../../model/b2_q8_8.memh";

    reg clk;
    reg rst;
    reg serial_in;
    reg start_inference;
    wire busy;
    wire done;
    wire [3:0] prediction_out;
    wire frame_loaded_out;
    wire frame_error_out;

    reg [7:0] sample_bytes [0:PAYLOAD_BYTES - 1];
    reg [15:0] expected_hidden [0:63];
    reg [15:0] expected_logits [0:9];
    reg [7:0] checksum;
    integer i;
    integer wait_cycles;
    integer mismatch_index;
    integer label_file;
    integer label_scan;
    integer expected_label_int;
    reg [3:0] expected_label;

    mnist_serial_classifier #(
        .CLOCK_HZ(CLOCK_HZ),
        .BAUD(BAUD),
        .PIXELS(784),
        .PIXEL_ADDR_WIDTH(10),
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
    ) dut (
        .clk(clk),
        .rst(rst),
        .serial_in(serial_in),
        .start_inference(start_inference),
        .busy(busy),
        .done(done),
        .prediction_out(prediction_out),
        .frame_loaded_out(frame_loaded_out),
        .frame_error_out(frame_error_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task drive_byte;
        input [7:0] value;
        integer bit_index;
        begin
            serial_in = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                serial_in = value[bit_index];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            serial_in = 1'b1;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        serial_in = 1'b1;
        start_inference = 1'b0;
        checksum = 8'h00;
        expected_label = 4'd0;
        expected_label_int = 0;

        $readmemh("../../model/sample_image_0.memh", sample_bytes);
        $readmemh("../../model/sample_expected_hidden_0_q8_8.memh", expected_hidden);
        $readmemh("../../model/sample_expected_logits_0_q8_8.memh", expected_logits);
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

        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            checksum = checksum ^ sample_bytes[i];
        end

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        drive_byte(8'hA5);
        drive_byte(8'h5A);
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            drive_byte(sample_bytes[i]);
        end
        drive_byte(checksum);

        wait (frame_loaded_out);
        @(posedge clk);
        start_inference = 1'b1;
        @(posedge clk);
        start_inference = 1'b0;

        wait_cycles = 0;
        begin : wait_for_done
            while (wait_cycles < 2000000) begin
                @(posedge clk);
                #1;
                wait_cycles = wait_cycles + 1;
                if (done) begin
                    disable wait_for_done;
                end
            end
        end

        if (!done) begin
            $display(
                "FAIL: timed out waiting for inference to finish (wait_cycles=%0d state=%0d layer=%0d hidden_tile=%0d output_tile=%0d chunk=%0d)",
                wait_cycles,
                dut.classifier_inst.state,
                dut.classifier_inst.current_layer,
                dut.classifier_inst.hidden_tile_index,
                dut.classifier_inst.output_tile_index,
                dut.classifier_inst.chunk_index
            );
            $finish(1);
        end
        if (frame_error_out) begin
            $display("FAIL: unexpected frame error");
            $finish(1);
        end
        for (mismatch_index = 0; mismatch_index < 64; mismatch_index = mismatch_index + 1) begin
            if (dut.classifier_inst.hidden_buffer[mismatch_index] !== expected_hidden[mismatch_index]) begin
                $display(
                    "FAIL: first hidden mismatch at index %0d expected %h got %h",
                    mismatch_index,
                    expected_hidden[mismatch_index],
                    dut.classifier_inst.hidden_buffer[mismatch_index]
                );
                $finish(1);
            end
        end
        for (mismatch_index = 0; mismatch_index < 10; mismatch_index = mismatch_index + 1) begin
            if (dut.classifier_inst.logits_buffer[mismatch_index] !== expected_logits[mismatch_index]) begin
                $display(
                    "FAIL: first logit mismatch at index %0d expected %h got %h",
                    mismatch_index,
                    expected_logits[mismatch_index],
                    dut.classifier_inst.logits_buffer[mismatch_index]
                );
                $finish(1);
            end
        end
        if (prediction_out !== expected_label) begin
            $display(
                "FAIL: expected prediction %0d got %0d",
                expected_label,
                prediction_out
            );
            $finish(1);
        end

        $display(
            "PASS: mnist_serial_classifier inferred the expected digit %0d on the tracked sample",
            expected_label
        );
        $finish(0);
    end
endmodule
