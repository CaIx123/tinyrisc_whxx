// 输入同步器模块
// 将输入信号打DP拍后输出，用于跨时钟域同步
// 本质是一个带深度参数(DP)的移位寄存器同步器
module gen_ticks_sync_xyh #(
    parameter DP = 2,
    parameter DW = 32)(

    input wire rst_n,                        // 复位(低有效)
    input wire clk,                          // 时钟

    input wire[DW-1:0] din,                  // 输入数据
    output wire[DW-1:0] dout                 // 同步后输出数据

    );

    wire[DW-1:0] sync_dat[DP-1:0];

    genvar i;

    generate 
        for (i = 0; i < DP; i = i + 1) begin: ticks_sync
            if (i == 0) begin: dp_is_0
                gen_rst_0_dff_xyh #(DW) rst_0_dff(clk, rst_n, din, sync_dat[0]);
            end else begin: dp_is_not_0
                gen_rst_0_dff_xyh #(DW) rst_0_dff(clk, rst_n, sync_dat[i-1], sync_dat[i]);
            end
        end
    endgenerate

    assign dout = sync_dat[DP-1];
  
endmodule
