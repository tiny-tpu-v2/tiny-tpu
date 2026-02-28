// ABOUTME: Simplified fixed-point arithmetic modules for synthesis
// ABOUTME: Contains only fxp_add, fxp_mul, and fxp_addsub with default Q8.8 format

`timescale 1ns/1ps
`default_nettype none

// Simple fixed-point addition (Q8.8 format: 8 integer bits, 8 fractional bits)
module fxp_add #(
    parameter WIIA = 8,
    parameter WIFA = 8,
    parameter WIIB = 8,
    parameter WIFB = 8,
    parameter WOI  = 8,
    parameter WOF  = 8,
    parameter ROUND= 1
)(
    input  wire [WIIA+WIFA-1:0] ina,
    input  wire [WIIB+WIFB-1:0] inb,
    output wire [WOI +WOF -1:0] out,
    output wire                 overflow
);

    // Simple addition - assumes same format for inputs and output
    wire signed [WOI+WOF:0] result;
    assign result = $signed(ina) + $signed(inb);

    // Check for overflow
    assign overflow = (result[WOI+WOF] != result[WOI+WOF-1]);

    // Output (saturate on overflow)
    assign out = overflow ?
                 (result[WOI+WOF] ? {1'b1, {(WOI+WOF-1){1'b0}}} : {1'b0, {(WOI+WOF-1){1'b1}}}) :
                 result[WOI+WOF-1:0];

endmodule

// Simple fixed-point multiplication (Q8.8 format)
module fxp_mul #(
    parameter WIIA = 8,
    parameter WIFA = 8,
    parameter WIIB = 8,
    parameter WIFB = 8,
    parameter WOI  = 8,
    parameter WOF  = 8,
    parameter ROUND= 1
)(
    input  wire [WIIA+WIFA-1:0] ina,
    input  wire [WIIB+WIFB-1:0] inb,
    output wire [WOI +WOF -1:0] out,
    output wire                 overflow
);

    // Multiply and shift right by fractional bits
    wire signed [(WIIA+WIFA)+(WIIB+WIFB)-1:0] product;
    wire signed [WOI+WOF-1:0] shifted;

    assign product = $signed(ina) * $signed(inb);

    // Shift right by fractional bits (assuming WIF=WIFB=WOF=8)
    assign shifted = product[(WIFA+WIFB)+:16];

    // Check overflow
    assign overflow = 1'b0; // Simplified - assume no overflow for now
    assign out = shifted;

endmodule

// Simple fixed-point add/subtract (Q8.8 format)
module fxp_addsub #(
    parameter WIIA = 8,
    parameter WIFA = 8,
    parameter WIIB = 8,
    parameter WIFB = 8,
    parameter WOI  = 8,
    parameter WOF  = 8,
    parameter ROUND= 1
)(
    input  wire [WIIA+WIFA-1:0] ina,
    input  wire [WIIB+WIFB-1:0] inb,
    input  wire                 sub, // 0=add, 1=sub
    output wire [WOI +WOF -1:0] out,
    output wire                 overflow
);

    wire signed [WOI+WOF:0] result;

    assign result = sub ?
                    ($signed(ina) - $signed(inb)) :
                    ($signed(ina) + $signed(inb));

    // Check for overflow
    assign overflow = (result[WOI+WOF] != result[WOI+WOF-1]);

    // Output (saturate on overflow)
    assign out = overflow ?
                 (result[WOI+WOF] ? {1'b1, {(WOI+WOF-1){1'b0}}} : {1'b0, {(WOI+WOF-1){1'b1}}}) :
                 result[WOI+WOF-1:0];

endmodule
