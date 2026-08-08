`timescale 1ns / 1ps

module global_clk_sel (

    input wire clk,
    input wire[1:0] chip_sel_i,

    output wire clk_wzc,
    output wire clk_xyh,
    output wire clk_hjx,
    output wire clk_xzr

    );

    assign clk_wzc = clk;
    assign clk_xyh = clk;
    assign clk_hjx = clk;
    assign clk_xzr = clk;

endmodule
