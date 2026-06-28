`timescale 1ns / 1ps

module tb_uart_tx_fixed;

    localparam int CLK_HZ = 100_000_000;
    localparam int BAUD   = 115_200;
    localparam int BAUD_DIV = CLK_HZ / BAUD;

    logic clk;
    logic n_rst;
    logic [7:0] data_in;
    logic data_valid;
    logic tx_out;
    logic busy;

    int errors = 0;

    uart_tx_fixed #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) dut (
        .clk(clk),
        .n_rst(n_rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .tx_out(tx_out),
        .busy(busy)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic reset_dut();
        begin
            data_in = 8'h00;
            data_valid = 1'b0;
            n_rst = 1'b0;
            repeat (5) @(posedge clk);
            @(negedge clk);
            n_rst = 1'b1;
            repeat (5) @(posedge clk);
        end
    endtask

    task automatic check(input logic got, input logic exp, input string tag);
        begin
            if (got !== exp) begin
                $display("[FAIL] %s got=%0b exp=%0b", tag, got, exp);
                errors++;
            end
        end
    endtask

    task automatic send_byte_then_mutate(input logic [7:0] b, input logic [7:0] mutate_to);
        begin
            @(negedge clk);
            data_in = b;
            data_valid = 1'b1;
            @(posedge clk); // accept in IDLE
            @(negedge clk);
            data_valid = 1'b0;

            // This is the important integration test:
            // data_in changes after acceptance, but UART must still transmit b.
            data_in = mutate_to;
        end
    endtask

    task automatic wait_bit_center();
        begin
            repeat (BAUD_DIV / 2) @(posedge clk);
        end
    endtask

    task automatic wait_one_bit();
        begin
            repeat (BAUD_DIV) @(posedge clk);
        end
    endtask

    initial begin
        $display("Starting tb_uart_tx_fixed...");
        reset_dut();

        check(tx_out, 1'b1, "idle tx high");
        check(busy, 1'b0, "idle busy low");

        // Send 0x2B = 8'b0010_1011, LSB first: 1 1 0 1 0 1 0 0
        send_byte_then_mutate(8'h2B, 8'h00);

        wait_bit_center();
        check(tx_out, 1'b0, "start bit");

        wait_one_bit(); check(tx_out, 1'b1, "data bit 0");
        wait_one_bit(); check(tx_out, 1'b1, "data bit 1");
        wait_one_bit(); check(tx_out, 1'b0, "data bit 2");
        wait_one_bit(); check(tx_out, 1'b1, "data bit 3");
        wait_one_bit(); check(tx_out, 1'b0, "data bit 4");
        wait_one_bit(); check(tx_out, 1'b1, "data bit 5");
        wait_one_bit(); check(tx_out, 1'b0, "data bit 6");
        wait_one_bit(); check(tx_out, 1'b0, "data bit 7");
        wait_one_bit(); check(tx_out, 1'b1, "stop bit");

        wait_one_bit();
        check(busy, 1'b0, "busy low after byte");

        if (errors == 0) begin
            $display("========================================");
            $display("PASS: tb_uart_tx_fixed completed with 0 errors");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAIL: tb_uart_tx_fixed completed with %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule
