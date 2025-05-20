module accumulator #(
    parameter int ACC_WIDTH = 4
) (
    input logic clk,
    input logic rst,
    input logic acc_valid_i,
    input logic [15:0] acc_data_in,
    output logic acc_valid_o
);

logic [15:0] acc_mem [0:ACC_WIDTH-1];
logic [15:0] acc_mem_counter;

always @(posedge clk) begin
    if (rst) begin
        acc_mem[0] <= 0;
        acc_mem[1] <= 0;
        acc_mem[2] <= 0;
        acc_mem[3] <= 0;
        acc_mem_counter <= 0;
        acc_valid_o <= 1'b0;
    end else if (acc_valid_i) begin
        if (acc_mem_counter == ACC_WIDTH - 1) begin
            acc_valid_o <= 1'b1;
            acc_mem_counter <= 0;
        end else begin
            acc_mem[acc_mem_counter] <= acc_data_in;
            acc_mem_counter <= acc_mem_counter + 1;
        end
    end else begin
        acc_valid_o <= 1'b0;
    end
end

endmodule