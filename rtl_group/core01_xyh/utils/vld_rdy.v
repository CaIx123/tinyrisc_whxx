`timescale 1ns / 1ps

// valid-ready握手缓冲模块
// 内部用1bit vld_r记录当前stage是否已满
// CUT_READY=0时rdy_o可能组合依赖rdy_i
// CUT_READY=1时ready路径被切断，仅当stage不满才接受新输入
module vld_rdy_xyh #(
    parameter CUT_READY = 0)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire vld_i,                        // 输入有效
    output wire rdy_o,                       // 输出就绪(可接收)
    input wire rdy_i,                        // 下一级就绪
    output wire vld_o                        // 输出有效

    );

    wire vld_set;
    wire vld_clr;
    wire vld_ena;
    wire vld_r;
    wire vld_nxt;

    // The valid will be set when input handshaked
    assign vld_set = vld_i & rdy_o;
    // The valid will be clr when output handshaked
    assign vld_clr = vld_o & rdy_i;

    assign vld_ena = vld_set | vld_clr;
    assign vld_nxt = vld_set | (~vld_clr);

    gen_en_dff_xyh #(1) vld_dff(clk, rst_n, vld_ena, vld_nxt, vld_r);

    assign vld_o = vld_r;

    if (CUT_READY == 1) begin
        // If cut ready, then only accept when stage is not full
        assign rdy_o = (~vld_r);
    end else begin
        // If not cut ready, then can accept when stage is not full or it is popping 
        assign rdy_o = (~vld_r) | vld_clr;
    end

endmodule
