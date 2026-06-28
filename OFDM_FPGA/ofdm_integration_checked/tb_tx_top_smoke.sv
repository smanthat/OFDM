`timescale 1ns / 1ps

module tb_tx_top_smoke;

    logic clk;
    logic btn_rst;
    logic btn_start;

    logic uart_txd;
    logic led_busy;
    logic led_done;

    int toggle_count = 0;
    logic uart_txd_d;

    tx_top dut (
        .clk(clk),
        .btn_rst(btn_rst),
        .btn_start(btn_start),
        .uart_txd(uart_txd),
        .led_busy(led_busy),
        .led_done(led_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    always_ff @(posedge clk) begin
        uart_txd_d <= uart_txd;
        if (uart_txd !== uart_txd_d) begin
            toggle_count++;
        end
    end

    initial begin
        $display("Starting tb_tx_top_smoke...");

        btn_rst   = 1'b1;
        btn_start = 1'b0;

        repeat (20) @(posedge clk);
        @(negedge clk);
        btn_rst = 1'b0;

        // Give IFFT wrapper time to send config to XFFT IP.
        repeat (200) @(posedge clk);

        $display("Pressing start...");
        @(negedge clk);
        btn_start = 1'b1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        btn_start = 1'b0;

        // UART is slow. This is just a smoke test, not a full 5760-byte drain.
        repeat (2_000_000) @(posedge clk);

        if (toggle_count == 0) begin
            $display("[FAIL] uart_txd never toggled. Check top-level wiring, XFFT IP, FIFO IP, and ROM paths.");
        end else begin
            $display("[PASS] uart_txd toggled %0d times", toggle_count);
        end

        $display("led_busy = %0b", led_busy);
        $display("led_done = %0b", led_done);
        $display("tb_tx_top_smoke complete.");
        $finish;
    end

endmodule
