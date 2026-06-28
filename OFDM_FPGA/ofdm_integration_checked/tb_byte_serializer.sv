`timescale 1ns / 1ps

import fixed_pkg::*;

module tb_byte_serializer;

    logic clk;
    logic n_rst;

    cplx_t in_data;
    logic  in_valid;
    logic  in_ready;

    logic [7:0] out_data;
    logic       out_valid;
    logic       out_ready;

    int errors = 0;

    byte_serializer dut (
        .clk(clk),
        .n_rst(n_rst),
        .in_data(in_data),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_data(out_data),
        .out_valid(out_valid),
        .out_ready(out_ready)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic reset_dut();
        begin
            in_data.re = '0;
            in_data.im = '0;
            in_valid = 1'b0;
            out_ready = 1'b0;

            n_rst = 1'b0;
            repeat (5) @(negedge clk);
            @(negedge clk);
            n_rst = 1'b1;
            repeat (5) @(negedge clk);
        end
    endtask

    task automatic push_sample(
    input logic signed [15:0] re,
    input logic signed [15:0] im
);
    begin
        @(negedge clk);
        in_data.re = re;
        in_data.im = im;
        in_valid   = 1'b1;

        while (in_ready !== 1'b1) begin
            @(negedge clk);
        end

        // Handshake happens on this one posedge
        @(posedge clk);

        @(negedge clk);
        in_valid   = 1'b0;
        in_data.re = '0;
        in_data.im = '0;
    end
endtask

   task automatic pop_byte(output logic [7:0] b);
    begin
        @(negedge clk);
        out_ready = 1'b1;

        while (out_valid !== 1'b1) begin
            @(negedge clk);
        end

        // Capture current byte before the handshake advances it
        b = out_data;

        // Exactly one handshake
        @(posedge clk);

        @(negedge clk);
        out_ready = 1'b0;
    end
endtask

    task automatic check_byte(input logic [7:0] got, input logic [7:0] exp, input string tag);
        begin
            if (got !== exp) begin
                $display("[FAIL] %s got=0x%02h exp=0x%02h", tag, got, exp);
                errors++;
            end
        end
    endtask

    logic [7:0] got;

    initial begin
        $display("Starting tb_byte_serializer...");
        reset_dut();

        if (in_ready !== 1'b1) begin
            $display("[FAIL] in_ready should be high after reset");
            errors++;
        end

        if (out_valid !== 1'b0) begin
            $display("[FAIL] out_valid should be low after reset");
            errors++;
        end

        // re = 16'h1122, im = 16'h3344
        // Expected bytes: 22, 11, 44, 33
        $display("Test 1: one sample, explicit re/im byte order");
        fork
            begin
                push_sample(16'sh1122, 16'sh3344);
            end
            begin
                pop_byte(got); check_byte(got, 8'h22, "sample0 re low");
                pop_byte(got); check_byte(got, 8'h11, "sample0 re high");
                pop_byte(got); check_byte(got, 8'h44, "sample0 im low");
                pop_byte(got); check_byte(got, 8'h33, "sample0 im high");
            end
        join

        repeat (5) @(negedge clk);

        // Backpressure: out_ready low should hold the first byte stable.
        $display("Test 2: output backpressure holds byte stable");
        push_sample(16'sh7A01, -16'sd2); // im = 0xFFFE

        @(negedge clk);
        out_ready = 1'b0;
        repeat (10) begin
            @(negedge clk);
            if (out_valid !== 1'b1) begin
                $display("[FAIL] out_valid dropped during backpressure");
                errors++;
            end
            if (out_data !== 8'h01) begin
                $display("[FAIL] out_data changed during backpressure got=0x%02h", out_data);
                errors++;
            end
        end

        pop_byte(got); check_byte(got, 8'h01, "backpressure re low");
        pop_byte(got); check_byte(got, 8'h7A, "backpressure re high");
        pop_byte(got); check_byte(got, 8'hFE, "backpressure im low");
        pop_byte(got); check_byte(got, 8'hFF, "backpressure im high");

        // Multiple samples
        $display("Test 3: multiple samples preserve order");
        fork
            begin
                push_sample(16'sh0102, 16'sh0304);
                push_sample(16'shA0B0, 16'shC0D0);
            end
            begin
                pop_byte(got); check_byte(got, 8'h02, "multi0 re low");
                pop_byte(got); check_byte(got, 8'h01, "multi0 re high");
                pop_byte(got); check_byte(got, 8'h04, "multi0 im low");
                pop_byte(got); check_byte(got, 8'h03, "multi0 im high");
                pop_byte(got); check_byte(got, 8'hB0, "multi1 re low");
                pop_byte(got); check_byte(got, 8'hA0, "multi1 re high");
                pop_byte(got); check_byte(got, 8'hD0, "multi1 im low");
                pop_byte(got); check_byte(got, 8'hC0, "multi1 im high");
            end
        join

        if (errors == 0) begin
            $display("========================================");
            $display("PASS: tb_byte_serializer completed with 0 errors");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAIL: tb_byte_serializer completed with %0d errors", errors);
            $display("========================================");
        end

        $finish;
    end

endmodule
