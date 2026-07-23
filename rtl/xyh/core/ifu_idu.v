`include "defines.v"

// IF/ID级流水寄存器
// 将取指阶段的指令和PC锁存后传递给译码阶段
// flush时插入NOP指令清空流水线
// STALL_IF时保持原值不更新
module ifu_idu(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire[31:0] inst_i,                 // 指令内容(来自IFU)
    input wire[31:0] inst_addr_i,            // 指令地址(来自IFU)
    input wire[`STALL_WIDTH-1:0] stall_i,    // 流水线暂停
    input wire flush_i,                      // 流水线冲刷
    input wire inst_valid_i,                 // 指令有效标志

    output wire[31:0] inst_o,                // 指令内容(送至IDU)
    output wire[31:0] inst_addr_o            // 指令地址(送至IDU)

    );

    wire en = (!stall_i[`STALL_IF] | flush_i);

    wire[31:0] i_inst = (flush_i)? `INST_NOP: inst_i;
    wire[31:0] inst;
    gen_en_dff #(32) inst_ff(clk, rst_n, en, i_inst, inst);
    assign inst_o = inst;

    wire[31:0] i_inst_addr = flush_i? 32'h0: inst_addr_i;
    wire[31:0] inst_addr;
    gen_en_dff #(32) inst_addr_ff(clk, rst_n, en, i_inst_addr, inst_addr);
    assign inst_addr_o = inst_addr;

endmodule
