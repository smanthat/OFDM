`timescale 1ns / 1ps

import fixed_pkg::*;

// Top-level TX integration for your verified modules:
// frame_sequencer -> ifft_wrapper -> cp_insert -> fifo_sync -> byte_serializer -> uart_tx_fixed
module tx_top #(
    parameter int CLK_HZ    = 100_000_000,
    parameter int UART_BAUD = 115_200
)(
    input  logic clk,
    input  logic btn_rst,
    input  logic btn_start,

    output logic uart_txd,
    output logic led_busy,
    output logic led_done
);

    localparam int NUM_BLOCKS  = 18;
    localparam int N_SC        = 64;
    localparam int CP_LEN      = 16;
    localparam int OUT_PER_BLK = N_SC + CP_LEN;       // 80
    localparam int FRAME_SAMPS = NUM_BLOCKS * OUT_PER_BLK; // 1440
    localparam int FRAME_BYTES = FRAME_SAMPS * 4;     // 5760

    logic n_rst;
    assign n_rst = ~btn_rst;

    // ------------------------------------------------------------
    // Synchronize and edge-detect start button
    // ------------------------------------------------------------
    logic start_meta;
    logic start_sync;
    logic start_sync_d;
    logic start_pulse_raw;
    logic start_pulse;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            start_meta   <= 1'b0;
            start_sync   <= 1'b0;
            start_sync_d <= 1'b0;
        end else begin
            start_meta   <= btn_start;
            start_sync   <= start_meta;
            start_sync_d <= start_sync;
        end
    end

    assign start_pulse_raw = start_sync && !start_sync_d;

    // ------------------------------------------------------------
    // Frame active / byte counting
    // This prevents accidental repeated button starts while a frame is draining.
    // ------------------------------------------------------------
    logic tx_active;
    logic [$clog2(FRAME_BYTES+1)-1:0] byte_count;
    logic uart_accept;

    assign start_pulse = start_pulse_raw && !tx_active;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            tx_active  <= 1'b0;
            byte_count <= '0;
        end else begin
            if (start_pulse) begin
                tx_active  <= 1'b1;
                byte_count <= '0;
            end else if (tx_active && uart_accept) begin
                if (byte_count == FRAME_BYTES - 1) begin
                    tx_active  <= 1'b0;
                    byte_count <= '0;
                end else begin
                    byte_count <= byte_count + 1'b1;
                end
            end
        end
    end

    // done LED latch: clears on a new accepted start, sets after one frame worth of bytes
    logic done_latched;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            done_latched <= 1'b0;
        end else if (start_pulse) begin
            done_latched <= 1'b0;
        end else if (tx_active && uart_accept && (byte_count == FRAME_BYTES - 1)) begin
            done_latched <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // frame_sequencer -> ifft_wrapper
    // ------------------------------------------------------------
    cplx_t seq_data;
    logic  seq_valid;
    logic  seq_ready;
    logic  seq_done;

    frame_sequencer u_frame_sequencer (
        .clk       (clk),
        .n_rst     (n_rst),
        .start     (start_pulse),
        .done      (seq_done),
        .out_data  (seq_data),
        .out_valid (seq_valid),
        .out_ready (seq_ready)
    );

    // ------------------------------------------------------------
    // ifft_wrapper -> cp_insert
    // ------------------------------------------------------------
    cplx_t ifft_data;
    logic  ifft_valid;
    logic  ifft_ready;
    logic  ifft_last;

    ifft_wrapper u_ifft_wrapper (
        .clk       (clk),
        .n_rst     (n_rst),
        .in_data   (seq_data),
        .in_ready  (seq_ready),
        .in_valid  (seq_valid),
        .out_data  (ifft_data),
        .out_valid (ifft_valid),
        .out_ready (ifft_ready),
        .out_last  (ifft_last)
    );

    // ------------------------------------------------------------
    // cp_insert -> fifo_sync
    // ------------------------------------------------------------
    cplx_t cp_data;
    logic  cp_valid;
    logic  cp_ready;
    logic  cp_last;

    cp_insert u_cp_insert (
        .clk       (clk),
        .n_rst     (n_rst),
        .in_data   (ifft_data),
        .in_valid  (ifft_valid),
        .in_ready  (ifft_ready),
        .out_data  (cp_data),
        .out_valid (cp_valid),
        .out_ready (cp_ready),
        .out_last  (cp_last)
    );

    // fifo_sync has a flat 32-bit interface.
    logic [31:0] cp_data_flat;
    logic [31:0] fifo_data_flat;
    cplx_t       fifo_data;
    logic        fifo_valid;
    logic        fifo_ready;

    assign cp_data_flat = cp_data;
    assign fifo_data    = fifo_data_flat;

    fifo_sync #(
        .DEPTH (2048),
        .WIDTH (32)
    ) u_frame_fifo (
        .clk       (clk),
        .n_rst     (n_rst),
        .in_data   (cp_data_flat),
        .in_valid  (cp_valid),
        .in_ready  (cp_ready),
        .out_data  (fifo_data_flat),
        .out_valid (fifo_valid),
        .out_ready (fifo_ready)
    );

    // ------------------------------------------------------------
    // fifo_sync -> byte_serializer -> uart_tx_fixed
    // ------------------------------------------------------------
    logic [7:0] uart_byte;
    logic       uart_byte_valid;
    logic       uart_byte_ready;
    logic       uart_busy;

    byte_serializer u_byte_serializer (
        .clk       (clk),
        .n_rst     (n_rst),
        .in_data   (fifo_data),
        .in_valid  (fifo_valid),
        .in_ready  (fifo_ready),
        .out_data  (uart_byte),
        .out_valid (uart_byte_valid),
        .out_ready (uart_byte_ready)
    );

    assign uart_byte_ready = !uart_busy;
    assign uart_accept     = uart_byte_valid && uart_byte_ready;

    uart_tx_fixed #(
        .CLK_HZ (100_000_000),
        .BAUD   (115_200)
    ) u_uart_tx (
        .clk        (clk),
        .n_rst      (n_rst),
        .data_in    (uart_byte),
        .data_valid (uart_accept),
        .tx_out     (uart_txd),
        .busy       (uart_busy)
    );

    // ------------------------------------------------------------
    // Debug LEDs
    // ------------------------------------------------------------
    assign led_busy = tx_active | seq_valid | ifft_valid | cp_valid | fifo_valid | uart_byte_valid | uart_busy;
    assign led_done = done_latched;

endmodule
