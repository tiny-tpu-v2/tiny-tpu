`timescale 1ns/1ps
`default_nettype none

module unified_buffer #(
    parameter int UNIFIED_BUFFER_WIDTH = 50
)(
    input  logic        clk,
    input  logic        rst,
    
    // write interface
    input  logic [15:0] ub_write_data_1_in,
    input  logic [15:0] ub_write_data_2_in,
    input  logic        ub_write_valid_1_in,
    input  logic        ub_write_valid_2_in,
    
    // ISA control signals
    input  logic        ub_write_start_in,        // determines if we are writing
    input  logic        ub_read_start_in,         // supplied from assembly code (determines if we start reading)
    input  logic        ub_transpose,         // read row or column (WE STILL NEED TO IMPLEMENT THIS FEATURE)
    input  logic [5:0]  ub_read_addr_in,          // address decoded from isa
    input  logic [5:0]  ub_num_mem_locations_in,  // number of memory locations/cells to increment by (HAS TO BE A MULTIPLE OF 2)
    
    // read interface
    output logic [15:0] ub_data_1_out,
    output logic [15:0] ub_data_2_out,
    output logic        ub_valid_1_out,
    output logic        ub_valid_2_out
);

    // internal memory array
    logic [15:0] ub_memory [UNIFIED_BUFFER_WIDTH-1:0];
    
    // internal pointers and counters
    logic [5:0] wr_ptr;                    // write pointer
    logic [5:0] rd_ptr;                    // read pointer
    logic [5:0] rd_num_locations_left;     // remaining locations to read
    
    // read state machine
    typedef enum logic [1:0] {
        READ_IDLE    = 2'b00,
        READ_ACTIVE  = 2'b10
    } read_state_t;
    
    read_state_t read_state, read_state_next;


    // combinational logic for read state machine
    always_comb begin
        case (read_state)
            READ_IDLE: begin
                if (ub_read_start_in) begin
                    read_state_next = READ_ACTIVE;
                end else begin
                    read_state_next = READ_IDLE;
                end
            end
            
            READ_ACTIVE: begin
                if (rd_num_locations_left <= 1) begin 
                    read_state_next = READ_IDLE;
                end else begin
                    read_state_next = READ_ACTIVE;
                end
            end
            
            default: begin
                read_state_next = READ_IDLE; // goes to here once rd_num_locations_left is zero. 
            end
        endcase
    end

    // sequential logic
    always @(posedge clk or posedge rst) begin

        if (rst) begin
            // reset all registers
            wr_ptr                <= '0;
            rd_ptr                <= '0;
            rd_num_locations_left <= '0;
            read_state            <= READ_IDLE;
            
            // clear output registers
            ub_data_1_out         <= '0;
            ub_data_2_out         <= '0;
            ub_valid_1_out        <= '0;
            ub_valid_2_out        <= '0;
            
            // clear memory array
            for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin
                ub_memory[i] <= '0;
            end
        end 

        else begin
            // update read state machine
            read_state <= read_state_next;
            
            // reading logic
            case (read_state)
                READ_IDLE: begin
                    if (ub_read_start_in) begin
                        // NOTICE that this is staggered. the last value should be written to ub_data_1_out
                        // first cycle of reading - output first ONE mem location (staggered)
                        // here we don't need to tranpose the first or last element
                        // in the future, we can latch our tranpose signal in this cycle, and then use
                        // the saved value for future signals
                        ub_data_1_out         <= ub_memory[ub_read_addr_in];
                        ub_data_2_out         <= '0;
                        ub_valid_1_out        <= 1'b1;
                        ub_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        rd_ptr                <= ub_read_addr_in + 1;
                        rd_num_locations_left <= ub_num_mem_locations_in - 1;
                    end else begin
                        ub_valid_1_out        <= 1'b0;
                        ub_valid_2_out        <= 1'b0;
                    end
                end
                
                READ_ACTIVE: begin
                    if (rd_num_locations_left > 1) begin 

                        // perhaps write logic here to use ub_transpose flag to determine if we want to transpose


                        // read two more locations
                        if (ub_transpose) begin // IF WE WANT TO TRANSPOSE (ub_transpose is high)
                            ub_data_1_out         <= ub_memory[rd_ptr]; // LINE A
                            ub_data_2_out         <= ub_memory[rd_ptr + 1]; 
                       
                        end else begin  // IF WE DON'T WANT TO TRANSPOSE (ub_transpose is low)
                            ub_data_1_out         <= ub_memory[rd_ptr + 1]; // LINE A
                            ub_data_2_out         <= ub_memory[rd_ptr]; 
                        end

                        ub_valid_1_out        <= 1'b1;
                        ub_valid_2_out        <= 1'b1;
        
                        // update pointers
                        rd_ptr                <= rd_ptr + 2;
                        rd_num_locations_left <= rd_num_locations_left - 2;
                        
                    end else if (rd_num_locations_left == 1) begin
                        // read last single location
                        // NOTICE that this is staggered. the last value should be written to ub_data_2_out
                        // here we don't need to tranpose the first or last element
                        ub_data_1_out         <= '0;
                        ub_data_2_out         <= ub_memory[rd_ptr];
                        ub_valid_1_out        <= 1'b0;
                        ub_valid_2_out        <= 1'b1;
                         
                        // clear counters
                        rd_num_locations_left <= '0;
                        
                    end else begin
                        // no more data to read
                        ub_valid_1_out        <= 1'b0;
                        ub_valid_2_out        <= 1'b0;
                    end
                end
                
                default: begin
                    ub_valid_1_out            <= 1'b0;
                    ub_valid_2_out            <= 1'b0;
                end
            endcase
            
            // writing INTO unified buffer logic (can run concurrently with reading)
            if (ub_write_start_in) begin
                if (ub_write_valid_1_in && ub_write_valid_2_in) begin
                    // write both data inputs
                    ub_memory[wr_ptr+1]     <= ub_write_data_1_in;
                    ub_memory[wr_ptr] <= ub_write_data_2_in;
                    wr_ptr                <= wr_ptr + 2;
                    
                end else if (ub_write_valid_1_in) begin
                    // write only first data input
                    ub_memory[wr_ptr]     <= ub_write_data_1_in;
                    wr_ptr                <= wr_ptr + 1;
                    
                end else if (ub_write_valid_2_in) begin
                    // write only second data input
                    ub_memory[wr_ptr]     <= ub_write_data_2_in;
                    wr_ptr                <= wr_ptr + 1;
                end
            end
        end
    end
endmodule


