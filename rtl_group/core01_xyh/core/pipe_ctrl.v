`include "defines.v"

// 流水线控制模块
// 统一产生stall(暂停)和flush(冲刷)信号
// 输入来自IFU的取指暂停、IDU的译码暂停、EXU的执行暂停
// jump_assert_i出发flush_o清空流水线，同时输出跳转目标地址
module pipe_ctrl_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire stall_from_if_i,              // IFU取指暂停(请求未返回)
    input wire stall_from_id_i,              // IDU暂停(分支指令)
    input wire[1:0] stall_from_ex_i,         // EXU暂停(访存/乘除/扩展)
    input wire stall_from_jtag_i,            // JTAG暂停(未使用)
    input wire jump_assert_i,                // 跳转断言(触发刷洗)
    input wire[31:0] jump_addr_i,            // 跳转目标地址

    output wire flush_o,                     // 流水线冲刷
    output wire[`STALL_WIDTH-1:0] stall_o,   // 流水线暂停(PC/IF/ID/EX各级)
    output wire[31:0] flush_addr_o           // 冲刷后新PC(跳转地址)

    );

    assign flush_addr_o = jump_addr_i;
    assign flush_o = jump_assert_i;

    reg[`STALL_WIDTH-1:0] stall;

    always @ (*) begin
        stall[`STALL_EX] = stall_from_if_i;
        stall[`STALL_ID] = stall_from_ex_i[0] | stall_from_if_i;
        stall[`STALL_IF] = stall_from_ex_i[0];
        stall[`STALL_PC] = stall_from_ex_i[1] | stall_from_id_i; //stall_from_id_i;// 
        // if (stall_from_ex_i) begin
        //     // stall[`STALL_EX] = 1'b0;
        //     stall[`STALL_ID] = 1'b1;
        //     stall[`STALL_IF] = 1'b1;
        //     stall[`STALL_PC] = 1'b1;
        // end else if (stall_from_id_i) begin
        //     // stall[`STALL_EX] = 1'b0;
        //     stall[`STALL_ID] = 1'b0;
        //     stall[`STALL_IF] = 1'b0;
        //     stall[`STALL_PC] = 1'b1;
        // end else if (stall_from_if_i) begin
        //     // stall[`STALL_EX] = 1'b1;
        //     stall[`STALL_ID] = 1'b1;
        //     stall[`STALL_IF] = 1'b0;
        //     stall[`STALL_PC] = 1'b0;
        // end else begin
        //     // stall[`STALL_EX] = 1'b0;
        //     stall[`STALL_ID] = 1'b0;
        //     stall[`STALL_IF] = 1'b0;
        //     stall[`STALL_PC] = 1'b0;
        // end
    end

    assign stall_o = stall;

endmodule
