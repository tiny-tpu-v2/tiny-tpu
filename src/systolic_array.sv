`timescale 1ps / 1ps

module systolic_array(
    input logic clk,
    input logic reset,
    input logic start,
    input logic load_weight,
    input logic load_input,

    input logic [31:0] w00,
    input logic [31:0] w01,
    input logic [31:0] w10,
    input logic [31:0] w11,
    
    input logic [31:0] a00,
    input logic [31:0] a01,
    input logic [31:0] a10,
    input logic [31:0] a11,

    output logic [31:0] out00,
    output logic [31:0] out01,
    output logic [31:0] out10,
    output logic [31:0] out11,
    output logic done
);

    logic [31:0] in0;
    logic [31:0] in1;
    logic [31:0] out0;
    logic [31:0] out1;

    logic [31:0] pe00_to_pe01;
    logic [31:0] pe00_to_pe10;
    logic [31:0] pe01_to_pe11;
    logic [31:0] pe10_to_pe11;

    logic [31:0] a00_reg;
    logic [31:0] a01_reg;
    logic [31:0] a10_reg;
    logic [31:0] a11_reg;

    logic [31:0] out00_reg;
    logic [31:0] out01_reg;
    logic [31:0] out10_reg;
    logic [31:0] out11_reg;

    logic pe_start;
    reg [7:0] state;

    pe pe00(
        .clk(clk),
        .reset(reset),
        .start(pe_start),
        .load_weight(load_weight),
        .weight_in(w00),
        .input_in(in0),
        .sum_in(0),
        .input_out(pe00_to_pe01),
        .sum_out(pe00_to_pe10)
    );

    pe pe01(
        .clk(clk),
        .reset(reset),
        .start(pe_start),
        .load_weight(load_weight),
        .weight_in(w01),
        .input_in(pe00_to_pe01),
        .sum_in(0),
        .input_out(),
        .sum_out(pe01_to_pe11)
    );

    pe pe10(
        .clk(clk),
        .reset(reset),
        .start(pe_start),
        .load_weight(load_weight),
        .weight_in(w10),
        .input_in(in1),
        .sum_in(pe00_to_pe10),
        .input_out(pe10_to_pe11),
        .sum_out(out0)
    );

    pe pe11(
        .clk(clk),
        .reset(reset),
        .start(pe_start),
        .load_weight(load_weight),
        .weight_in(w11),
        .input_in(pe10_to_pe11),
        .sum_in(pe01_to_pe11),
        .input_out(),
        .sum_out(out1)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // set output registers to 0
            out00 <= 0;
            out01 <= 0;
            out10 <= 0;
            out11 <= 0;

            // set internal registers to 0
            in0 <= 0;
            in1 <= 0;
            a00_reg <= 0;
            a01_reg <= 0;
            a10_reg <= 0;
            a11_reg <= 0;

            out00_reg <= 0;
            out01_reg <= 0;
            out10_reg <= 0;
            out11_reg <= 0;

            state <= 0;
            pe_start <= 0;
            done <= 0;
        end
        else begin
            if(load_input) begin
                a00_reg <= a00;
                a01_reg <= a01;
                a10_reg <= a10;
                a11_reg <= a11;
            end

            if (start && state == 0) begin
                in0 <= a00_reg;
                in1 <= 0;
                state <= 1;
                pe_start <= 1;
            end

            case (state)
                1: begin
                    in0 <= a10_reg;
                    in1 <= a01_reg;
                    state <= 2;
                end
                2: begin
                    in0 <= 0;
                    in1 <= a11_reg;
                    
                    state <= 3;
                end
                3: begin
                    in0 <= 0;
                    in1 <= 0;
                    out00_reg <= out0;
                    
                    state <= 4;
                    
                end
                4: begin
                    in0 <= 0;
                    in1 <= 0;
                    out10_reg <= out0;
                    out01_reg <= out1;
                    
                    state <= 5;
                end
                5: begin
                    in0 <= 0;
                    in1 <= 0;
                    out11_reg <= out1;
                    
                    state <= 6;
                end
                6: begin
                    out00 <= out00_reg;
                    out01 <= out01_reg;
                    out10 <= out10_reg;
                    out11 <= out11_reg;
                    done <= 1;
                    
                    state <= 0;
                    pe_start <= 0;

                    // set internal registers to 0
                    in0 <= 0;
                    in1 <= 0;
                    a00_reg <= 0;
                    a01_reg <= 0;
                    a10_reg <= 0;
                    a11_reg <= 0;

                    out00_reg <= 0;
                    out01_reg <= 0;
                    out10_reg <= 0;
                    out11_reg <= 0;

                    state <= 0;
                end
            endcase
        end
    end
endmodule
