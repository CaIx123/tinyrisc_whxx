`include "../../top/macros.v"

module pc_reg_xzr(

    input wire clk,
    input wire rst,

    input wire jump_flag_i,                 // 跳转标志
    input wire[`InstAddrBus] jump_addr_i,   // 跳转地址
    input wire[`Hold_Flag_Bus] hold_flag_i, // 来自 ctrl_xzr 的全局暂停标志

    output reg[`InstAddrBus] pc_o,          // PC指针
    output wire hold_flag_if_o,
    input wire if_busy_i,

    input wire reset_if_cnt_i // [新增]
    );

    // [新增] ROM 读取等待计数器
    reg [2:0] rom_wait_cnt;

    // 逻辑：只要计数器没数到 5 (即还没过6个周期)，就请求暂停
    assign hold_flag_if_o = if_busy_i ? `HoldEnable : `HoldDisable;

// [修改后的] ROM 读取等待计数器逻辑
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