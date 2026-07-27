`include "defines.v"

// 将指令向译码模块传递
module if_id(

    input wire clk,
    input wire rst,

    input wire[`InstBus] inst_i,            // 指令内容
    input wire[`InstAddrBus] inst_addr_i,   // 指令地址

    input wire[`Hold_Flag_Bus] hold_flag_i, // 流水线暂停标志

    // [已注释] 中断相关端口
    // input wire[`INT_BUS] int_flag_i,        // 外设中断输入信号
    // output wire[`INT_BUS] int_flag_o,

    input wire flush_i,                     // 冲刷使能

    output wire[`InstBus] inst_o,           // 指令内容
    output wire[`InstAddrBus] inst_addr_o   // 指令地址

    );


    wire hold_en = (hold_flag_i >= `Hold_If);
    reg hold_en2;
    
 always @(posedge clk) begin
    if (!rst) begin
        // 复位时，将 hold_en2 初始化为默认值（通常为 0）
        hold_en2 <= 1'b0;
    end else begin
        // 在每个时钟上升沿，将当前 hold_en 的值赋给 hold_en2
        // 这会导致 hold_en2 的更新比 hold_en 晚一个时钟周期
        hold_en2 <= hold_en;
    end
end    

    wire[`InstBus] inst;
    // 使用复位使能信号：当reset_en有效时，强制输出INST_NOP
    gen_pipe_dff #(32) inst_ff(clk, rst, hold_en, flush_i, `INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`InstAddrBus] inst_addr;
    gen_pipe_dff #(32) inst_addr_ff(clk, rst, hold_en, flush_i, `ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

    // [已注释] 中断信号打拍传递逻辑
    // wire[`INT_BUS] int_flag;
    // gen_pipe_dff #(8) int_ff(clk, rst, hold_en, flush_i, `INT_NONE, int_flag_i, int_flag);
    // assign int_flag_o = int_flag;

endmodule