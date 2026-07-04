`timescale 1ns / 1ps
import fixed_pkg::*;

module top #(
    parameter int CLK_HZ    = 100_000_000,
    parameter int BAUD = 115_200
) (
    input  logic clk,
    input  logic btn_rst,
    input  logic btn_start,

    output logic tx_out,
    output logic [7:0] led
);

    logic start;
    logic n_rst;

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

    logic        out_valid_ser;
    logic        out_ready_ser;
    logic [7:0]  out_data_ser;


    assign fifo_in_data = cp_out_data;

    button_sync u_start_sync (.clk(clk),
     .n_rst(por_n_rst), .btn_async(btn_start), .pulse(start));

     // power-on reset: hold n_rst low for the first 1024 cycles after config
logic [10:0] por_cnt = '0;
logic        por_done = 1'b0;
always_ff @(posedge clk) begin
    if (!por_done) begin
        por_cnt <= por_cnt + 1'b1;
        if (por_cnt == 11'h7FF) por_done <= 1'b1;
    end
end

logic por_n_rst;
assign por_n_rst = por_done & ~btn_rst;   // release only after POR AND btn not pressed

    frame_sequencer u_seq (
        .clk       (clk),
        .n_rst     (por_n_rst),
        .start     (start),
        .done      (seq_done),
        .out_data  (seq_out_data),
        .out_valid (seq_out_valid),
        .out_ready (seq_out_ready)
    );

    ifft_wrapper u_ifft (
        .clk       (clk),
        .n_rst     (por_n_rst),

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
        .n_rst     (por_n_rst),

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
        .n_rst     (por_n_rst),

        .in_data   (fifo_in_data),
        .in_valid  (cp_out_valid),
        .in_ready  (cp_out_ready),

        .out_data  (fifo_out_data),
        .out_valid (fifo_out_valid),
        .out_ready (fifo_out_ready)
    );

    byte_serializer u_ser (
        .clk       (clk),
        .n_rst     (por_n_rst),

        .in_data   (fifo_out_data),
        .in_valid  (fifo_out_valid),
        .in_ready  (fifo_out_ready),

        .out_data  (out_data_ser),
        .out_valid (out_valid_ser),
        .out_ready (out_ready_ser)
    );

    logic uart_data_valid;
    logic uart_accept;

    // UART is willing to take a byte when it's idle AND we have a byte to give
    assign uart_accept = out_valid_ser && !uart_busy;

    // Feed the UART: one cycle pulse per byte
    // (uart_accept is 1 only for the cycle right before busy goes high)
    assign uart_data_valid = uart_accept;

    // Tell the serializer we took its byte
    assign out_ready_ser = uart_accept;



    uart_tx_fixed #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart (
        .clk       (clk),
        .n_rst     (por_n_rst),

        .data_in   (out_data_ser),
        .data_valid(uart_data_valid),
        .tx_out    (tx_out),
        .busy      (uart_busy)
    );

            // Latch for start being seen
        logic start_ever_seen;
        always_ff @(posedge clk or negedge por_n_rst) begin
            if (!por_n_rst)     start_ever_seen <= 1'b0;
            else if (start)     start_ever_seen <= 1'b1;
        end
        
        // Latch for BTNU raw (before sync) being seen 
        logic btn_start_ever_seen;
        always_ff @(posedge clk) begin
            if (btn_start) btn_start_ever_seen <= 1'b1;
        end
        
        // Heartbeat 
        logic [25:0] heartbeat_cnt = '0;
        always_ff @(posedge clk) begin
            heartbeat_cnt <= heartbeat_cnt + 1'b1;
        end
        
        assign led[0] = heartbeat_cnt[25];      // heartbeat - clock alive
        assign led[1] = por_done;                // POR completed
        assign led[2] = por_n_rst;               // Reset released
        assign led[3] = btn_start_ever_seen;    // Raw BTNU ever pressed (physical button working)
        assign led[4] = start_ever_seen;        // Synchronized start pulse ever fired
        assign led[5] = seq_done;                // Sequencer completed a frame
        assign led[6] = seq_out_valid;          // Sequencer producing data (may be transient)
        assign led[7] = uart_busy;               // UART is transmitting
endmodule