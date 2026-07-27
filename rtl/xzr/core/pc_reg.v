`include "defines.v"

module pc_reg(

    input wire clk,
    input wire rst,

    input wire jump_flag_i,                 // 跳转标志
    input wire[`InstAddrBus] jump_addr_i,   // 跳转地址
    input wire[`Hold_Flag_Bus] hold_flag_i, // 来自 ctrl 的全局暂停标志

    output reg[`InstAddrBus] pc_o,          // PC指针
    output wire hold_flag_if_o,              // [新增] 输出给 ctrl 的暂停请求

    input wire reset_if_cnt_i // [新增]
    );

    // [新增] ROM 读取等待计数器
    reg [2:0] rom_wait_cnt;

    // 逻辑：只要计数器没数到 5 (即还没过6个周期)，就请求暂停
    assign hold_flag_if_o = (rom_wait_cnt < 3'd5) ? `HoldEnable : `HoldDisable;

// [修改后的] ROM 读取等待计数器逻辑
    always @ (posedge clk) begin
        // 1. 复位、跳转 或 [新增：被别的流水线阶段暂停] 
        // 只要系统处于忙碌或被阻塞状态，计数器就强制清零
        if (rst == `RstEnable ||  reset_if_cnt_i == 1'b1) begin    // jump_flag_i == `JumpEnable
            rom_wait_cnt <= 3'd0;
        end 
        // 2. 正常计数
        else if (rom_wait_cnt < 3'd5) begin
            rom_wait_cnt <= rom_wait_cnt + 1'b1;
        end 
        // 3. 计数完成，归零准备下一次
        else begin
            rom_wait_cnt <= 3'd0;
        end
    end

    always @ (posedge clk) begin
        // 复位
        if (rst == `RstEnable) begin
            pc_o <= `CpuResetAddr;
        // 跳转
        end else if (jump_flag_i == `JumpEnable) begin
            pc_o <= jump_addr_i;
        // 暂停：如果是 Hold_Pc 以上等级，锁住 PC
        end else if (hold_flag_i >= `Hold_Pc) begin
            pc_o <= pc_o;
        // 地址加4
        end else begin
            pc_o <= pc_o + 4'h4;
        end
    end

endmodule