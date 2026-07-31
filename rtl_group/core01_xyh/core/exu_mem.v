`timescale 1ns / 1ps

`include "defines_xyh.v"

// 访存模块
// 处理普通load/store指令(lb/lh/lw/lbu/lhu/sb/sh/sw)
// 根据地址低两位与访问类型生成字节掩码(mem_sel)
// sb/sh/sw生成带字节掩码的写数据，lb/lh/lw根据返回字进行字节选取和符号扩展
// 同时支持扩展指令对总线的复用访问(ext_req_i有效时总线输出改由扩展模块提供)
module exu_mem_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire mem_stall_i,                  // 外部暂停(来自pipe_ctrl)

    input wire req_mem_i,                    // 访存请求(普通load/store)
    input wire[31:0] mem_addr_i,             // 访存地址
    input wire[31:0] mem_rs2_data_i,         // 存储数据(rs2)
    input wire[31:0] mem_rdata_i,            // 存储器读数据
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    input wire mem_op_lb_i,                  // LB指令
    input wire mem_op_lh_i,                  // LH指令
    input wire mem_op_lw_i,                  // LW指令
    input wire mem_op_lbu_i,                 // LBU指令
    input wire mem_op_lhu_i,                 // LHU指令
    input wire mem_op_sb_i,                  // SB指令
    input wire mem_op_sh_i,                  // SH指令
    input wire mem_op_sw_i,                  // SW指令

    input wire ext_req_i,                    // 扩展模块总线请求
    input wire ext_req_valid_i,              // 扩展模块请求有效
    input wire ext_mem_we_i,                 // 扩展模块写使能
    input wire[31:0] ext_addr_i,             // 扩展模块地址
    input wire[31:0] ext_wdata_i,            // 扩展模块写数据
    input wire[3:0] ext_sel_i,               // 扩展模块字节选择

    output wire mem_access_misaligned_o,     // 非对齐访存标志
    output wire[1:0] mem_stall_o,            // 访存暂停(位0=hold,位1=stall)
    output wire[31:0] mem_addr_o,            // 输出访存地址
    output wire[31:0] mem_wdata_o,           // 输出写数据
    output wire mem_reg_we_o,                // 寄存器写使能(load指令)
    output wire mem_mem_we_o,                // 存储器写使能
    output wire[3:0] mem_sel_o,              // 字节选择
    output wire mem_req_valid_o,             // 访存请求有效
    output wire mem_rsp_ready_o              // 访存响应就绪

    );

    wire[1:0] mem_addr_index = mem_addr_i[1:0];
    wire mem_addr_index00 = (mem_addr_index == 2'b00);
    wire mem_addr_index01 = (mem_addr_index == 2'b01);
    wire mem_addr_index10 = (mem_addr_index == 2'b10);
    wire mem_addr_index11 = (mem_addr_index == 2'b11);

    wire[3:0] mem_sel_norm;
    assign mem_sel_norm[0] = mem_addr_index00 | mem_op_lw_i | mem_op_sw_i;
    assign mem_sel_norm[1] = mem_addr_index01 | mem_op_lw_i |
        ((mem_op_sh_i | mem_op_lh_i | mem_op_lhu_i) & mem_addr_index00) | mem_op_sw_i;
    assign mem_sel_norm[2] = mem_addr_index10 | mem_op_lw_i | mem_op_sw_i;
    assign mem_sel_norm[3] = mem_addr_index11 | mem_op_lw_i |
        ((mem_op_sh_i | mem_op_lh_i | mem_op_lhu_i) & mem_addr_index10) | mem_op_sw_i;

    reg[31:0] sb_res;
    always @ (*) begin
        sb_res = 32'h0;
        case (1'b1)
            mem_addr_index00: sb_res = {24'h0, mem_rs2_data_i[7:0]};
            mem_addr_index01: sb_res = {16'h0, mem_rs2_data_i[7:0], 8'h0};
            mem_addr_index10: sb_res = {8'h0, mem_rs2_data_i[7:0], 16'h0};
            mem_addr_index11: sb_res = {mem_rs2_data_i[7:0], 24'h0};
        endcase
    end

    reg[31:0] sh_res;
    always @ (*) begin
        sh_res = 32'h0;
        case (1'b1)
            mem_addr_index00: sh_res = {16'h0, mem_rs2_data_i[15:0]};
            mem_addr_index10: sh_res = {mem_rs2_data_i[15:0], 16'h0};
        endcase
    end

    wire[31:0] sw_res = mem_rs2_data_i;

    reg[31:0] lb_res;
    always @ (*) begin
        lb_res = 32'h0;
        case (1'b1)
            mem_addr_index00: lb_res = {{24{mem_op_lb_i & mem_rdata_i[7]}}, mem_rdata_i[7:0]};
            mem_addr_index01: lb_res = {{24{mem_op_lb_i & mem_rdata_i[15]}}, mem_rdata_i[15:8]};
            mem_addr_index10: lb_res = {{24{mem_op_lb_i & mem_rdata_i[23]}}, mem_rdata_i[23:16]};
            mem_addr_index11: lb_res = {{24{mem_op_lb_i & mem_rdata_i[31]}}, mem_rdata_i[31:24]};
        endcase
    end

    reg[31:0] lh_res;
    always @ (*) begin
        lh_res = 32'h0;
        case (1'b1)
            mem_addr_index00: lh_res = {{16{mem_op_lh_i & mem_rdata_i[15]}}, mem_rdata_i[15:0]};
            mem_addr_index10: lh_res = {{16{mem_op_lh_i & mem_rdata_i[31]}}, mem_rdata_i[31:16]};
        endcase
    end

    wire[31:0] lw_res = mem_rdata_i;

    reg[31:0] mem_wdata_norm;
    always @ (*) begin
        mem_wdata_norm = 32'h0;
        case (1'b1)
            mem_op_sb_i:  mem_wdata_norm = sb_res;
            mem_op_sh_i:  mem_wdata_norm = sh_res;
            mem_op_sw_i:  mem_wdata_norm = sw_res;
            mem_op_lb_i:  mem_wdata_norm = lb_res;
            mem_op_lbu_i: mem_wdata_norm = lb_res;
            mem_op_lh_i:  mem_wdata_norm = lh_res;
            mem_op_lhu_i: mem_wdata_norm = lh_res;
            mem_op_lw_i:  mem_wdata_norm = lw_res;
        endcase
    end

    wire mem_req_valid_norm = req_mem_i & (~mem_stall_i);
    wire mem_req_valid = ext_req_i ? ext_req_valid_i : mem_req_valid_norm;
    wire mem_req_hsked = mem_req_valid & mem_req_ready_i;
    wire mem_rsp_hsked = mem_rsp_valid_i & mem_rsp_ready_o;

    assign mem_req_valid_o = mem_req_valid;
    assign mem_stall_o[0] = mem_req_valid_norm & (~mem_rsp_hsked);
    assign mem_stall_o[1] = mem_req_valid_norm;

    assign mem_addr_o = ext_req_i ? ext_addr_i : mem_addr_i;
    assign mem_wdata_o = ext_req_i ? ext_wdata_i : mem_wdata_norm;
    assign mem_sel_o = ext_req_i ? ext_sel_i : mem_sel_norm;
    assign mem_rsp_ready_o = 1'b1;

    assign mem_reg_we_o =
        (mem_op_lb_i | mem_op_lh_i | mem_op_lw_i | mem_op_lbu_i | mem_op_lhu_i) & mem_rsp_hsked;

    assign mem_mem_we_o = ext_req_i ? ext_mem_we_i : (mem_op_sb_i | mem_op_sh_i | mem_op_sw_i);

    assign mem_access_misaligned_o = (mem_op_sw_i | mem_op_lw_i) ? (mem_addr_i[0] | mem_addr_i[1]) :
                                     (mem_op_sh_i | mem_op_lh_i | mem_op_lhu_i) ? mem_addr_i[0] :
                                     1'b0;

endmodule
