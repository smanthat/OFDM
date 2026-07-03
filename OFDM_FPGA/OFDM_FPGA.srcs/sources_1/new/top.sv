`timescale 1ns / 1ps
import fixed_pkg::*;

module top (
    input  logic clk,
    input  logic n_rst,
    input  logic start,

    output logic [7:0] out_data,
    output logic       out_valid,
    input  logic       out_ready,

    output logic       seq_done
);

    cplx_t seq_out_data;
    logic  seq_out_valid;
    logic  seq_out_ready;

    cplx_t ifft_out_data;
    logic  ifft_out_valid;
    logic  ifft_out_ready;
    logic  ifft_out_last;

    cplx_t cp_out_data;
    logic  cp_out_valid;
    logic  cp_out_ready;
    logic  cp_out_last;

    logic [31:0] fifo_in_data;
    logic [31:0] fifo_out_data;
    logic        fifo_out_valid;
    logic        fifo_out_ready;

    assign fifo_in_data = cp_out_data;

    frame_sequencer u_seq (
        .clk       (clk),
        .n_rst     (n_rst),
        .start     (start),
        .done      (seq_done),
        .out_data  (seq_out_data),
        .out_valid (seq_out_valid),
        .out_ready (seq_out_ready)
    );

    ifft_wrapper u_ifft (
        .clk       (clk),
        .n_rst     (n_rst),

        .in_data   (seq_out_data),
        .in_valid  (seq_out_valid),
        .in_ready  (seq_out_ready),

        .out_data  (ifft_out_data),
        .out_valid (ifft_out_valid),
        .out_ready (ifft_out_ready),
        .out_last  (ifft_out_last)
    );

    cp_insert u_cp (
        .clk       (clk),
        .n_rst     (n_rst),

        .in_data   (ifft_out_data),
        .in_valid  (ifft_out_valid),
        .in_ready  (ifft_out_ready),

        .out_data  (cp_out_data),
        .out_valid (cp_out_valid),
        .out_ready (cp_out_ready),
        .out_last  (cp_out_last)
    );

    fifo_sync u_fifo (
        .clk       (clk),
        .n_rst     (n_rst),

        .in_data   (fifo_in_data),
        .in_valid  (cp_out_valid),
        .in_ready  (cp_out_ready),

        .out_data  (fifo_out_data),
        .out_valid (fifo_out_valid),
        .out_ready (fifo_out_ready)
    );

    byte_serializer u_ser (
        .clk       (clk),
        .n_rst     (n_rst),

        .in_data   (fifo_out_data),
        .in_valid  (fifo_out_valid),
        .in_ready  (fifo_out_ready),

        .out_data  (out_data),
        .out_valid (out_valid),
        .out_ready (out_ready)
    );

endmodule