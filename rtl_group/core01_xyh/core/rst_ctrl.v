`include "defines_xyh.v"

// 复位控制模块
// 统一处理外部复位(rst_ext_i)与调试复位(rst_jtag_i)
// 外部复位先经过2级同步器同步后再送入核心
// JTAG复位(当前版本固定为0)通过移位寄存器产生可配置深度的复位序列
module rst_ctrl_xyh(

    input wire clk,                          // 时钟

    input wire rst_ext_i,                    // 外部复位输入
    input wire rst_jtag_i,                   // JTAG复位输入(当前版本固定为0)

    output wire core_rst_n_o,                // 处理器核复位(低有效)
    output wire jtag_rst_n_o                 // JTAG复位(低有效)

    );

    wire ext_rst_r;

    gen_ticks_sync_xyh #(
        .DP(2),
        .DW(1)
    ) ext_rst_sync(
        .rst_n(rst_ext_i),
        .clk(clk),
        .din(1'b1),
        .dout(ext_rst_r)
    );

    reg[`JTAG_RESET_FF_LEVELS-1:0] jtag_rst_r;

    always @ (posedge clk) begin
        if (!rst_ext_i) begin
            jtag_rst_r[`JTAG_RESET_FF_LEVELS-1:0] <= {`JTAG_RESET_FF_LEVELS{1'b1}};
        end else if (rst_jtag_i) begin
            jtag_rst_r[`JTAG_RESET_FF_LEVELS-1:0] <= {`JTAG_RESET_FF_LEVELS{1'b0}};
        end else begin
            jtag_rst_r[`JTAG_RESET_FF_LEVELS-1:0] <= {jtag_rst_r[`JTAG_RESET_FF_LEVELS-2:0], 1'b1};
        end
    end

    assign core_rst_n_o = ext_rst_r & jtag_rst_r[`JTAG_RESET_FF_LEVELS-1];
    assign jtag_rst_n_o = ext_rst_r;

endmodule
