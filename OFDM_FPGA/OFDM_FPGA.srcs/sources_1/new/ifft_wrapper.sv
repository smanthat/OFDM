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
import fixed_pkg::*;

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
    logic s_axis_data_tvalid, s_axis_data_tready;
    logic s_axis_data_tlast;

    logic [31:0] m_axis_data_tdata;
    logic m_axis_data_tvalid, m_axis_data_tready;
    logic m_axis_data_tlast;

    logic [5:0] counter;

    xfft_0 u1 (.aclk(clk),
               .s_axis_config_tdata(s_axis_config_tdata),
               .s_axis_config_tready(s_axis_config_tready),
               .s_axis_config_tvalid(s_axis_config_tvalid),
               .s_axis_data_tdata(s_axis_data_tdata),
               .s_axis_data_tvalid(s_axis_data_tvalid),
               .s_axis_data_tready(s_axis_data_tready),
               .s_axis_data_tlast(s_axis_data_tlast),
               .m_axis_data_tdata(m_axis_data_tdata),
               .m_axis_data_tvalid(m_axis_data_tvalid),
               .m_axis_data_tready(m_axis_data_tready),
               .m_axis_data_tlast(m_axis_data_tlast));

    // Track whether config has been accepted by the XFFT
    logic cfg_done;
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) cfg_done <= 1'b0;
        else if (s_axis_config_tvalid && s_axis_config_tready) cfg_done <= 1'b1;
    end

    // Config: assert tvalid until accepted, then stop.
    // The XFFT will accept whenever it's ready. We don't gate data on this.
    assign s_axis_config_tvalid = !cfg_done;
    assign s_axis_config_tdata  = 8'h54;

    // Counter for tlast on the 64th input sample
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) counter <= 0;
        else if (s_axis_data_tvalid && s_axis_data_tready) begin
            if (counter == 6'd63) counter <= 0;
            else                  counter <= counter + 1;
        end
    end

    // Data path — no gate on config state, flows immediately
    assign s_axis_data_tdata  = {in_data.im, in_data.re};
    assign s_axis_data_tvalid = in_valid;
    assign in_ready           = s_axis_data_tready;
    assign s_axis_data_tlast  = (counter == 6'd63) && s_axis_data_tvalid;

    // Output
    assign out_data.re         = m_axis_data_tdata[15:0];
    assign out_data.im         = m_axis_data_tdata[31:16];
    assign out_valid           = m_axis_data_tvalid;
    assign m_axis_data_tready  = out_ready;
    assign out_last            = m_axis_data_tlast;

endmodule