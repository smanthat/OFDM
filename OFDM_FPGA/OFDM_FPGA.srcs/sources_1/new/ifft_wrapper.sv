`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/21/2026 07:54:31 PM
// Design Name: 
// Module Name: ifft_wrapper
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

import  fixed_pkg::*;
typedef enum logic { 
    CONFIG = 0,
    RUN = 1
 } state_t;

module ifft_wrapper(
    input logic clk, n_rst,
    input cplx_t in_data,
    output logic in_ready,
    input logic in_valid,
    output cplx_t out_data,
    output logic out_valid,
    input logic out_ready,
    output logic out_last
    );
    logic [7:0] s_axis_config_tdata;
    logic s_axis_config_tvalid, s_axis_config_tready;

    logic [31:0] s_axis_data_tdata;
    logic s_axis_data_tvalid,s_axis_data_tready;
    logic s_axis_data_tlast;

    logic [31:0] m_axis_data_tdata;
    logic m_axis_data_tvalid,m_axis_data_tready;
    logic m_axis_data_tlast;

    logic [5:0] counter;

    xfft_0 u1 (.aclk(clk),.s_axis_config_tdata(s_axis_config_tdata),
                .s_axis_config_tready(s_axis_config_tready),.s_axis_config_tvalid(s_axis_config_tvalid),
                .s_axis_data_tdata(s_axis_data_tdata),.s_axis_data_tvalid(s_axis_data_tvalid),
                .s_axis_data_tready(s_axis_data_tready),.s_axis_data_tlast(s_axis_data_tlast),
                .m_axis_data_tdata(m_axis_data_tdata),.m_axis_data_tvalid(m_axis_data_tvalid),
                .m_axis_data_tready(m_axis_data_tready),.m_axis_data_tlast(m_axis_data_tlast));


    state_t state, n_state;

    always_ff @(posedge clk or negedge n_rst)begin
        if(~n_rst) state <= CONFIG;
        else state <= n_state;
    end

    always_comb begin
        n_state = state;
        case(state)
            CONFIG : if(s_axis_config_tvalid && s_axis_config_tready) begin
                n_state = RUN;
            end
            default : n_state = CONFIG;
        endcase
    end

    always_ff @( posedge clk or negedge n_rst ) begin : blockName
        if(~n_rst) counter <= 0;
        else if(state == CONFIG) counter <= 0;
        else if(counter != 6'b111111 && in_valid && in_ready) counter <= counter + 1;
        else if(in_valid && in_ready) counter <= 0;
    end


    always_comb begin
        s_axis_config_tdata = 8'h54;
        s_axis_data_tdata = {in_data.im, in_data.re};
        s_axis_data_tvalid = (state == RUN) && in_valid;
        in_ready = (state == RUN) && s_axis_data_tready;
        s_axis_data_tlast = (counter == 6'd63) && s_axis_data_tvalid;

        out_data.re = m_axis_data_tdata[15:0];
        out_data.im = m_axis_data_tdata[31:16];
        out_valid = m_axis_data_tvalid; 
        m_axis_data_tready = out_ready;
        out_last = m_axis_data_tlast;
            
        case(state)
            CONFIG :   s_axis_config_tvalid = 1;
            RUN    :   s_axis_config_tvalid = 0;
            default : s_axis_config_tvalid = 1;
        endcase
    end

endmodule
