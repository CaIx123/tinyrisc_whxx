`include "core/defines.v"

// tinyriscv处理器核顶层模块
// 负责例化IFU、IDU、EXU、GPR、流水控制等所有核心子模块
// 对外提供指令总线(ibus)和数据总线(dbus)两套独立的访存接口
// 同时提供x26/x27寄存器引出用于测试完成信号(succ)
module core_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire pc_rst_i,                     // PC复位信号(烧录完成后重启IFU)
    output wire gpr_we_o,
    output wire[4:0] gpr_waddr_o,
    output wire[31:0] gpr_wdata_o,
    output wire[4:0] gpr_raddr1_o,
    input wire[31:0] gpr_rdata1_i,
    output wire[4:0] gpr_raddr2_o,
    input wire[31:0] gpr_rdata2_i,

    output wire[31:0] dbus_addr_o,           // 数据总线地址
    input wire[31:0] dbus_data_i,            // 数据总线读数据
    output wire[31:0] dbus_data_o,           // 数据总线写数据
    output wire[3:0] dbus_sel_o,             // 数据总线字节选择掩码
    output wire dbus_we_o,                   // 数据总线写使能
    output wire dbus_req_valid_o,            // 数据总线请求有效
    input wire dbus_req_ready_i,             // 数据总线请求就绪
    input wire dbus_rsp_valid_i,             // 数据总线响应有效
    output wire dbus_rsp_ready_o,            // 数据总线响应就绪

    output wire[31:0] ibus_addr_o,           // 指令总线地址
    input wire[31:0] ibus_data_i,            // 指令总线读数据
    output wire[31:0] ibus_data_o,           // 指令总线写数据(恒为0)
    output wire[3:0] ibus_sel_o,             // 指令总线字节选择(恒为1111)
    output wire ibus_we_o,                   // 指令总线写使能(恒为0)
    output wire ibus_req_valid_o,            // 指令总线请求有效
    input wire ibus_req_ready_i,             // 指令总线请求就绪
    input wire ibus_rsp_valid_i,             // 指令总线响应有效
    output wire ibus_rsp_ready_o,            // 指令总线响应就绪

    input wire jtag_halt_i                  // JTAG停机信号(被uart_debug复用)

    );

    // ifu模块输出信号
    wire[31:0] ifetch_inst_o;
    wire[31:0] ifetch_pc_o;
    wire ifetch_inst_valid_o;
    wire ifetch_stall_o;

    // ifu_idu模块输出信号
    wire[31:0] if_inst_o;
    wire[31:0] if_inst_addr_o;

    // idu模块输出信号
    wire[31:0] id_inst_o;
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
    wire[1:0] ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[31:0] ex_jump_addr_o;

    // pipe_ctrl模块输出信号
    wire[31:0] ctrl_flush_addr_o;
    wire ctrl_flush_o;
    wire[`STALL_WIDTH-1:0] ctrl_stall_o;

    assign dbus_addr_o = ex_mem_addr_o;
    assign dbus_data_o = ex_mem_wdata_o;
    assign dbus_we_o = ex_mem_we_o;
    assign dbus_sel_o = ex_mem_sel_o;
    assign dbus_req_valid_o = ex_mem_req_valid_o;
    assign dbus_rsp_ready_o = ex_mem_rsp_ready_o;
    assign gpr_we_o = ex_reg_we_o;
    assign gpr_waddr_o = ex_reg_waddr_o;
    assign gpr_wdata_o = ex_reg_wdata_o;
    assign gpr_raddr1_o = id_rs1_raddr_o;
    assign gpr_raddr2_o = id_rs2_raddr_o;

    ifu_xyh u_ifu(
        .clk(clk),
        .rst_n(rst_n),
        .pc_rst_i(pc_rst_i),
        .flush_addr_i(ctrl_flush_addr_o),
        .stall_i(ctrl_stall_o),
        .flush_i(ctrl_flush_o),
        .jtag_halt_i(jtag_halt_i),
        .inst_o(ifetch_inst_o),
        .pc_o(ifetch_pc_o),
        .inst_valid_o(ifetch_inst_valid_o),
        .stall_o(ifetch_stall_o),
        .ibus_addr_o(ibus_addr_o),
        .ibus_data_i(ibus_data_i),
        .ibus_data_o(ibus_data_o),
        .ibus_sel_o(ibus_sel_o),
        .ibus_we_o(ibus_we_o),
        .req_valid_o(ibus_req_valid_o),
        .req_ready_i(ibus_req_ready_i),
        .rsp_valid_i(ibus_rsp_valid_i),
        .rsp_ready_o(ibus_rsp_ready_o)
    );

    pipe_ctrl_xyh u_pipe_ctrl(
        .clk(clk),
        .rst_n(rst_n),
        .stall_from_if_i(ifetch_stall_o),
        .stall_from_id_i(id_stall_o),
        .stall_from_ex_i(ex_hold_flag_o),
        .stall_from_jtag_i(1'b0),
        .jump_assert_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .flush_o(ctrl_flush_o),
        .stall_o(ctrl_stall_o),
        .flush_addr_o(ctrl_flush_addr_o)
    );
    ifu_idu_xyh u_ifu_idu(
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

    idu_xyh u_idu(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(if_inst_o),
        .rs1_rdata_i(gpr_rdata1_i),
        .rs2_rdata_i(gpr_rdata2_i),
        .stall_o(id_stall_o),
        .inst_o(id_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .dec_info_bus_o(id_dec_info_bus_o),
        .dec_imm_o(id_dec_imm_o),
        .dec_pc_o(id_dec_pc_o),
        .rs1_raddr_o(id_rs1_raddr_o),
        .rs2_raddr_o(id_rs2_raddr_o),
        .rs1_rdata_o(id_rs1_rdata_o),
        .rs2_rdata_o(id_rs2_rdata_o),
        .rd_waddr_o(id_rd_waddr_o),
        .rd_we_o(id_rd_we_o)
    );

    idu_exu_xyh u_idu_exu(
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

    exu_xyh u_exu(
        .clk(clk),
        .rst_n(rst_n),
        .mem_rdata_i(dbus_data_i),
        .mem_req_ready_i(dbus_req_ready_i),
        .mem_rsp_valid_i(dbus_rsp_valid_i),
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
        .stall_i(ctrl_stall_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .dec_info_bus_i(ie_dec_info_bus_o),
        .dec_imm_i(ie_dec_imm_o),
        .dec_pc_i(ie_dec_pc_o),
        .next_pc_i(ie_dec_pc_o + 32'h4),
        .rd_waddr_i(ie_rd_waddr_o),
        .reg1_rdata_i(ie_rs1_rdata_o),
        .reg2_rdata_i(ie_rs2_rdata_o),
        .rd_we_i(ie_rd_we_o)
    );

endmodule
