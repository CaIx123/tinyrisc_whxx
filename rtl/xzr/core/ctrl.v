
`include "defines.v"

module ctrl(
    input wire rst,

    // from ex
    input wire jump_flag_i,
    input wire[`InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,

    // [新增] from pc_reg (IF阶段)
    input wire hold_flag_if_i,

    // from rib
    input wire hold_flag_rib_i,

    // from jtag
    //input wire jtag_halt_flag_i,

    // from clint
    //input wire hold_flag_clint_i,

    output reg[`Hold_Flag_Bus] hold_flag_o,

    // to pc_reg
    output reg jump_flag_o,
    output reg[`InstAddrBus] jump_addr_o,
        // [新增] 用于重置 IF 计数器的信号
    output wire reset_if_cnt_o ,
    
    output wire flush_o

    );

    assign reset_if_cnt_o = (hold_flag_ex_i == `HoldEnable );
                             //||
                             //hold_flag_rib_i == `HoldEnable
    /*assign reset_if_cnt_o = (hold_flag_ex_i == `HoldEnable || 
                             jtag_halt_flag_i == `HoldEnable);*/
    
    assign flush_o = jump_flag_o;
    
    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;
        
        // 默认不暂停
        hold_flag_o = `Hold_None;

        // 按优先级处理不同模块的请求
        // 优先级：跳转 > (中断/EX访存/IF取指) > JTAG > RIB总线仲裁
        
        if (hold_flag_ex_i == `HoldEnable || 
                 hold_flag_if_i == `HoldEnable) begin 
            hold_flag_o = `Hold_Id;
        end 
        
        else if (hold_flag_rib_i == `HoldEnable) begin
            // 总线忙，只暂停PC，即取指地址不变
            hold_flag_o = `Hold_Pc;
        end 
        else begin
            hold_flag_o = `Hold_None;
        end
    end

endmodule