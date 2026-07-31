`timescale 1ns / 1ps

// 复位控制模块
module global_rst_ctrl(
    input wire clk,
    input wire rst_ext_i,
    output wire rst_n_o
    );

    wire ext_rst_r;

    gen_ticks_sync #(
        .DP(2),
        .DW(1)
    ) ext_rst_sync(
        .rst_n(rst_ext_i),
        .clk(clk),
        .din(1'b1),
        .dout(ext_rst_r)
    );

    assign rst_n_o = ext_rst_r;

endmodule
