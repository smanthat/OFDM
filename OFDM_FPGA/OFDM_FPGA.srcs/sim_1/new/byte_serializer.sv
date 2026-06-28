`timescale 1ns / 1ps

import fixed_pkg::*;

// Converts one cplx_t sample into four UART bytes.
// Byte order is explicit and PC-friendly:
//   byte 0 = re[7:0]
//   byte 1 = re[15:8]
//   byte 2 = im[7:0]
//   byte 3 = im[15:8]
module byte_serializer (
    input  logic clk,
    input  logic n_rst,

    // AXI-style input from FIFO
    input  cplx_t in_data,
    input  logic  in_valid,
    output logic  in_ready,

    // AXI-style output to UART wrapper / UART TX
    output logic [7:0] out_data,
    output logic       out_valid,
    input  logic       out_ready
);

    typedef enum logic [1:0] {
        IDLE = 2'd0,
        SEND = 2'd1
    } state_t;

    state_t state;

    cplx_t word_reg;
    logic [1:0] byte_idx;

    logic input_fire;
    logic output_fire;
    logic last_byte;

    assign input_fire  = in_valid && in_ready;
    assign output_fire = out_valid && out_ready;
    assign last_byte   = (byte_idx == 2'd3);

    // Safe for FIFO Generator FWFT/native FIFO:
    // only take a new 32-bit word when serializer is fully idle.
    assign in_ready = (state == IDLE);

    function automatic logic [7:0] select_byte(
        input cplx_t sample,
        input logic [1:0] idx
    );
        case (idx)
            2'd0: select_byte = sample.re[7:0];
            2'd1: select_byte = sample.re[15:8];
            2'd2: select_byte = sample.im[7:0];
            2'd3: select_byte = sample.im[15:8];
            default: select_byte = 8'h00;
        endcase
    endfunction

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state     <= IDLE;
            word_reg  <= '0;
            byte_idx  <= 2'd0;
            out_data  <= 8'h00;
            out_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    byte_idx <= 2'd0;

                    if (input_fire) begin
                        word_reg  <= in_data;
                        out_data  <= select_byte(in_data, 2'd0);
                        out_valid <= 1'b1;
                        state     <= SEND;
                    end else begin
                        out_valid <= 1'b0;
                        out_data  <= 8'h00;
                    end
                end

                SEND: begin
                    if (output_fire) begin
                        if (last_byte) begin
                            state     <= IDLE;
                            byte_idx  <= 2'd0;
                            out_valid <= 1'b0;
                        end else begin
                            byte_idx <= byte_idx + 1'b1;
                            out_data <= select_byte(word_reg, byte_idx + 1'b1);
                        end
                    end
                end

                default: begin
                    state     <= IDLE;
                    word_reg  <= '0;
                    byte_idx  <= 2'd0;
                    out_data  <= 8'h00;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule
