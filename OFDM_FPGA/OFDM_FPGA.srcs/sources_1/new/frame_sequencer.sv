`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 10:04:21 PM
// Design Name: 
// Module Name: frame_sequencer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module frame_sequencer (
    input  logic  clk,
    input  logic  n_rst,
    input  logic  start,
    output logic  done,
    output cplx_t out_data,
    output logic  out_valid,
    input  logic  out_ready
);

    // ----- parameters -----
    localparam int NUM_BLOCKS = 18;
    localparam int NUM_SC     = 64;
    localparam int DATA_START = 2;

    // ----- state machine -----
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        WARMUP = 2'b01,
        ACTIVE = 2'b10,
        DONE_S = 2'b11
    } state_t;
    state_t state, n_state;

    // ----- counters -----
    logic [$clog2(NUM_BLOCKS)-1:0] block_idx, block_idx_next;   // 5 bits, 0-17
    logic [$clog2(NUM_SC)-1:0]     sc_idx, sc_idx_next;      // 6 bits, 0-63

    // ----- ROM and mapper signals -----
    logic [$clog2(NUM_SC)-1:0]     timing_addr;
    logic [$clog2(NUM_SC)-1:0]     channel_addr;
    logic [7:0]                    bit_addr;
    
    cplx_t timing_rom_out, channel_rom_out;
    logic [7:0] bit_rom_out;
    
    logic [1:0] qpsk_bits_in;
    cplx_t      qpsk_symbol_out;

    // ----- ROM and mapper instances -----
    preamble_rom #(.DEPTH(64), .INIT_FILE("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/preamble_timing.txt")) u_timing_rom (
        .clk(clk), .addr(timing_addr), .data_out(timing_rom_out)
    );
    preamble_rom #(.DEPTH(64), .INIT_FILE("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/preamble_channel.txt")) u_channel_rom (
        .clk(clk), .addr(channel_addr), .data_out(channel_rom_out)
    );
    bit_rom #(.DEPTH(256), .INIT_FILE("C:/Sourish/OFDM/OFDM Simulation/Verification_Files/bits.hex")) u_bit_rom (
        .clk(clk), .addr(bit_addr), .data_out(bit_rom_out)
    );
    qpsk_mapper u_mapper (
        .bits_in(qpsk_bits_in),
        .symbol_out(qpsk_symbol_out)
    );


    always_ff @( posedge clk or negedge n_rst ) begin 
        if(!n_rst) state <= IDLE;
        else state <= n_state;
    end
    



    //next_state logic
    always_comb begin
        n_state = state;
        case(state)
            IDLE : if(start) n_state = WARMUP;
            WARMUP : n_state = ACTIVE;
            ACTIVE : if(out_valid && out_ready && block_idx == NUM_BLOCKS-1 && sc_idx == NUM_SC - 1) n_state = DONE_S;
            DONE_S : n_state = IDLE;
            default : n_state = state;
        endcase
    end

    // ----- counter NEXT values -----
    always_comb begin
        sc_idx_next    = sc_idx;
        block_idx_next = block_idx;
        if (state == ACTIVE && out_valid && out_ready) begin
            if (sc_idx == NUM_SC-1) begin
                sc_idx_next    = '0;
                block_idx_next = block_idx + 1;
            end else begin
                sc_idx_next = sc_idx + 1;
            end
        end
    end

    // ----- counter registers -----
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            sc_idx    <= '0;
            block_idx <= '0;
        end else if (state == IDLE) begin
            sc_idx    <= '0;
            block_idx <= '0;
        end else begin
            sc_idx    <= sc_idx_next;
            block_idx <= block_idx_next;
        end
    end

    always_comb begin
        // bit_addr is the byte address: 16 bytes per data symbol, sc_idx/4 bytes into the symbol
        bit_addr = (block_idx - DATA_START) * 16 + (sc_idx >> 2);

        // Extract 2 bits from the byte (MSB-first within byte)
        // sc_idx[1:0] picks which 2-bit field
        // shift right by (3 - sc_idx[1:0]) * 2 to bring the desired pair to bits [1:0]
        qpsk_bits_in = bit_rom_out[7 - (sc_idx[1:0]*2) -: 2];
        out_data     = '0;
        out_valid    = 1'b0;
        done         = 1'b0;
        timing_addr  = '0;
        channel_addr = '0;
            case(state)
            IDLE: ;
            WARMUP : begin 
                timing_addr = sc_idx;
                channel_addr = sc_idx;
                out_valid = 0;
            end
            ACTIVE : begin 
                timing_addr = sc_idx;
                channel_addr = sc_idx;
                if(block_idx == 0) out_data = timing_rom_out;
                else if(block_idx == 1) out_data = channel_rom_out;
                else out_data = qpsk_symbol_out;
                out_valid = 1;
            end
            DONE_S : begin 
                done = 1;
                out_valid = 0;
            end
            default : begin
                out_data     = '0;
                out_valid    = 1'b0;
                done         = 1'b0;
                timing_addr  = '0;
                channel_addr = '0;
            end

        endcase
    end


    

endmodule