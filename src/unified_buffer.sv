`timescale 1ns/1ps
`default_nettype none

module unified_buffer #(
    parameter int UNIFIED_BUFFER_WIDTH = 50
)(
    input  logic        clk,
    input  logic        rst,
    
    // WRITING!!!
    // inputs from VPU to UB
    input  logic        ub_wr_addr_valid_in,
    input  logic [5:0]  ub_wr_addr_in,          // address to start at

    // inputs from VPU to UB
    input  logic [15:0] ub_wr_data_in_1, 
    input  logic [15:0] ub_wr_data_in_2, 
    input  logic        ub_wr_valid_data_in_1, 
    input  logic        ub_wr_valid_data_in_2, 

    // model data from host to UB (put in weights, inputs, biases, and outputs Y) THERE IS DATA CONTENTION HERE IF WE HAVE DRAM BUT FOR SIMPLICITY OF DESIGN WE WILL ALL NECESSARY VALUES
    input  logic [15:0] ub_wr_host_data_in_1, 
    input  logic [15:0] ub_wr_host_data_in_2, 
    input  logic        ub_wr_host_valid_in_1, 
    input  logic        ub_wr_host_valid_in_2, 
    
    
    // READING!!!!
    // read interface for left inputs (X's, H's, or dL/dZ^T) from UB to systolic array
    input  logic        ub_rd_input_transpose,         // FLAG EXCLUSIVE TO LEFT SIDE OF SYSTOLIC ARRAY
    input  logic        ub_rd_input_start_in,
    input  logic [5:0]  ub_rd_input_addr_in,
    input  logic [5:0]  ub_rd_input_loc_in,

    // outputs for left inputs (X's, H's, or dL/dZ^T) from UB to systolic array
    output logic [15:0] ub_rd_input_data_1_out,
    output logic [15:0] ub_rd_input_data_2_out,
    output logic        ub_rd_input_valid_1_out,
    output logic        ub_rd_input_valid_2_out,

    // read interface for weights (W^T, W or H aka top inputs) from UB to systolic array
    input  logic        ub_rd_weight_transpose,
    input  logic        ub_rd_weight_start_in,
    input  logic [5:0]  ub_rd_weight_addr_in,
    input  logic [5:0]  ub_rd_weight_loc_in,

    // outputs for weights (W^T or H aka top inputs) from UB to systolic array
    output logic [15:0] ub_rd_weight_data_1_out,
    output logic [15:0] ub_rd_weight_data_2_out,
    output logic        ub_rd_weight_valid_1_out,
    output logic        ub_rd_weight_valid_2_out,
    
    // bias read interface for biases from UB to VPU bias module
    input  logic        ub_rd_bias_start_in,
    input  logic [5:0]  ub_rd_bias_addr_in,
    input  logic [5:0]  ub_rd_bias_loc_in,
    
    // outputs for biases from UB to VPU bias module
    output logic [15:0] ub_rd_bias_data_1_out,
    output logic [15:0] ub_rd_bias_data_2_out,
    output logic        ub_rd_bias_valid_1_out,
    output logic        ub_rd_bias_valid_2_out,
    
    // loss read interface for Y's from UB to VPU loss module
    input  logic        ub_rd_Y_start_in,
    input  logic [5:0]  ub_rd_Y_addr_in,
    input  logic [5:0]  ub_rd_Y_loc_in,

    // outputs for outputs (Y's) from UB to VPU loss module
    output logic [15:0] ub_rd_Y_data_1_out,
    output logic [15:0] ub_rd_Y_data_2_out,
    output logic        ub_rd_Y_valid_1_out,
    output logic        ub_rd_Y_valid_2_out,

    // activation derivative read interface for H's from UB to VPU activation derivative module
    input  logic        ub_rd_H_start_in,
    input  logic [5:0]  ub_rd_H_addr_in,
    input  logic [5:0]  ub_rd_H_loc_in,

    // outputs for H's from UB to VPU activation derivative module
    output logic [15:0] ub_rd_H_data_1_out,
    output logic [15:0] ub_rd_H_data_2_out,
    output logic        ub_rd_H_valid_1_out,
    output logic        ub_rd_H_valid_2_out
);

    // internal memory array
    logic [15:0] ub_memory [0:UNIFIED_BUFFER_WIDTH-1];
    
    // internal pointers and counters
    logic [5:0] wr_ptr;                         // write pointer (from VPU to UB and host to UB)

    logic [5:0] wr_num_locations_left;          // remaining locations to write to
    
    logic [5:0] rd_input_ptr;                    // read pointer for UB to left side inputs of systolic array
    logic [5:0] rd_input_num_locations_left;     // remaining locations to read

    // pointers and counters for bias (read only)
    logic [5:0] rd_bias_ptr;
    logic [5:0] rd_bias_num_output_left;
    logic [5:0] rd_bias_address;

    // pointers and counters for activation (read only)
    logic [5:0] rd_weight_ptr;
    logic [5:0] rd_weight_num_locations_left;
    logic rd_weight_transpose;

    // pointers and counters for loss (read only)
    logic [5:0] rd_Y_ptr;
    logic [5:0] rd_Y_num_locations_left;

    // pointers and counters for activation derivative (read only)
    logic [5:0] rd_H_ptr;
    logic [5:0] rd_H_num_locations_left;

    
    // read state machine
    typedef enum logic [1:0] {
        READ_IDLE    = 2'b00,
        READ_ACTIVE  = 2'b10
    } read_write_state_t;


    typedef enum logic [1:0] {
        FIRST_COL               = 2'b00,
        FIRST_AND_SECOND_COL    = 2'b01,
        SECOND_COL              = 2'b10
    } bias_state_t;
    
    read_write_state_t rd_input_state, rd_input_state_next;
    
    // bias read state machine
    bias_state_t rd_bias_state, rd_bias_state_next;
    
    // activation read state machine 
    read_write_state_t rd_weight_state, rd_weight_state_next;
    
    // loss read state machine
    read_write_state_t rd_Y_state, rd_Y_state_next;
    
    // activation derivative read state machine
    read_write_state_t rd_H_state, rd_H_state_next;


    // combinational logic for read state machine
    always_comb begin
        case (rd_input_state)
            READ_IDLE: begin
                if (ub_rd_input_start_in) begin
                    rd_input_state_next = READ_ACTIVE;
                end else begin
                    rd_input_state_next = READ_IDLE;
                end
            end
            
            READ_ACTIVE: begin
                if (rd_input_num_locations_left <= 1) begin 
                    rd_input_state_next = READ_IDLE;
                end else begin
                    rd_input_state_next = READ_ACTIVE;
                end
            end
            
            default: begin
                rd_input_state_next = READ_IDLE; // goes to here once rd_input_num_locations_left is zero. 
            end
        endcase
    end


    //combinational logic for bias read state machine
    always_comb begin
        case (rd_bias_state)
            FIRST_COL: begin
                if (ub_rd_bias_start_in) begin
                    rd_bias_state_next = FIRST_AND_SECOND_COL;
                end else begin
                    rd_bias_state_next = FIRST_COL;
                end
            end
            
            FIRST_AND_SECOND_COL: begin
                if (rd_bias_num_output_left <= 1) begin 
                    rd_bias_state_next = SECOND_COL;
                end else begin
                    rd_bias_state_next = FIRST_AND_SECOND_COL;
                end
            end

            SECOND_COL: begin
                if (rd_bias_num_output_left <= 1) begin 
                    rd_bias_state_next = FIRST_COL;
                end else begin
                    rd_bias_state_next = FIRST_AND_SECOND_COL;
                end
            end
            
            default: begin
                rd_bias_state_next = FIRST_COL;
            end
        endcase
    end

    // combinational logic for activation read state machine
    always_comb begin
        case (rd_weight_state)
            READ_IDLE: begin
                if (ub_rd_weight_start_in) begin
                    rd_weight_state_next = READ_ACTIVE;
                    rd_weight_transpose = ub_rd_weight_transpose;
                end else begin
                    rd_weight_state_next = READ_IDLE;
                end
            end
            
            READ_ACTIVE: begin
                if (rd_weight_num_locations_left <= 1) begin 
                    rd_weight_state_next = READ_IDLE;
                end else begin
                    rd_weight_state_next = READ_ACTIVE;
                end
            end
            
            default: begin
                rd_weight_state_next = READ_IDLE;
            end
        endcase
    end

    // combinational logic for loss read state machine
    always_comb begin
        case (rd_Y_state)
            READ_IDLE: begin
                if (ub_rd_Y_start_in) begin
                    rd_Y_state_next = READ_ACTIVE;
                end else begin
                    rd_Y_state_next = READ_IDLE;
                end
            end
            
            READ_ACTIVE: begin
                if (rd_Y_num_locations_left <= 1) begin 
                    rd_Y_state_next = READ_IDLE;
                end else begin
                    rd_Y_state_next = READ_ACTIVE;
                end
            end
            
            default: begin
                rd_Y_state_next = READ_IDLE;
            end
        endcase
    end

    // combinational logic for activation derivative read state machine
    always_comb begin
        case (rd_H_state)
            READ_IDLE: begin
                if (ub_rd_H_start_in) begin
                    rd_H_state_next = READ_ACTIVE;
                end else begin
                    rd_H_state_next = READ_IDLE;
                end
            end
            
            READ_ACTIVE: begin
                if (rd_H_num_locations_left <= 1) begin 
                    rd_H_state_next = READ_IDLE;
                end else begin
                    rd_H_state_next = READ_ACTIVE;
                end
            end
            
            default: begin
                rd_H_state_next = READ_IDLE;
            end
        endcase
    end

    // sequential logic
    always @(posedge clk or posedge rst) begin

        for (int i = 0; i < 30; i++) begin
            $dumpvars(0, ub_memory[i]);
        end

        if (rst) begin
            // reset all registers
            wr_ptr                <= '0;
            rd_input_ptr                <= '0;
            rd_input_num_locations_left <= '0;
            rd_input_state            <= READ_IDLE;
            
            // reset bias pointers and state (read only)
            rd_bias_ptr                <= '0;
            rd_bias_num_output_left <= '0;
            rd_bias_state            <= READ_IDLE;
            
            // reset activation pointers and state (read only)
            rd_weight_ptr                <= '0;
            rd_weight_num_locations_left <= '0;
            rd_weight_state            <= READ_IDLE;
            
            // reset loss pointers and state (read only)
            rd_Y_ptr                <= '0;
            rd_Y_num_locations_left <= '0;
            rd_Y_state            <= READ_IDLE;
            
            // reset activation derivative pointers and state (read only)
            rd_H_ptr                <= '0;
            rd_H_num_locations_left <= '0;
            rd_H_state            <= READ_IDLE;
            
            // clear output registers
            ub_rd_input_data_1_out         <= '0;
            ub_rd_input_data_2_out         <= '0;
            ub_rd_input_valid_1_out        <= '0;
            ub_rd_input_valid_2_out        <= '0;
            
            // clear bias output registers
            ub_rd_bias_data_1_out    <= '0;
            ub_rd_bias_data_2_out    <= '0;
            ub_rd_bias_valid_1_out   <= '0;
            ub_rd_bias_valid_2_out   <= '0;
            
            // clear activation output registers
            ub_rd_weight_data_1_out    <= '0;
            ub_rd_weight_data_2_out    <= '0;
            ub_rd_weight_valid_1_out   <= '0;
            ub_rd_weight_valid_2_out   <= '0;
            
            // clear loss output registers
            ub_rd_Y_data_1_out    <= '0;
            ub_rd_Y_data_2_out    <= '0;
            ub_rd_Y_valid_1_out   <= '0;
            ub_rd_Y_valid_2_out   <= '0;
            
            // clear activation derivative output registers
            ub_rd_H_data_1_out    <= '0;
            ub_rd_H_data_2_out    <= '0;
            ub_rd_H_valid_1_out   <= '0;
            ub_rd_H_valid_2_out   <= '0;
            
            // clear memory array
            for (int i = 0; i < UNIFIED_BUFFER_WIDTH; i++) begin
                ub_memory[i] <= '0;
            end
        end else begin

            // READING LOGIC:
            // update read state machines
            rd_input_state <= rd_input_state_next;
            rd_bias_state <= rd_bias_state_next;
            rd_weight_state <= rd_weight_state_next;
            rd_Y_state <= rd_Y_state_next;
            rd_H_state <= rd_H_state_next;
            
            // reading logic
            case (rd_input_state)
                READ_IDLE: begin
                    if (ub_rd_input_start_in) begin
                        // NOTICE that this is staggered. the last value should be written to ub_rd_input_data_1_out
                        // first cycle of reading - output first ONE mem location (staggered)
                        // here we don't need to tranpose the first or last element
                        // in the future, we can latch our tranpose signal in this cycle, and then use
                        // the saved value for future signals
                        ub_rd_input_data_1_out         <= ub_memory[ub_rd_input_addr_in];
                        ub_rd_input_data_2_out         <= '0;
                        ub_rd_input_valid_1_out        <= 1'b1;
                        ub_rd_input_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        rd_input_ptr                <= ub_rd_input_addr_in + 1;
                        rd_input_num_locations_left <= ub_rd_input_loc_in - 1;
                    end else begin
                        ub_rd_input_valid_1_out        <= 1'b0;
                        ub_rd_input_valid_2_out        <= 1'b0;
                    end
                end
                
                READ_ACTIVE: begin
                    if (rd_input_num_locations_left > 1) begin 

                        // perhaps write logic here to use ub_rd_input_transpose flag to determine if we want to transpose


                        // read two more locations
                        if (ub_rd_input_transpose) begin // IF WE WANT TO TRANSPOSE (ub_rd_input_transpose is high)
                            ub_rd_input_data_1_out         <= ub_memory[rd_input_ptr]; // LINE A
                            ub_rd_input_data_2_out         <= ub_memory[rd_input_ptr + 1]; 
                       
                        end else begin  // IF WE DON'T WANT TO TRANSPOSE (ub_rd_input_transpose is low)
                            ub_rd_input_data_1_out         <= ub_memory[rd_input_ptr + 1]; // LINE A
                            ub_rd_input_data_2_out         <= ub_memory[rd_input_ptr]; 
                        end

                        ub_rd_input_valid_1_out        <= 1'b1;
                        ub_rd_input_valid_2_out        <= 1'b1;
        
                        // update pointers
                        rd_input_ptr                <= rd_input_ptr + 2;
                        rd_input_num_locations_left <= rd_input_num_locations_left - 2;
                        
                    end else if (rd_input_num_locations_left == 1) begin
                        // read last single location
                        // NOTICE that this is staggered. the last value should be written to ub_rd_input_data_2_out
                        // here we don't need to tranpose the first or last element
                        ub_rd_input_data_1_out         <= '0;
                        ub_rd_input_data_2_out         <= ub_memory[rd_input_ptr];
                        ub_rd_input_valid_1_out        <= 1'b0;
                        ub_rd_input_valid_2_out        <= 1'b1;
                         
                        // clear counters
                        rd_input_num_locations_left <= '0;
                        
                    end else begin
                        // no more data to read
                        ub_rd_input_valid_1_out        <= 1'b0;
                        ub_rd_input_valid_2_out        <= 1'b0;
                    end
                end
                
                default: begin
                    ub_rd_input_valid_1_out            <= 1'b0;
                    ub_rd_input_valid_2_out            <= 1'b0;
                end
            endcase
            
            // bias reading logic
            case (rd_bias_state)
                FIRST_COL: begin
                    if (ub_rd_bias_start_in) begin
                        rd_bias_address <=  ub_rd_bias_addr_in; // copy the address from the line below into a register so that we can "deassert" the address in waveform 1 clk cycle later
                        // first cycle of reading - output first one mem location (staggered)
                        ub_rd_bias_data_1_out         <= ub_memory[ub_rd_bias_addr_in];
                        ub_rd_bias_data_2_out         <= '0;
                        ub_rd_bias_valid_1_out        <= 1'b1;
                        ub_rd_bias_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        rd_bias_num_output_left <= ub_rd_bias_loc_in - 1;
                        rd_bias_state <= FIRST_AND_SECOND_COL;
                    end else begin // IDLE STATE (assuming ub_rd_bias_start_in is zero now)
                        ub_rd_bias_valid_1_out        <= 1'b0;
                        ub_rd_bias_valid_2_out        <= 1'b0;
                    end
                end

                FIRST_AND_SECOND_COL: begin 
                    if (rd_bias_num_output_left > 1) begin
                        ub_rd_bias_data_1_out         <= ub_memory[rd_bias_address];
                        ub_rd_bias_data_2_out         <= ub_memory[rd_bias_address + 1];
                        ub_rd_bias_valid_1_out        <= 1'b1;
                        ub_rd_bias_valid_2_out        <= 1'b1;

                        rd_bias_num_output_left <= rd_bias_num_output_left - 1;
                    end else begin
                        rd_bias_state <= SECOND_COL;
                    end
                end
                
                SECOND_COL: begin
                    ub_rd_bias_data_1_out         <= '0; 
                    ub_rd_bias_data_2_out         <= ub_memory[rd_bias_address + 1]; // read last element of bias vector/matrix
                    ub_rd_bias_valid_1_out        <= 1'b0;
                    ub_rd_bias_valid_2_out        <= 1'b1;
                    rd_bias_state <= FIRST_COL;
                end
                
                default: begin
                    ub_rd_bias_valid_1_out            <= 1'b0;
                    ub_rd_bias_valid_2_out            <= 1'b0;
                end
            endcase
            
            // activation reading logic
            case (rd_weight_state)
                READ_IDLE: begin
                    if (ub_rd_weight_start_in) begin
                        // first cycle of reading - output first one mem location (staggered)
                        ub_rd_weight_data_1_out         <= ub_memory[ub_rd_weight_addr_in];
                        ub_rd_weight_data_2_out         <= '0;
                        ub_rd_weight_valid_1_out        <= 1'b1;
                        ub_rd_weight_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        if (rd_weight_transpose) begin // if transpose 
                            rd_weight_ptr                <= ub_rd_weight_addr_in + 2;
                        end else begin // if not transpose 
                            rd_weight_ptr                <= ub_rd_weight_addr_in + 1;
                        end // this rule applies for both transpose and non-tranpose 
                        rd_weight_num_locations_left <= ub_rd_weight_loc_in - 1;
                    end else begin
                        ub_rd_weight_valid_1_out        <= 1'b0;
                        ub_rd_weight_valid_2_out        <= 1'b0;
                    end
                end
                
                READ_ACTIVE: begin 
                    if (rd_weight_num_locations_left > 1) begin 
                        ub_rd_weight_data_1_out <= ub_memory[rd_weight_ptr - 3];
                        ub_rd_weight_data_2_out <= ub_memory[rd_weight_ptr];
                        ub_rd_weight_valid_1_out        <= 1'b1;
                        ub_rd_weight_valid_2_out        <= 1'b1;

                        if (rd_weight_transpose) begin // if transpose 
                            rd_weight_ptr                <= rd_weight_ptr + 2;
                        end else begin // if no transpose
                            rd_weight_ptr                <= rd_weight_ptr + 1;
                        end// this rule applies for both tranpose and non-transpose
                        rd_weight_num_locations_left <= rd_weight_num_locations_left - 2;

                    end else if (rd_weight_num_locations_left == 1) begin
                        ub_rd_weight_data_1_out         <= 0;
                        ub_rd_weight_data_2_out         <= ub_memory[rd_weight_ptr - 3];
                        ub_rd_weight_valid_1_out        <= 1'b0;
                        ub_rd_weight_valid_2_out        <= 1'b1;
                    end
                end
                
                default: begin
                    ub_rd_weight_valid_1_out            <= 1'b0;
                    ub_rd_weight_valid_2_out            <= 1'b0;
                end
            endcase
            
            // loss reading logic
            case (rd_Y_state)
                READ_IDLE: begin
                    if (ub_rd_Y_start_in) begin
                        // first cycle of reading - output first one mem location (staggered)
                        ub_rd_Y_data_1_out         <= ub_memory[ub_rd_Y_addr_in];
                        ub_rd_Y_data_2_out         <= '0;
                        ub_rd_Y_valid_1_out        <= 1'b1;
                        ub_rd_Y_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        rd_Y_ptr                <= ub_rd_Y_addr_in + 1;
                        rd_Y_num_locations_left <= ub_rd_Y_loc_in - 1;
                    end else begin
                        ub_rd_Y_valid_1_out        <= 1'b0;
                        ub_rd_Y_valid_2_out        <= 1'b0;
                    end
                end
                
                READ_ACTIVE: begin
                    if (rd_Y_num_locations_left > 1) begin 
                        // read two more locations (no transpose)
                        ub_rd_Y_data_1_out         <= ub_memory[rd_Y_ptr + 1];
                        ub_rd_Y_data_2_out         <= ub_memory[rd_Y_ptr];

                        ub_rd_Y_valid_1_out        <= 1'b1;
                        ub_rd_Y_valid_2_out        <= 1'b1;
        
                        // update pointers
                        rd_Y_ptr                <= rd_Y_ptr + 2;
                        rd_Y_num_locations_left <= rd_Y_num_locations_left - 2;
                        
                    end else if (rd_Y_num_locations_left == 1) begin
                        // read last single location
                        ub_rd_Y_data_1_out         <= '0;
                        ub_rd_Y_data_2_out         <= ub_memory[rd_Y_ptr];
                        ub_rd_Y_valid_1_out        <= 1'b0;
                        ub_rd_Y_valid_2_out        <= 1'b1;
                         
                        // clear counters
                        rd_Y_num_locations_left <= '0;
                        
                    end else begin
                        // no more data to read
                        ub_rd_Y_valid_1_out        <= 1'b0;
                        ub_rd_Y_valid_2_out        <= 1'b0;
                    end
                end
                
                default: begin
                    ub_rd_Y_valid_1_out            <= 1'b0;
                    ub_rd_Y_valid_2_out            <= 1'b0;
                end
            endcase
            
            // activation derivative reading logic
            case (rd_H_state)
                READ_IDLE: begin
                    if (ub_rd_H_start_in) begin
                        // first cycle of reading - output first one mem location (staggered)
                        ub_rd_H_data_1_out         <= ub_memory[ub_rd_H_addr_in];
                        ub_rd_H_data_2_out         <= '0;
                        ub_rd_H_valid_1_out        <= 1'b1;
                        ub_rd_H_valid_2_out        <= 1'b0;
                        
                        // update internal counters
                        rd_H_ptr                <= ub_rd_H_addr_in + 1;
                        rd_H_num_locations_left <= ub_rd_H_loc_in - 1;
                    end else begin
                        ub_rd_H_valid_1_out        <= 1'b0;
                        ub_rd_H_valid_2_out        <= 1'b0;
                    end
                end
                
                READ_ACTIVE: begin
                    if (rd_H_num_locations_left > 1) begin 
                        // read two more locations (no transpose)
                        ub_rd_H_data_1_out         <= ub_memory[rd_H_ptr + 1];
                        ub_rd_H_data_2_out         <= ub_memory[rd_H_ptr];

                        ub_rd_H_valid_1_out        <= 1'b1;
                        ub_rd_H_valid_2_out        <= 1'b1;
        
                        // update pointers
                        rd_H_ptr                <= rd_H_ptr + 2;
                        rd_H_num_locations_left <= rd_H_num_locations_left - 2;
                        
                    end else if (rd_H_num_locations_left == 1) begin
                        // read last single location
                        ub_rd_H_data_1_out         <= '0;
                        ub_rd_H_data_2_out         <= ub_memory[rd_H_ptr];
                        ub_rd_H_valid_1_out        <= 1'b0;
                        ub_rd_H_valid_2_out        <= 1'b1;
                         
                        // clear counters
                        rd_H_num_locations_left <= '0;
                        
                    end else begin
                        // no more data to read
                        ub_rd_H_valid_1_out        <= 1'b0;
                        ub_rd_H_valid_2_out        <= 1'b0;
                    end
                end
                
                default: begin
                    ub_rd_H_valid_1_out            <= 1'b0;
                    ub_rd_H_valid_2_out            <= 1'b0;
                end
            endcase
            
            // writing INTO unified buffer logic (can run concurrently with reading)

            if (ub_wr_host_valid_in_1 && ub_wr_host_valid_in_2) begin
                // write both data inputs
                ub_memory[wr_ptr+1]     <= ub_wr_host_data_in_1;
                ub_memory[wr_ptr]       <= ub_wr_host_data_in_2;
                wr_ptr                  <= wr_ptr + 2;
            end else if (ub_wr_host_valid_in_1) begin
                // write only first data input
                ub_memory[wr_ptr]     <= ub_wr_host_data_in_1;
                wr_ptr                <= wr_ptr + 1;
            end else if (ub_wr_host_valid_in_2) begin
                // write only second data input
                ub_memory[wr_ptr]     <= ub_wr_host_data_in_2;
                wr_ptr                <= wr_ptr + 1;
            end else if (ub_wr_valid_data_in_1 && ub_wr_valid_data_in_2) begin
                // write both data inputs
                ub_memory[wr_ptr+1]     <= ub_wr_data_in_1;
                ub_memory[wr_ptr]       <= ub_wr_data_in_2;
                wr_ptr                  <= wr_ptr + 2;
                
            end else if (ub_wr_valid_data_in_1) begin
                // write only first data input
                ub_memory[wr_ptr]     <= ub_wr_data_in_1;
                wr_ptr                <= wr_ptr + 1;
                
            end else if (ub_wr_valid_data_in_2) begin
                // write only second data input
                ub_memory[wr_ptr]     <= ub_wr_data_in_2;
                wr_ptr                <= wr_ptr + 1;
            end
            
            // ub_wr_addr_valid_in should only be on for 1 clock cycle
            if (ub_wr_addr_valid_in) begin
                wr_ptr <= ub_wr_addr_in; 
            end 
            
        end
    end
endmodule


