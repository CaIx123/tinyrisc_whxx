`timescale 1ns / 1ps

 /*
 Copyright 2019 Blue Liang, liangkangnan@163.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

`include "defines_hjx.v"

// 执行模块
// 纯组合逻辑电路
module exu_hjx(

    input wire clk,
    input wire rst_n,


    // mem
    input wire[31:0] mem_rdata_i,           // 内存输入数据
    input wire mem_req_ready_i,
    input wire mem_rsp_valid_i,
    output wire[31:0] mem_wdata_o,          // 写内存数据
    output wire[31:0] mem_addr_o,           // 读、写内存地址
    output wire mem_we_o,                   // 是否要写内存
    output wire[3:0] mem_sel_o,             // 字节位
    output wire mem_req_valid_o,
    output wire mem_rsp_ready_o,
    output wire mem_access_misaligned_o,

    // gpr_reg
    output wire[31:0] reg_wdata_o,          // 写寄存器数据
    output wire reg_we_o,                   // 是否要写通用寄存器
    output wire[4:0] reg_waddr_o,           // 写通用寄存器地址


    // to pipe_ctrl_hjx
    output wire hold_flag_o,                // 是否暂停标志
    output wire jump_flag_o,                // 是否跳转标志
    output wire[31:0] jump_addr_o,          // 跳转目的地址

    // from idu_exu_hjx
    input wire[`HJX_DECINFO_WIDTH-1:0] dec_info_bus_i,
    input wire[31:0] dec_imm_i,
    input wire[31:0] dec_pc_i,
    input wire[31:0] next_pc_i,
    input wire[4:0] rd_waddr_i,
    input wire[31:0] reg1_rdata_i,          // 通用寄存器1输入数据
    input wire[31:0] reg2_rdata_i,          // 通用寄存器2输入数据
    input wire rd_we_i

    );

    // dispatch to ALU
    wire[31:0] alu_op1_o;
    wire[31:0] alu_op2_o;
    wire req_alu_o;
    wire alu_op_lui_o;
    wire alu_op_auipc_o;
    wire alu_op_add_o;
    wire alu_op_sub_o;
    wire alu_op_sll_o;
    wire alu_op_slt_o;
    wire alu_op_sltu_o;
    wire alu_op_xor_o;
    wire alu_op_srl_o;
    wire alu_op_sra_o;
    wire alu_op_or_o;
    wire alu_op_and_o;
    // dispatch to BJP
    wire[31:0] bjp_op1_o;
    wire[31:0] bjp_op2_o;
    wire[31:0] bjp_jump_op1_o;
    wire[31:0] bjp_jump_op2_o;
    wire req_bjp_o;
    wire bjp_op_jump_o;
    wire bjp_op_beq_o;
    wire bjp_op_bne_o;
    wire bjp_op_blt_o;
    wire bjp_op_bltu_o;
    wire bjp_op_bge_o;
    wire bjp_op_bgeu_o;
    // dispatch to MEM
    wire req_mem_o;
    wire[31:0] mem_op1_o;
    wire[31:0] mem_op2_o;
    wire[31:0] mem_rs2_data_o;
    wire mem_op_lb_o;
    wire mem_op_lh_o;
    wire mem_op_lw_o;
    wire mem_op_lbu_o;
    wire mem_op_lhu_o;
    wire mem_op_sb_o;
    wire mem_op_sh_o;
    wire mem_op_sw_o;
    // dispatch to SYS
    wire sys_op_nop_o;
    wire sys_op_fence_o;
    // dispatch to EXT
    wire req_ext_o;
    wire ext_op_sid_o;
    wire ext_op_rt_o;
    wire ext_op_if_o;

    exu_dispatch_hjx u_exu_dispatch(
        // input
        .clk(clk),
        .rst_n(rst_n),
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i(dec_imm_i),
        .dec_pc_i(dec_pc_i),
        .rs1_rdata_i(reg1_rdata_i),
        .rs2_rdata_i(reg2_rdata_i),
        // dispatch to ALU
        .alu_op1_o(alu_op1_o),
        .alu_op2_o(alu_op2_o),
        .req_alu_o(req_alu_o),
        .alu_op_lui_o(alu_op_lui_o),
        .alu_op_auipc_o(alu_op_auipc_o),
        .alu_op_add_o(alu_op_add_o),
        .alu_op_sub_o(alu_op_sub_o),
        .alu_op_sll_o(alu_op_sll_o),
        .alu_op_slt_o(alu_op_slt_o),
        .alu_op_sltu_o(alu_op_sltu_o),
        .alu_op_xor_o(alu_op_xor_o),
        .alu_op_srl_o(alu_op_srl_o),
        .alu_op_sra_o(alu_op_sra_o),
        .alu_op_or_o(alu_op_or_o),
        .alu_op_and_o(alu_op_and_o),
        // dispatch to BJP
        .bjp_op1_o(bjp_op1_o),
        .bjp_op2_o(bjp_op2_o),
        .bjp_jump_op1_o(bjp_jump_op1_o),
        .bjp_jump_op2_o(bjp_jump_op2_o),
        .req_bjp_o(req_bjp_o),
        .bjp_op_jump_o(bjp_op_jump_o),
        .bjp_op_beq_o(bjp_op_beq_o),
        .bjp_op_bne_o(bjp_op_bne_o),
        .bjp_op_blt_o(bjp_op_blt_o),
        .bjp_op_bltu_o(bjp_op_bltu_o),
        .bjp_op_bge_o(bjp_op_bge_o),
        .bjp_op_bgeu_o(bjp_op_bgeu_o),
        // dispatch to MEM
        .req_mem_o(req_mem_o),
        .mem_op1_o(mem_op1_o),
        .mem_op2_o(mem_op2_o),
        .mem_rs2_data_o(mem_rs2_data_o),
        .mem_op_lb_o(mem_op_lb_o),
        .mem_op_lh_o(mem_op_lh_o),
        .mem_op_lw_o(mem_op_lw_o),
        .mem_op_lbu_o(mem_op_lbu_o),
        .mem_op_lhu_o(mem_op_lhu_o),
        .mem_op_sb_o(mem_op_sb_o),
        .mem_op_sh_o(mem_op_sh_o),
        .mem_op_sw_o(mem_op_sw_o),
        // dispatch to SYS
        .sys_op_nop_o(sys_op_nop_o),
        .sys_op_fence_o(sys_op_fence_o),
        // dispatch to EXT
        .req_ext_o(req_ext_o),
        .ext_op_sid_o(ext_op_sid_o),
        .ext_op_rt_o(ext_op_rt_o),
        .ext_op_if_o(ext_op_if_o)
    );

    wire[31:0] alu_res_o;
    wire[31:0] bjp_res_o;
    wire bjp_cmp_res_o;
    exu_alu_datapath_hjx u_exu_alu_datapath(
        .clk(clk),
        .rst_n(rst_n),
        // ALU
        .req_alu_i(req_alu_o),
        .alu_op1_i(alu_op1_o),
        .alu_op2_i(alu_op2_o),
        .alu_op_add_i(alu_op_add_o | alu_op_lui_o | alu_op_auipc_o),
        .alu_op_sub_i(alu_op_sub_o),
        .alu_op_sll_i(alu_op_sll_o),
        .alu_op_slt_i(alu_op_slt_o),
        .alu_op_sltu_i(alu_op_sltu_o),
        .alu_op_xor_i(alu_op_xor_o),
        .alu_op_srl_i(alu_op_srl_o),
        .alu_op_sra_i(alu_op_sra_o),
        .alu_op_or_i(alu_op_or_o),
        .alu_op_and_i(alu_op_and_o),
        // BJP
        .req_bjp_i(req_bjp_o),
        .bjp_op1_i(bjp_op1_o),
        .bjp_op2_i(bjp_op2_o),
        .bjp_op_beq_i(bjp_op_beq_o),
        .bjp_op_bne_i(bjp_op_bne_o),
        .bjp_op_blt_i(bjp_op_blt_o),
        .bjp_op_bltu_i(bjp_op_bltu_o),
        .bjp_op_bge_i(bjp_op_bge_o),
        .bjp_op_bgeu_i(bjp_op_bgeu_o),
        .bjp_op_jump_i(bjp_op_jump_o),
        .bjp_jump_op1_i(bjp_jump_op1_o),
        .bjp_jump_op2_i(bjp_jump_op2_o),
        // MEM
        .req_mem_i(req_mem_o),
        .mem_op1_i(mem_op1_o),
        .mem_op2_i(mem_op2_o),
        .alu_res_o(alu_res_o),
        .bjp_res_o(bjp_res_o),
        .bjp_cmp_res_o(bjp_cmp_res_o)
    );

    wire mem_reg_we_o;
    wire mem_mem_we_o;
    wire[31:0] mem_wdata;
    wire mem_stall_o;
    wire[31:0] mem_addr_from_mem;
    wire[3:0] mem_sel_from_mem;
    wire mem_req_valid_from_mem;
    wire mem_rsp_ready_from_mem;

    exu_mem_hjx u_exu_mem(
        .clk(clk),
        .rst_n(rst_n),
        .req_mem_i(req_mem_o),
        .mem_addr_i(alu_res_o),
        .mem_rs2_data_i(mem_rs2_data_o),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .mem_op_lb_i(mem_op_lb_o),
        .mem_op_lh_i(mem_op_lh_o),
        .mem_op_lw_i(mem_op_lw_o),
        .mem_op_lbu_i(mem_op_lbu_o),
        .mem_op_lhu_i(mem_op_lhu_o),
        .mem_op_sb_i(mem_op_sb_o),
        .mem_op_sh_i(mem_op_sh_o),
        .mem_op_sw_i(mem_op_sw_o),
        .mem_access_misaligned_o(mem_access_misaligned_o),
        .mem_stall_o(mem_stall_o),
        .mem_addr_o(mem_addr_from_mem),
        .mem_wdata_o(mem_wdata),
        .mem_reg_we_o(mem_reg_we_o),
        .mem_mem_we_o(mem_mem_we_o),
        .mem_sel_o(mem_sel_from_mem),
        .mem_req_valid_o(mem_req_valid_from_mem),
        .mem_rsp_ready_o(mem_rsp_ready_from_mem)
    );

    wire sid_stall_o;
    wire[31:0] sid_mem_addr_o;
    wire[31:0] sid_mem_wdata_o;
    wire sid_mem_we_o;
    wire[3:0] sid_mem_sel_o;
    wire sid_mem_req_valid_o;
    wire sid_mem_rsp_ready_o;

    exu_ext_sid_hjx u_exu_ext_sid(
        .clk(clk),
        .rst_n(rst_n),
        .req_sid_i(req_ext_o & ext_op_sid_o),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .sid_stall_o(sid_stall_o),
        .sid_mem_addr_o(sid_mem_addr_o),
        .sid_mem_wdata_o(sid_mem_wdata_o),
        .sid_mem_we_o(sid_mem_we_o),
        .sid_mem_sel_o(sid_mem_sel_o),
        .sid_mem_req_valid_o(sid_mem_req_valid_o),
        .sid_mem_rsp_ready_o(sid_mem_rsp_ready_o)
    );

    wire if_stall_o;
    wire[31:0] if_mem_addr_o;
    wire[31:0] if_mem_wdata_o;
    wire if_mem_we_o;
    wire[3:0] if_mem_sel_o;
    wire if_mem_req_valid_o;
    wire if_mem_rsp_ready_o;
    wire[31:0] if_reg_wdata_o;
    wire if_reg_we_o;

    exu_ext_if_hjx u_exu_ext_if(
        .clk(clk),
        .rst_n(rst_n),
        .req_if_i(req_ext_o & ext_op_if_o),
        .if_rs1_i(reg1_rdata_i),
        .if_vth_i(reg2_rdata_i),
        .if_imm_i(dec_imm_i),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .if_stall_o(if_stall_o),
        .if_mem_addr_o(if_mem_addr_o),
        .if_mem_wdata_o(if_mem_wdata_o),
        .if_mem_we_o(if_mem_we_o),
        .if_mem_sel_o(if_mem_sel_o),
        .if_mem_req_valid_o(if_mem_req_valid_o),
        .if_mem_rsp_ready_o(if_mem_rsp_ready_o),
        .if_reg_wdata_o(if_reg_wdata_o),
        .if_reg_we_o(if_reg_we_o)
    );

    wire rt_stall_o;
    wire[31:0] rt_mem_addr_o;
    wire[31:0] rt_mem_wdata_o;
    wire rt_mem_we_o;
    wire[3:0] rt_mem_sel_o;
    wire rt_mem_req_valid_o;
    wire rt_mem_rsp_ready_o;
    wire[31:0] rt_reg_wdata_o;
    wire rt_reg_we_o;

    exu_ext_rt_hjx u_exu_ext_rt(
        .clk(clk),
        .rst_n(rst_n),
        .req_rt_i(req_ext_o & ext_op_rt_o),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .rt_stall_o(rt_stall_o),
        .rt_mem_addr_o(rt_mem_addr_o),
        .rt_mem_wdata_o(rt_mem_wdata_o),
        .rt_mem_we_o(rt_mem_we_o),
        .rt_mem_sel_o(rt_mem_sel_o),
        .rt_mem_req_valid_o(rt_mem_req_valid_o),
        .rt_mem_rsp_ready_o(rt_mem_rsp_ready_o),
        .rt_reg_wdata_o(rt_reg_wdata_o),
        .rt_reg_we_o(rt_reg_we_o)
    );

    wire commit_reg_we_o;
    wire[31:0] bjp_link_wdata = dec_pc_i + 32'h4;

    exu_commit_hjx u_exu_commit(
        .clk(clk),
        .rst_n(rst_n),
        .req_mem_i(req_mem_o),
        .mem_reg_we_i(mem_reg_we_o),
        .mem_reg_waddr_i(rd_waddr_i),
        .mem_reg_wdata_i(mem_wdata),
        .req_bjp_i(req_bjp_o),
        .bjp_reg_we_i(bjp_op_jump_o),
        .bjp_reg_wdata_i(bjp_link_wdata),
        .bjp_reg_waddr_i(rd_waddr_i),
        .req_ext_wb_i(req_ext_o & (ext_op_rt_o | ext_op_if_o)),
        .ext_reg_we_i(rt_reg_we_o | if_reg_we_o),
        .ext_reg_wdata_i(rt_reg_we_o? rt_reg_wdata_o: if_reg_wdata_o),
        .ext_reg_waddr_i(rd_waddr_i),
        .rd_we_i(rd_we_i),
        .rd_waddr_i(rd_waddr_i),
        .alu_reg_wdata_i(alu_res_o),
        .reg_we_o(commit_reg_we_o),
        .reg_waddr_o(reg_waddr_o),
        .reg_wdata_o(reg_wdata_o)
    );

    assign reg_we_o = commit_reg_we_o;

    assign jump_flag_o = bjp_cmp_res_o | bjp_op_jump_o | sys_op_fence_o;
    assign jump_addr_o = sys_op_fence_o? next_pc_i:
                         bjp_res_o;
    assign hold_flag_o = mem_stall_o | sid_stall_o | rt_stall_o | if_stall_o;

    assign mem_we_o = rt_stall_o? rt_mem_we_o:
                      if_stall_o? if_mem_we_o:
                      sid_stall_o? sid_mem_we_o: mem_mem_we_o;
    assign mem_wdata_o = rt_stall_o? rt_mem_wdata_o:
                         if_stall_o? if_mem_wdata_o:
                         sid_stall_o? sid_mem_wdata_o: mem_wdata;
    assign mem_addr_o = rt_stall_o? rt_mem_addr_o:
                        if_stall_o? if_mem_addr_o:
                        sid_stall_o? sid_mem_addr_o: mem_addr_from_mem;
    assign mem_sel_o = rt_stall_o? rt_mem_sel_o:
                       if_stall_o? if_mem_sel_o:
                       sid_stall_o? sid_mem_sel_o: mem_sel_from_mem;
    assign mem_req_valid_o = rt_stall_o? rt_mem_req_valid_o:
                             if_stall_o? if_mem_req_valid_o:
                             sid_stall_o? sid_mem_req_valid_o: mem_req_valid_from_mem;
    assign mem_rsp_ready_o = rt_stall_o? rt_mem_rsp_ready_o:
                             if_stall_o? if_mem_rsp_ready_o:
                             sid_stall_o? sid_mem_rsp_ready_o: mem_rsp_ready_from_mem;

endmodule
