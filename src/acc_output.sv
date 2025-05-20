// TODO: Add streaming output functionality to the acc_output module

module acc_output #(
    parameter int ACC_WIDTH = 4 // This equals the size of the systolic array that we decide to use (if the systolic array is 4x4, then ACC_WIDTH = 4)
) (
    input logic clk,
    input logic rst,

    // Input Flags
    input logic acc_valid_i,

    // Streaming Input Data
    input logic [15:0] acc_data_in,
    
    // Output Flags
    output logic acc_valid_o,

    // Batch Output Data
    output logic [15:0] acc_mem_out [0:ACC_WIDTH-1]
);

logic [15:0] acc_mem_reg [0:ACC_WIDTH-1];
logic [15:0] acc_mem_counter;


always @(posedge clk) begin
    for (int i = 0; i < ACC_WIDTH; i++) begin
        $dumpvars(0, acc_mem_reg[i]);
        $dumpvars(0, acc_mem_out[i]);
    end
    if (rst) begin
        // Set internal and output registers to 0
        for (int i = 0; i < ACC_WIDTH; i++) begin
            acc_mem_reg[i] <= 0;
            acc_mem_out[i] <= 0;
        end
        acc_mem_counter <= 0;
        acc_valid_o <= 1'b0;
        
    end 
    else if (acc_valid_i && !acc_valid_o) begin
        acc_mem_reg[acc_mem_counter] <= acc_data_in;
        acc_mem_counter <= acc_mem_counter + 1;
        
        // Set outputs to 0
        for (int i = 0; i < ACC_WIDTH; i++) begin
            acc_mem_out[i] <= 0;
        end

    end else begin
        if (acc_mem_counter > 0) begin                      // When everything is stored in the registers, automatically set load the registers to the output ports
            acc_valid_o <= 1'b1;
            acc_mem_counter <= 0;
            for (int i = 0; i < ACC_WIDTH; i++) begin
                acc_mem_out[i] <= acc_mem_reg[i];
            end
        end else begin
            acc_valid_o <= 1'b0;
        end
    end
end

endmodule