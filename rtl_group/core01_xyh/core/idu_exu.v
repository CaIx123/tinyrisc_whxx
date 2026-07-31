`timescale 1ns / 1ps

`include "defines_xyh.v"

// ID/EX级流水寄存器
// 将译码阶段的译码信息、源寄存器值、立即数、PC等锁存后传递给执行阶段
// flush时清空所有输出
// STALL_ID时保持原值
module idu_exu_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire[`XYH_STALL_WIDTH-1:0] stall_i,    // 流水线暂停
    input wire flush_i,                      // 流水线冲刷

    input wire[31:0] inst_i,                 // 指令(来自IDU)
    input wire[`XYH_DECINFO_WIDTH-1:0] dec_info_bus_i,  // 译码信息总线(来自IDU)
    input wire[31:0] dec_imm_i,              // 立即数(来自IDU)
    input wire[31:0] dec_pc_i,               // 指令PC(来自IDU)
    input wire[31:0] rs1_rdata_i,            // rs1读数据(来自IDU)
    input wire[31:0] rs2_rdata_i,            // rs2读数据(来自IDU)
    input wire[4:0] rd_waddr_i,              // 目标寄存器地址(来自IDU)
    input wire rd_we_i,                      // 寄存器写使能(来自IDU)

    output wire[31:0] inst_o,                // 指令(送至EXU)
    output wire[`XYH_DECINFO_WIDTH-1:0] dec_info_bus_o,  // 译码信息总线(送至EXU)
    output wire[31:0] dec_imm_o,             // 立即数(送至EXU)
    output wire[31:0] dec_pc_o,              // 指令PC(送至EXU)
    output wire[31:0] rs1_rdata_o,           // rs1读数据(送至EXU)
    output wire[31:0] rs2_rdata_o,           // rs2读数据(送至EXU)
    output wire[4:0] rd_waddr_o,             // 目标寄存器地址(送至EXU)
    output wire rd_we_o                      // 寄存器写使能(送至EXU)

    );

    wire en = !stall_i[`XYH_STALL_ID] | flush_i;

    wire[`XYH_DECINFO_WIDTH-1:0] i_dec_info_bus = flush_i? {`XYH_DECINFO_WIDTH{1'b0}}: dec_info_bus_i;
    wire[`XYH_DECINFO_WIDTH-1:0] dec_info_bus;
    gen_en_dff_xyh #(`XYH_DECINFO_WIDTH) info_bus_ff(clk, rst_n, en, i_dec_info_bus, dec_info_bus);
    assign dec_info_bus_o = dec_info_bus;

    wire[31:0] i_dec_imm = flush_i? 32'h0: dec_imm_i;
    wire[31:0] dec_imm;
    gen_en_dff_xyh #(32) imm_ff(clk, rst_n, en, i_dec_imm, dec_imm);
    assign dec_imm_o = dec_imm;

    wire[31:0] i_dec_pc = flush_i? 32'h0: dec_pc_i;
    wire[31:0] dec_pc;
    gen_en_dff_xyh #(32) pc_ff(clk, rst_n, en, i_dec_pc, dec_pc);
    assign dec_pc_o = dec_pc;

    wire[31:0] i_rs1_rdata = flush_i? 32'h0: rs1_rdata_i;
    wire[31:0] rs1_rdata;
    gen_en_dff_xyh #(32) rs1_rdata_ff(clk, rst_n, en, i_rs1_rdata, rs1_rdata);
    assign rs1_rdata_o = rs1_rdata;

    wire[31:0] i_rs2_rdata = flush_i? 32'h0: rs2_rdata_i;
    wire[31:0] rs2_rdata;
    gen_en_dff_xyh #(32) rs2_rdata_ff(clk, rst_n, en, i_rs2_rdata, rs2_rdata);
    assign rs2_rdata_o = rs2_rdata;

    wire[4:0] i_rd_waddr = flush_i? 5'h0: rd_waddr_i;
    wire[4:0] rd_waddr;
    gen_en_dff_xyh #(5) rd_waddr_ff(clk, rst_n, en, i_rd_waddr, rd_waddr);
    assign rd_waddr_o = rd_waddr;

    wire i_rd_we = flush_i? 1'b0: rd_we_i;
    wire rd_we;
    gen_en_dff_xyh #(1) rd_we_ff(clk, rst_n, en, i_rd_we, rd_we);
    assign rd_we_o = rd_we;

    wire[31:0] i_inst = flush_i? 32'h0: inst_i;
    wire[31:0] inst;
    gen_en_dff_xyh #(32) inst_ff(clk, rst_n, en, i_inst, inst);
    assign inst_o = inst;

endmodule
