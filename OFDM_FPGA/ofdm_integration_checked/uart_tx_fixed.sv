`timescale 1ns / 1ps

// Drop-in-safe UART transmitter for integration.
// It LATCHES data_in when data_valid is accepted, so the upstream byte source
// is allowed to change out_data after the accept cycle.
module uart_tx_fixed #(
    parameter int CLK_HZ   = 100_000_000,
    parameter int BAUD     = 115_200,
    parameter int BAUD_DIV = CLK_HZ / BAUD
)(
    input  logic       clk,
    input  logic       n_rst,
    input  logic [7:0] data_in,
    input  logic       data_valid,
    output logic       tx_out,
    output logic       busy
);

    typedef enum logic [3:0] {
        IDLE  = 4'd0,
        START = 4'd1,
        DATA0 = 4'd2,
        DATA1 = 4'd3,
        DATA2 = 4'd4,
        DATA3 = 4'd5,
        DATA4 = 4'd6,
        DATA5 = 4'd7,
        DATA6 = 4'd8,
        DATA7 = 4'd9,
        STOP  = 4'd10
    } state_t;

    state_t state;

    logic [7:0] data_reg;
    logic [$clog2(BAUD_DIV)-1:0] baud_counter;
    logic baud_tick;

    assign baud_tick = (baud_counter == BAUD_DIV - 1);

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state        <= IDLE;
            data_reg     <= 8'h00;
            baud_counter <= '0;
        end else begin
            case (state)
                IDLE: begin
                    baud_counter <= '0;
                    if (data_valid) begin
                        data_reg <= data_in;
                        state    <= START;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA0;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA0: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA1;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA1: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA2;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA2: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA3;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA3: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA4;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA4: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA5;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA5: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA6;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA6: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= DATA7;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DATA7: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= STOP;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        baud_counter <= '0;
                        state <= IDLE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                default: begin
                    state        <= IDLE;
                    baud_counter <= '0;
                end
            endcase
        end
    end

    always_comb begin
        tx_out = 1'b1;
        busy   = (state != IDLE);

        case (state)
            IDLE:  tx_out = 1'b1;
            START: tx_out = 1'b0;
            DATA0: tx_out = data_reg[0];
            DATA1: tx_out = data_reg[1];
            DATA2: tx_out = data_reg[2];
            DATA3: tx_out = data_reg[3];
            DATA4: tx_out = data_reg[4];
            DATA5: tx_out = data_reg[5];
            DATA6: tx_out = data_reg[6];
            DATA7: tx_out = data_reg[7];
            STOP:  tx_out = 1'b1;
            default: tx_out = 1'b1;
        endcase
    end

endmodule
