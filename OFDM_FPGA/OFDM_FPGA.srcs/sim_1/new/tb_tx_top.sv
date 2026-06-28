`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2026 08:06:51 PM
// Design Name: 
// Module Name: tb_tx_top
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


module tb_tx_top_full;

    localparam int CLK_HZ      = 100_000_000;

    // Fast simulation baud.
    // 100 MHz / 10 MHz = 10 clock cycles per UART bit.
    // This makes a full 5760-byte frame finish quickly.
    localparam int UART_BAUD   = 10_000_000;
    localparam int BIT_CYCLES  = CLK_HZ / UART_BAUD;

    localparam int NUM_BLOCKS  = 18;
    localparam int N_SC        = 64;
    localparam int CP_LEN      = 16;
    localparam int FRAME_SAMPS = NUM_BLOCKS * (N_SC + CP_LEN); // 1440
    localparam int FRAME_BYTES = FRAME_SAMPS * 4;              // 5760

    logic clk;
    logic btn_rst;
    logic btn_start;

    logic uart_txd;
    logic led_busy;
    logic led_done;

    int errors = 0;
    int rx_count = 0;

    logic [7:0] rx_bytes [0:FRAME_BYTES-1];

    tx_top #(
        .CLK_HZ    (CLK_HZ),
        .UART_BAUD (UART_BAUD)
    ) dut (
        .clk       (clk),
        .btn_rst   (btn_rst),
        .btn_start (btn_start),
        .uart_txd  (uart_txd),
        .led_busy  (led_busy),
        .led_done  (led_done)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Timeout protection
    // ------------------------------------------------------------
    initial begin
        repeat (5_000_000) @(posedge clk);
        $display("[TIMEOUT] tb_tx_top_full did not finish.");
        $display("rx_count = %0d / %0d", rx_count, FRAME_BYTES);
        $display("led_busy = %0b, led_done = %0b", led_busy, led_done);
        $finish;
    end

    // ------------------------------------------------------------
    // UART byte receiver
    // Decodes 8N1 UART:
    // start bit = 0
    // 8 data bits, LSB first
    // stop bit = 1
    // ------------------------------------------------------------
    task automatic uart_rx_byte(output logic [7:0] b);
        begin
            b = 8'h00;

            // Wait for falling edge of start bit
            @(negedge uart_txd);

            // Move to middle of start bit
            repeat (BIT_CYCLES / 2) @(posedge clk);

            if (uart_txd !== 1'b0) begin
                $display("[FAIL] Bad UART start bit");
                errors++;
            end

            // Sample each data bit in the middle of its bit period
            for (int i = 0; i < 8; i++) begin
                repeat (BIT_CYCLES) @(posedge clk);
                b[i] = uart_txd;
            end

            // Sample stop bit
            repeat (BIT_CYCLES) @(posedge clk);

            if (uart_txd !== 1'b1) begin
                $display("[FAIL] Bad UART stop bit after byte 0x%02h", b);
                errors++;
            end
        end
    endtask

    task automatic press_start_button();
        begin
            @(negedge clk);
            btn_start = 1'b1;

            // Hold long enough to pass through the synchronizer
            repeat (10) @(posedge clk);

            @(negedge clk);
            btn_start = 1'b0;
        end
    endtask

    task automatic reset_dut();
        begin
            btn_rst   = 1'b1;
            btn_start = 1'b0;

            repeat (20) @(posedge clk);

            @(negedge clk);
            btn_rst = 1'b0;

            // Give IFFT wrapper time to configure XFFT IP
            repeat (300) @(posedge clk);
        end
    endtask

    int f;

    initial begin
        $display("========================================");
        $display("Starting tb_tx_top_full");
        $display("Expected frame bytes = %0d", FRAME_BYTES);
        $display("Simulation UART baud = %0d", UART_BAUD);
        $display("UART bit cycles      = %0d", BIT_CYCLES);
        $display("========================================");

        reset_dut();

        if (uart_txd !== 1'b1) begin
            $display("[FAIL] UART TX line should idle high after reset");
            errors++;
        end

        $display("Pressing start button...");
        press_start_button();

        $display("Receiving UART frame...");

        for (int i = 0; i < FRAME_BYTES; i++) begin
            uart_rx_byte(rx_bytes[i]);
            rx_count++;

            if ((i % 512) == 0) begin
                $display("Received %0d / %0d bytes", i, FRAME_BYTES);
            end
        end

        $display("Received all %0d bytes.", rx_count);

        // Give top-level byte counter / done LED a few cycles to update
        repeat (100) @(posedge clk);

        if (rx_count != FRAME_BYTES) begin
            $display("[FAIL] Wrong byte count. got=%0d expected=%0d",
                     rx_count, FRAME_BYTES);
            errors++;
        end

        if (led_done !== 1'b1) begin
            $display("[FAIL] led_done should be high after one full frame");
            errors++;
        end

        // Write captured bytes to file
        f = $fopen("tx_top_uart_bytes.hex", "w");

        if (f == 0) begin
            $display("[FAIL] Could not open tx_top_uart_bytes.hex");
            errors++;
        end else begin
            for (int i = 0; i < FRAME_BYTES; i++) begin
                $fwrite(f, "%02h\n", rx_bytes[i]);
            end

            $fclose(f);
            $display("Wrote captured UART bytes to tx_top_uart_bytes.hex");
        end

        if (errors == 0) begin
            $display("========================================");
            $display("PASS: tb_tx_top_full completed with 0 errors");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAIL: tb_tx_top_full completed with %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule