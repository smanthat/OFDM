`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/26/2026 11:25:54 AM
// Design Name: 
// Module Name: tb_fifo_sync
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

import fixed_pkg::*;
module tb_fifo_sync;

    localparam int DEPTH = 2048;
    localparam int WIDTH = 32;

    logic clk;
    logic n_rst;

    logic [WIDTH-1:0] in_data;
    logic             in_valid;
    logic             in_ready;

    logic [WIDTH-1:0] out_data;
    logic             out_valid;
    logic             out_ready;

    int errors = 0;

    fifo_sync #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
    ) dut (
        .clk       (clk),
        .n_rst     (n_rst),

        .in_data   (in_data),
        .in_valid  (in_valid),
        .in_ready  (in_ready),

        .out_data  (out_data),
        .out_valid (out_valid),
        .out_ready (out_ready)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic reset_dut();
        begin
            in_data   = '0;
            in_valid  = 1'b0;
            out_ready = 1'b0;

            n_rst = 1'b0;
            repeat (5) @(negedge clk);

            // Release reset on negedge to avoid reset-release races
            @(negedge clk);
            n_rst = 1'b1;

            repeat (5) @(negedge clk);
        end
    endtask

    task automatic push_word(input logic [WIDTH-1:0] data);
        begin
            @(negedge clk);
            in_data  = data;
            in_valid = 1'b1;

            while (in_ready !== 1'b1) begin
                @(negedge clk);
            end

            // Handshake occurs on this negedge
            @(negedge clk);

            @(negedge clk);
            in_valid = 1'b0;
            in_data  = '0;
        end
    endtask

    task automatic pop_word(output logic [WIDTH-1:0] data);
        begin
            @(negedge clk);
            out_ready = 1'b1;

            while (out_valid !== 1'b1) begin
                @(negedge clk);
            end

            data = out_data;

            // Handshake occurs on this negedge
            @(negedge clk);

            @(negedge clk);
            out_ready = 1'b0;
        end
    endtask

    task automatic check_word(
        input logic [WIDTH-1:0] got,
        input logic [WIDTH-1:0] expected,
        input string tag
    );
        begin
            if (got !== expected) begin
                $display("[FAIL] %s | got = 0x%08h, expected = 0x%08h",
                         tag, got, expected);
                errors++;
            end
        end
    endtask

    logic [WIDTH-1:0] got;

    initial begin
        $display("Starting tb_fifo_sync...");

        reset_dut();

        if (out_valid !== 1'b0) begin
            $display("[FAIL] out_valid should be 0 after reset");
            errors++;
        end

        if (in_ready !== 1'b1) begin
            $display("[FAIL] in_ready should be 1 after reset");
            errors++;
        end

        // ------------------------------------------------------------
        // Test 1: basic ordering
        // ------------------------------------------------------------
        $display("Test 1: basic push/pop ordering");

        for (int i = 0; i < 16; i++) begin
            push_word(32'hA000_0000 + i);
        end

        for (int i = 0; i < 16; i++) begin
            pop_word(got);
            check_word(got, 32'hA000_0000 + i, "basic ordering");
        end

        repeat (5) @(negedge clk);

        if (out_valid !== 1'b0) begin
            $display("[FAIL] FIFO should be empty after Test 1");
            errors++;
        end

        // ------------------------------------------------------------
        // Test 2: output backpressure
        // Push many words while out_ready = 0.
        // FIFO should hold data and not lose ordering.
        // ------------------------------------------------------------
        $display("Test 2: output backpressure");

        out_ready = 1'b0;

        for (int i = 0; i < 32; i++) begin
            push_word(32'hB000_0000 + i);
        end

        repeat (20) @(negedge clk);

        if (out_valid !== 1'b1) begin
            $display("[FAIL] out_valid should be high while FIFO contains data");
            errors++;
        end

        if (out_data !== 32'hB000_0000) begin
            $display("[FAIL] first visible output wrong during backpressure | got = 0x%08h",
                     out_data);
            errors++;
        end

        for (int i = 0; i < 32; i++) begin
            pop_word(got);
            check_word(got, 32'hB000_0000 + i, "backpressure ordering");
        end

        repeat (5) @(negedge clk);

        if (out_valid !== 1'b0) begin
            $display("[FAIL] FIFO should be empty after Test 2");
            errors++;
        end

        // // ------------------------------------------------------------
        // // Test 3: full-depth fill and drain
        // // Fill exactly DEPTH entries.
        // // FIFO should deassert in_ready when full.
        // // ------------------------------------------------------------
        // $display("Test 3: full-depth fill/drain");

        // out_ready = 1'b0;

        // for (int i = 0; i < DEPTH; i++) begin
        //     push_word(32'hC000_0000 + i);
        // end

        // repeat (10) @(negedge clk);
        // @(negedge clk);

        // if (in_ready !== 1'b0) begin
        //     $display("[FAIL] in_ready should be 0 when FIFO is full");
        //     errors++;
        // end

        // for (int i = 0; i < DEPTH; i++) begin
        //     pop_word(got);
        //     check_word(got, 32'hC000_0000 + i, "full-depth drain");
        // end

        // repeat (10) @(negedge clk);

        // if (out_valid !== 1'b0) begin
        //     $display("[FAIL] FIFO should be empty after full-depth drain");
        //     errors++;
        // end

        // // ------------------------------------------------------------
        // // Test 4: pointer wraparound
        // // Push some, pop some, push more, then drain.
        // // This forces rd_ptr and wr_ptr to move independently.
        // // ------------------------------------------------------------
        // $display("Test 4: pointer wraparound behavior");

        // for (int i = 0; i < 100; i++) begin
        //     push_word(32'hD000_0000 + i);
        // end

        // for (int i = 0; i < 60; i++) begin
        //     pop_word(got);
        //     check_word(got, 32'hD000_0000 + i, "wraparound first drain");
        // end

        // for (int i = 100; i < 220; i++) begin
        //     push_word(32'hD000_0000 + i);
        // end

        // for (int i = 60; i < 220; i++) begin
        //     pop_word(got);
        //     check_word(got, 32'hD000_0000 + i, "wraparound final drain");
        // end

        // repeat (10) @(negedge clk);

        // if (out_valid !== 1'b0) begin
        //     $display("[FAIL] FIFO should be empty after wraparound test");
        //     errors++;
        // end

        // ------------------------------------------------------------
        // Final result
        // ------------------------------------------------------------
        if (errors == 0) begin
            $display("========================================");
            $display("PASS: tb_fifo_sync completed with 0 errors");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAIL: tb_fifo_sync completed with %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule

