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

`include "defines.v"

// tinyriscv处理器核顶层模块
module tinyriscv_core(

    input wire clk,
    input wire rst_n,

    output wire[31:0] dbus_addr_o,
    input wire[31:0] dbus_data_i,
    output wire[31:0] dbus_data_o,
    output wire[3:0] dbus_sel_o,
    output wire dbus_we_o,
    output wire dbus_req_valid_o,
    input wire dbus_req_ready_i,
    input wire dbus_rsp_valid_i,
    output wire dbus_rsp_ready_o,

    output wire[31:0] ibus_addr_o,          // 取指地址
    input wire[31:0] ibus_data_i,           // 取到的指令内容
    output wire[31:0] ibus_data_o,
    output wire[3:0] ibus_sel_o,
    output wire ibus_we_o,
    output wire ibus_req_valid_o,
    input wire ibus_req_ready_i,
    input wire ibus_rsp_valid_i,
    output wire ibus_rsp_ready_o,

    input wire debug_halt_i

    );

    // ifu模块输出信号
    wire[31:0] ifetch_inst_o;
    wire[31:0] ifetch_pc_o;
    wire ifetch_inst_valid_o;

    // ifu_idu模块输出信号
	wire[31:0] if_inst_o;
    wire[31:0] if_inst_addr_o;

    // idu模块输出信号
    wire[31:0] id_inst_o;
    wire[31:0] id_inst_addr_o;
    wire[`DECINFO_WIDTH-1:0] id_dec_info_bus_o;
    wire[31:0] id_dec_imm_o;
    wire[31:0] id_dec_pc_o;
    wire[4:0] id_rs1_raddr_o;
    wire[4:0] id_rs2_raddr_o;
    wire[4:0] id_rd_waddr_o;
    wire id_rd_we_o;
    wire id_stall_o;
    wire[31:0] id_rs1_rdata_o;
    wire[31:0] id_rs2_rdata_o;

    // idu_exu模块输出信号
    wire[31:0] ie_inst_o;
    wire[31:0] ie_inst_addr_o;
    wire[`DECINFO_WIDTH-1:0] ie_dec_info_bus_o;
    wire[31:0] ie_dec_imm_o;
    wire[31:0] ie_dec_pc_o;
    wire[31:0] ie_rs1_rdata_o;
    wire[31:0] ie_rs2_rdata_o;
    wire[4:0] ie_rd_waddr_o;
    wire ie_rd_we_o;

    // exu模块输出信号
    wire[31:0] ex_mem_wdata_o;
    wire[31:0] ex_mem_addr_o;
    wire ex_mem_we_o;
    wire[3:0] ex_mem_sel_o;
    wire ex_mem_req_valid_o;
    wire ex_mem_rsp_ready_o;
    wire ex_mem_access_misaligned_o;
    wire[31:0] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[4:0] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[31:0] ex_jump_addr_o;

    // gpr_reg模块输出信号
    wire[31:0] regs_rdata1_o;
    wire[31:0] regs_rdata2_o;

    // pipe_ctrl模块输出信号
    wire[31:0] ctrl_flush_addr_o;
    wire ctrl_flush_o;
    wire[`STALL_WIDTH-1:0] ctrl_stall_o;

    // The shared RIB has one response route. Serialize the two core masters
    // here so a data request cannot replace an outstanding fetch response.
    wire ifu_req_valid_raw;
    wire ifu_rsp_ready_raw;
    reg core_bus_pending_r;
    reg core_bus_owner_r; // 1: EXU/data, 0: IFU/instruction
    wire core_grant_exu = (~core_bus_pending_r) & ex_mem_req_valid_o;
    wire core_grant_ifu = (~core_bus_pending_r) & (~ex_mem_req_valid_o) & ifu_req_valid_raw;
    wire core_req_hsked = (core_grant_exu & dbus_req_ready_i) |
                          (core_grant_ifu & ibus_req_ready_i);
    wire core_rsp_hsked = (dbus_rsp_valid_i & dbus_rsp_ready_o) |
                          (ibus_rsp_valid_i & ibus_rsp_ready_o);

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            core_bus_pending_r <= 1'b0;
            core_bus_owner_r <= 1'b0;
        end else if (core_bus_pending_r) begin
            if (core_rsp_hsked)
                core_bus_pending_r <= 1'b0;
        end else if (core_req_hsked) begin
            core_bus_pending_r <= 1'b1;
            core_bus_owner_r <= core_grant_exu;
        end
    end

    assign dbus_addr_o = ex_mem_addr_o;
    assign dbus_data_o = ex_mem_wdata_o;
    assign dbus_we_o = ex_mem_we_o;
    assign dbus_sel_o = ex_mem_sel_o;
    assign dbus_req_valid_o = core_grant_exu;
    assign dbus_rsp_ready_o = core_bus_pending_r & core_bus_owner_r & ex_mem_rsp_ready_o;
    assign ibus_req_valid_o = core_grant_ifu;
    assign ibus_rsp_ready_o = core_bus_pending_r & (~core_bus_owner_r) & ifu_rsp_ready_raw;

    ifu u_ifu(
        .clk(clk),
        .rst_n(rst_n),
        .flush_addr_i(ctrl_flush_addr_o),
        .stall_i(ctrl_stall_o),
        .flush_i(ctrl_flush_o),
        .debug_halt_i(debug_halt_i),
        .inst_o(ifetch_inst_o),
        .pc_o(ifetch_pc_o),
        .inst_valid_o(ifetch_inst_valid_o),
        .ibus_addr_o(ibus_addr_o),
        .ibus_data_i(ibus_data_i),
        .ibus_data_o(ibus_data_o),
        .ibus_sel_o(ibus_sel_o),
        .ibus_we_o(ibus_we_o),
        .req_valid_o(ifu_req_valid_raw),
        .req_ready_i(core_grant_ifu & ibus_req_ready_i),
        .rsp_valid_i(core_bus_pending_r & (~core_bus_owner_r) & ibus_rsp_valid_i),
        .rsp_ready_o(ifu_rsp_ready_raw)
    );

    pipe_ctrl u_pipe_ctrl(
        .clk(clk),
        .rst_n(rst_n),
        .stall_from_id_i(id_stall_o),
        .stall_from_ex_i(ex_hold_flag_o),
        .jump_assert_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .flush_o(ctrl_flush_o),
        .stall_o(ctrl_stall_o),
        .flush_addr_o(ctrl_flush_addr_o)
    );

    gpr_reg u_gpr_reg(
        .clk(clk),
        .rst_n(rst_n),
        .we_i(ex_reg_we_o),
        .waddr_i(ex_reg_waddr_o),
        .wdata_i(ex_reg_wdata_o),
        .raddr1_i(id_rs1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(id_rs2_raddr_o),
        .rdata2_o(regs_rdata2_o)
    );

    ifu_idu u_ifu_idu(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(ifetch_inst_o),
        .inst_addr_i(ifetch_pc_o),
        .stall_i(ctrl_stall_o),
        .flush_i(ctrl_flush_o),
        .inst_valid_i(ifetch_inst_valid_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    idu u_idu(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(if_inst_o),
        .rs1_rdata_i(regs_rdata1_o),
        .rs2_rdata_i(regs_rdata2_o),
        .inst_o(id_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .rs1_rdata_o(id_rs1_rdata_o),
        .rs2_rdata_o(id_rs2_rdata_o),
        .stall_o(id_stall_o),
        .dec_info_bus_o(id_dec_info_bus_o),
        .dec_imm_o(id_dec_imm_o),
        .dec_pc_o(id_dec_pc_o),
        .rs1_raddr_o(id_rs1_raddr_o),
        .rs2_raddr_o(id_rs2_raddr_o),
        .rd_waddr_o(id_rd_waddr_o),
        .rd_we_o(id_rd_we_o)
    );

    idu_exu u_idu_exu(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(id_inst_o),
        .stall_i(ctrl_stall_o),
        .flush_i(ctrl_flush_o),
        .dec_info_bus_i(id_dec_info_bus_o),
        .dec_imm_i(id_dec_imm_o),
        .dec_pc_i(id_dec_pc_o),
        .rs1_rdata_i(id_rs1_rdata_o),
        .rs2_rdata_i(id_rs2_rdata_o),
        .rd_waddr_i(id_rd_waddr_o),
        .rd_we_i(id_rd_we_o),
        .inst_o(ie_inst_o),
        .dec_info_bus_o(ie_dec_info_bus_o),
        .dec_imm_o(ie_dec_imm_o),
        .dec_pc_o(ie_dec_pc_o),
        .rs1_rdata_o(ie_rs1_rdata_o),
        .rs2_rdata_o(ie_rs2_rdata_o),
        .rd_waddr_o(ie_rd_waddr_o),
        .rd_we_o(ie_rd_we_o)
    );

    exu u_exu(
        .clk(clk),
        .rst_n(rst_n),
        .reg1_rdata_i(ie_rs1_rdata_o),
        .reg2_rdata_i(ie_rs2_rdata_o),
        .mem_rdata_i(dbus_data_i),
        .mem_req_ready_i(core_grant_exu & dbus_req_ready_i),
        .mem_rsp_valid_i(core_bus_pending_r & core_bus_owner_r & dbus_rsp_valid_i),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_addr_o(ex_mem_addr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_sel_o(ex_mem_sel_o),
        .mem_req_valid_o(ex_mem_req_valid_o),
        .mem_rsp_ready_o(ex_mem_rsp_ready_o),
        .mem_access_misaligned_o(ex_mem_access_misaligned_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .dec_info_bus_i(ie_dec_info_bus_o),
        .dec_imm_i(ie_dec_imm_o),
        .dec_pc_i(ie_dec_pc_o),
        .next_pc_i(if_inst_addr_o),
        .rd_waddr_i(ie_rd_waddr_o),
        .rd_we_i(ie_rd_we_o)
    );

endmodule
