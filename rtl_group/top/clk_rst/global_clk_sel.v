`timescale 1ns / 1ps

module global_clk_sel (

    input wire clk,
    input wire[1:0] chip_sel_i,

    output wire clk_wzc,
    output wire clk_xyh,
    output wire clk_hjx,
    output wire clk_xzr

    );

    wire en_wzc;
    wire en_xyh;
    wire en_hjx;
    wire en_xzr;

    assign en_wzc = (chip_sel_i == 2'b00);
    assign en_xyh = (chip_sel_i == 2'b01);
    assign en_hjx = (chip_sel_i == 2'b10);
    assign en_xzr = (chip_sel_i == 2'b11);

    kalsit_icg u_icg_wzc (.clk_i(clk), .en_i(en_wzc), .clk_o(clk_wzc));
    kalsit_icg u_icg_xyh (.clk_i(clk), .en_i(en_xyh), .clk_o(clk_xyh));
    kalsit_icg u_icg_hjx (.clk_i(clk), .en_i(en_hjx), .clk_o(clk_hjx));
    kalsit_icg u_icg_xzr (.clk_i(clk), .en_i(en_xzr), .clk_o(clk_xzr));

endmodule
