module acc_input #(
    parameter int ACC_WIDTH = 1
) (
    input logic clk,
    input logic rst,

    // Input flags
    input logic acc_load_i,
    input logic acc_valid_i,

    // Batch Input Data
    input logic [15:0] acc_data_in [0:ACC_WIDTH-1],

    // Output flags
    output logic acc_valid_o,

    // Streaming Output Data
    output logic [15:0] acc_data_out
);

logic [15:0] acc_mem_reg [0:ACC_WIDTH-1];
logic [15:0] acc_mem_counter;                   // Maybe replace the counter with a bit shift (this is basically a queue)

always @(posedge clk) begin
    for (int i = 0; i < ACC_WIDTH; i++) begin
        $dumpvars(0, acc_mem_reg[i]);
        $dumpvars(0, acc_data_in[i]);
    end

    if (rst) begin
        for (int i = 0; i < ACC_WIDTH; i++) begin
            acc_mem_reg[i] <= 0;
            acc_data_out <= 0;
            acc_valid_o <= 0;
            acc_mem_counter <= 0;
        end
    end
    else if (acc_load_i) begin
        acc_mem_counter <= 0;
        for (int i = 0; i < ACC_WIDTH; i++) begin
            acc_mem_reg[i] <= acc_data_in[i];
        end
    end
    else if (acc_valid_i) begin
        acc_data_out <= acc_mem_reg[acc_mem_counter];
        acc_mem_counter <= acc_mem_counter + 1;
        acc_valid_o <= 1'b1;
    end
    
    else begin
        
        acc_valid_o <= 1'b0;
        acc_data_out <= 0;
        acc_mem_counter <= 0;
    end
end

endmodule