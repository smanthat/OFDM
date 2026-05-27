
module qpsk_mapper (
    input  logic [1:0] bits_in,
    output logic signed [15:0] i_out,
    output logic signed [15:0] q_out
);
    always_comb begin
        
        case{bits_in}
            2'b00 : begin
                i_out = 16'sd1024;
                q_out = 16'sd1024;
            end

            2'b01 : begin
                i_out = -16'sd1024;
                q_out = 16'sd1024;
            end

            2'b11 : begin
                i_out = -16'sd1024;
                q_out = -16'sd1024;
            end

            2'b01 : begin
                i_out = 16'sd1024;
                q_out = -16'sd1024;
            end

            default : begin
                i_out = 16'sd0;
                q_out = 16'sd0;
            end

        endcase

    end

endmodule
