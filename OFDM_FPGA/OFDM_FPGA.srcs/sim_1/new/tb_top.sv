`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// tb_top — byte_serializer integration test
//   Chain: frame_seq -> ifft -> cp_insert -> fifo -> byte_serializer
//   Serializer out_ready is tied 1 inside top, so bytes stream at full rate.
//   Captures all 320 bytes at the top output, reassembles cplx_t samples
//   (byte order: re[7:0], re[15:8], im[7:0], im[15:8]) and compares against
//   frame_with_cp.txt.
//////////////////////////////////////////////////////////////////////////////////
import fixed_pkg::*;

module tb_top;
 localparam int NUM_BLOCKS     = 18;
    localparam int N              = 64;
    localparam int CP_LEN         = 16;
    localparam int BLOCK_LEN      = N + CP_LEN;
    localparam int TOTAL_SAMPLES  = NUM_BLOCKS * BLOCK_LEN; // 1440
    localparam int TOTAL_BYTES    = TOTAL_SAMPLES * 4;       // 5760
    localparam int TIMEOUT_CYCLES = 1_000_000;

    logic clk;
    logic n_rst;
    logic start;

    logic [7:0] out_data;
    logic       out_valid;
    logic       out_ready;
    logic       seq_done;

    int byte_count;
    int errors;

    logic [31:0] expected_words [0:TOTAL_SAMPLES-1];
    logic [7:0]  got_bytes      [0:TOTAL_BYTES-1];

    initial begin
        $readmemh(
            "C:/Sourish/OFDM/OFDM Simulation/Verification_Files/frame_with_cp.txt",
            expected_words
        );
    end

    top DUT (
        .clk       (clk),
        .n_rst     (n_rst),
        .start     (start),

        .out_data  (out_data),
        .out_valid (out_valid),
        .out_ready (out_ready),

        .seq_done  (seq_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    assign out_ready = 1'b1;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            byte_count <= 0;
        end else begin
            if (out_valid && out_ready) begin
                if (byte_count < TOTAL_BYTES) begin
                    got_bytes[byte_count] <= out_data;
                    byte_count <= byte_count + 1;
                end
            end
        end
    end

    function automatic logic [7:0] expected_byte(input int byte_idx);
    int sample_idx;
    int byte_sel;
    logic [31:0] word;
    begin
        sample_idx = byte_idx / 4;
        byte_sel   = byte_idx % 4;
        word       = expected_words[sample_idx];

        case (byte_sel)
            0: expected_byte = word[23:16]; // re low byte
            1: expected_byte = word[31:24]; // re high byte
            2: expected_byte = word[7:0];   // im low byte
            3: expected_byte = word[15:8];  // im high byte
            default: expected_byte = 8'hxx;
        endcase
    end
endfunction

    initial begin
        start  = 1'b0;
        n_rst  = 1'b0;
        errors = 0;

        repeat (5) @(negedge clk);
        n_rst = 1'b1;

        repeat (5) @(negedge clk);

        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        fork
            begin
                wait (byte_count == TOTAL_BYTES);
            end

            begin
                repeat (TIMEOUT_CYCLES) @(posedge clk);

                $display("========== TIMEOUT ==========");
                $display("byte_count = %0d / %0d", byte_count, TOTAL_BYTES);
                $display("seq_done   = %0b", seq_done);

                $display("FIFO: out_valid=%0b out_ready=%0b",
                    DUT.u_fifo.out_valid,
                    DUT.u_fifo.out_ready
                );

                $display("SER: in_valid=%0b in_ready=%0b out_valid=%0b out_ready=%0b out_data=%02h",
                    DUT.u_ser.in_valid,
                    DUT.u_ser.in_ready,
                    DUT.u_ser.out_valid,
                    DUT.u_ser.out_ready,
                    DUT.u_ser.out_data
                );

                $display("SER state=%0d byte_idx=%0d",
                    DUT.u_ser.state,
                    DUT.u_ser.byte_idx
                );

                $fatal(1, "Timed out before receiving all serialized bytes.");
            end
        join_any

        disable fork;

        @(negedge clk);

        for (int i = 0; i < TOTAL_SAMPLES; i++) begin
    logic signed [15:0] got_re, got_im;
    logic signed [15:0] exp_re, exp_im;
    int re_err;
    int im_err;

    // Serializer order: re_lo, re_hi, im_lo, im_hi
    got_re = {got_bytes[4*i + 1], got_bytes[4*i + 0]};
    got_im = {got_bytes[4*i + 3], got_bytes[4*i + 2]};

    exp_re = expected_words[i][31:16];
    exp_im = expected_words[i][15:0];

    re_err = (got_re > exp_re) ? int'(got_re - exp_re) : int'(exp_re - got_re);
    im_err = (got_im > exp_im) ? int'(got_im - exp_im) : int'(exp_im - got_im);

    if (re_err > 2 || im_err > 2) begin
        $display(
            "FAIL sample[%0d]: expected re=%0d im=%0d, got re=%0d im=%0d, err=%0d/%0d",
            i, exp_re, exp_im, got_re, got_im, re_err, im_err
        );
        errors++;
    end
end
if (errors == 0) begin
    $display("========== PASS: ALL %0d SERIALIZED SAMPLES MATCH ==========", TOTAL_SAMPLES);
end else begin
    $display("========== FAIL: %0d SAMPLE ERRORS ==========", errors);
end

        $finish;
    end

endmodule