`timescale 1ns / 1ps

module tb_uart_tx;

    logic clk, n_rst, data_valid;
    logic [7:0] data_in;
    logic tx_out, busy;

    // 100 MHz clock (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    uart_tx DUT (
        .clk(clk),
        .n_rst(n_rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .tx_out(tx_out),
        .busy(busy)
    );
    task reset_dut;
    begin
        n_rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1;
        @(negedge clk);
        @(negedge clk);
    end
    endtask

    task check_output(
        input logic expected_busy,
        input logic expected_tx_out
    );
        if (expected_tx_out !== tx_out || expected_busy !== busy ) begin
            $display("FAIL: Expected tx_out=%b busy=%b, Got tx_out=%b busy=%b",
                     expected_tx_out, expected_busy,
                     tx_out, busy);
        end else begin
            $display("PASS: tx_out=%b busy=%b", tx_out, busy);
        end
    endtask

    initial begin


       reset_dut;
       repeat(3) @(negedge clk);

        // After reset: idle — tx line high, not busy, data_ready asserted
        check_output(.expected_busy(1'b0), .expected_tx_out(1'b1));
    
        // Send byte 00101011
        @(negedge clk);
        data_in    = 8'b00101011;
        data_valid = 1;
        @(negedge clk);
        data_valid = 0;

        repeat(434) @(negedge clk);
        // START first
        check_output(1,0);

        repeat(867) @(negedge clk);

        //first bit
        check_output(1,1);

        //2bit
        repeat(867) @(negedge clk);

        check_output(1,1);


        //3 bit
        repeat(867) @(negedge clk);

        check_output(1,0);


        //4 bit
       repeat(867) @(negedge clk);

        check_output(1,1);


        //5 bit
        repeat(867) @(negedge clk);

        check_output(1,0);
            
        //6 bit
        repeat(867) @(negedge clk);

        check_output(1,1);

        //7 bit
        repeat(867) @(negedge clk);
        check_output(1,0);

        //8 bit
        repeat(867) @(negedge clk);

        check_output(1,0);

        //STOP
        repeat(867) @(negedge clk);

        check_output(1,1);
        
        repeat(867) @(negedge clk);
        
        check_output(0,1);



        $finish;
    end

endmodule
