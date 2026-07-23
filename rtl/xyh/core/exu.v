`include "defines.v"

// 执行级总装模块
// 内部组合了5类执行资源：ALU、BJP(分支/跳转)、MEM(访存)、MULDIV(乘除)、EXT(扩展指令)
// exu_dispatch将dec_info_bus拆成各单元的控制信号
// exu_alu_datapath统一处理加减/逻辑/移位/比较/地址计算
// exu_commit最终选择写回寄存器的数据来源
module exu(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    // mem interface
    input wire[31:0] mem_rdata_i,            // 存储器读数据
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    output wire[31:0] mem_wdata_o,           // 存储器写数据
    output wire[31:0] mem_addr_o,            // 访存地址
    output wire mem_we_o,                    // 访存写使能
    output wire[3:0] mem_sel_o,              // 访存字节选择
    output wire mem_req_valid_o,             // 访存请求有效
    output wire mem_rsp_ready_o,             // 访存响应就绪
    output wire mem_access_misaligned_o,     // 非对齐访问标志

    // gpr_reg interface
    output wire[31:0] reg_wdata_o,           // 写回寄存器数据
    output wire reg_we_o,                    // 写回寄存器使能
    output wire[4:0] reg_waddr_o,            // 写回寄存器地址

    // to pipe_ctrl
    input wire[`STALL_WIDTH-1:0] stall_i,    // 流水线暂停(来自pipe_ctrl)
    output wire[1:0] hold_flag_o,            // 暂停标志(给pipe_ctrl)
    output wire jump_flag_o,                 // 跳转标志
    output wire[31:0] jump_addr_o,           // 跳转目标地址

    // from idu_exu
    input wire[`DECINFO_WIDTH-1:0] dec_info_bus_i,  // 译码信息总线
    input wire[31:0] dec_imm_i,              // 立即数
    input wire[31:0] dec_pc_i,               // 指令PC
    input wire[31:0] next_pc_i,              // 下一条指令PC(PC+4)
    input wire[4:0] rd_waddr_i,              // 目标寄存器地址
    input wire[31:0] reg1_rdata_i,           // rs1寄存器数据
    input wire[31:0] reg2_rdata_i,           // rs2寄存器数据
    input wire rd_we_i                       // 寄存器写使能

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

    // dispatch to MULDIV
    wire req_muldiv_o;
    wire[31:0] muldiv_op1_o;
    wire[31:0] muldiv_op2_o;
    wire muldiv_op_mul_o;
    wire muldiv_op_mulh_o;
    wire muldiv_op_mulhsu_o;
    wire muldiv_op_mulhu_o;
    wire muldiv_op_div_o;
    wire muldiv_op_divu_o;
    wire muldiv_op_rem_o;
    wire muldiv_op_remu_o;

    // extension
    wire req_ext_o;
    wire ext_bus_req_o;
    wire ext_bus_valid_o;
    wire ext_bus_we_o;
    wire[31:0] ext_bus_addr_o;
    wire[31:0] ext_bus_wdata_o;
    wire[3:0] ext_bus_sel_o;
    wire[31:0] ext_reg_wdata_o;
    wire ext_reg_we_o;
    wire ext_stall_o;

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

    exu_extension u_exu_extension(
        .clk(clk),
        .rst_n(rst_n),
        .mem_stall_i(stall_i[`STALL_EX]),
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i(dec_imm_i),
        .reg1_rdata_i(reg1_rdata_i),
        .reg2_rdata_i(reg2_rdata_i),
        .mem_req_ready_i(mem_req_ready_i),
        .mem_rsp_valid_i(mem_rsp_valid_i),
        .mem_rdata_i(mem_rdata_i),
        .req_ext_o(req_ext_o),
        .ext_bus_req_o(ext_bus_req_o),
        .ext_bus_valid_o(ext_bus_valid_o),
        .ext_bus_we_o(ext_bus_we_o),
        .ext_bus_addr_o(ext_bus_addr_o),
        .ext_bus_wdata_o(ext_bus_wdata_o),
        .ext_bus_sel_o(ext_bus_sel_o),
        .ext_reg_wdata_o(ext_reg_wdata_o),
        .ext_reg_we_o(ext_reg_we_o),
        .ext_stall_o(ext_stall_o)
    );

    exu_dispatch u_exu_dispatch(
        .clk(clk),
        .rst_n(rst_n),
        .dec_info_bus_i(dec_info_bus_i),
        .dec_imm_i(dec_imm_i),
        .dec_pc_i(dec_pc_i),
        .rs1_rdata_i(reg1_rdata_i),
        .rs2_rdata_i(reg2_rdata_i),
        .req_alu_o(req_alu_o),
        .alu_op1_o(alu_op1_o),
        .alu_op2_o(alu_op2_o),
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
        .req_bjp_o(req_bjp_o),
        .bjp_op1_o(bjp_op1_o),
        .bjp_op2_o(bjp_op2_o),
        .bjp_jump_op1_o(bjp_jump_op1_o),
        .bjp_jump_op2_o(bjp_jump_op2_o),
        .bjp_op_jump_o(bjp_op_jump_o),
        .bjp_op_beq_o(bjp_op_beq_o),
        .bjp_op_bne_o(bjp_op_bne_o),
        .bjp_op_blt_o(bjp_op_blt_o),
        .bjp_op_bltu_o(bjp_op_bltu_o),
        .bjp_op_bge_o(bjp_op_bge_o),
        .bjp_op_bgeu_o(bjp_op_bgeu_o),
        .req_muldiv_o(req_muldiv_o),
        .muldiv_op1_o(muldiv_op1_o),
        .muldiv_op2_o(muldiv_op2_o),
        .muldiv_op_mul_o(muldiv_op_mul_o),
        .muldiv_op_mulh_o(muldiv_op_mulh_o),
        .muldiv_op_mulhsu_o(muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_o(muldiv_op_mulhu_o),
        .muldiv_op_div_o(muldiv_op_div_o),
        .muldiv_op_divu_o(muldiv_op_divu_o),
        .muldiv_op_rem_o(muldiv_op_rem_o),
        .muldiv_op_remu_o(muldiv_op_remu_o),
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
        .sys_op_nop_o(sys_op_nop_o),
        .sys_op_fence_o(sys_op_fence_o)
    );

    wire[31:0] alu_res_o;
    wire[31:0] bjp_res_o;
    wire bjp_cmp_res_o;

    exu_alu_datapath u_exu_alu_datapath(
        .clk(clk),
        .rst_n(rst_n),
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
        .req_mem_i(req_mem_o),
        .mem_op1_i(mem_op1_o),
        .mem_op2_i(mem_op2_o),
        .req_csr_i(1'b0),
        .csr_op1_i(32'h0),
        .csr_op2_i(32'h0),
        .csr_csrrw_i(1'b0),
        .csr_csrrs_i(1'b0),
        .csr_csrrc_i(1'b0),
        .alu_res_o(alu_res_o),
        .bjp_res_o(bjp_res_o),
        .bjp_cmp_res_o(bjp_cmp_res_o)
    );

    wire mem_reg_we_o;
    wire mem_mem_we_o;
    wire[31:0] mem_wdata;
    wire[1:0] mem_stall_o;

    exu_mem u_exu_mem(
        .clk(clk),
        .rst_n(rst_n),
        .req_mem_i(req_mem_o),
        .mem_stall_i(stall_i[`STALL_EX]),
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
        .ext_req_i(ext_bus_req_o),
        .ext_req_valid_i(ext_bus_valid_o),
        .ext_mem_we_i(ext_bus_we_o),
        .ext_addr_i(ext_bus_addr_o),
        .ext_wdata_i(ext_bus_wdata_o),
        .ext_sel_i(ext_bus_sel_o),
        .mem_access_misaligned_o(mem_access_misaligned_o),
        .mem_stall_o(mem_stall_o),
        .mem_addr_o(mem_addr_o),
        .mem_wdata_o(mem_wdata),
        .mem_reg_we_o(mem_reg_we_o),
        .mem_mem_we_o(mem_mem_we_o),
        .mem_sel_o(mem_sel_o),
        .mem_req_valid_o(mem_req_valid_o),
        .mem_rsp_ready_o(mem_rsp_ready_o)
    );

    wire[31:0] muldiv_reg_wdata_o;
    wire muldiv_reg_we_o;
    wire muldiv_stall_o;

    exu_muldiv u_exu_muldiv(
        .clk(clk),
        .rst_n(rst_n),
        .mem_stall_i(stall_i[`STALL_EX]),
        .muldiv_op1_i(muldiv_op1_o),
        .muldiv_op2_i(muldiv_op2_o),
        .muldiv_op_mul_i(muldiv_op_mul_o),
        .muldiv_op_mulh_i(muldiv_op_mulh_o),
        .muldiv_op_mulhsu_i(muldiv_op_mulhsu_o),
        .muldiv_op_mulhu_i(muldiv_op_mulhu_o),
        .muldiv_op_div_i(muldiv_op_div_o),
        .muldiv_op_divu_i(muldiv_op_divu_o),
        .muldiv_op_rem_i(muldiv_op_rem_o),
        .muldiv_op_remu_i(muldiv_op_remu_o),
        .muldiv_reg_wdata_o(muldiv_reg_wdata_o),
        .muldiv_reg_we_o(muldiv_reg_we_o),
        .muldiv_stall_o(muldiv_stall_o)
    );

    wire commit_reg_we_o;

    exu_commit u_exu_commit(
        .clk(clk),
        .rst_n(rst_n),
        .req_muldiv_i(req_muldiv_o),
        .muldiv_reg_we_i(muldiv_reg_we_o),
        .muldiv_reg_waddr_i(rd_waddr_i),
        .muldiv_reg_wdata_i(muldiv_reg_wdata_o),
        .req_mem_i(req_mem_o),
        .mem_reg_we_i(mem_reg_we_o),
        .mem_reg_waddr_i(rd_waddr_i),
        .mem_reg_wdata_i(mem_wdata),
        .req_ext_i(req_ext_o),
        .ext_reg_we_i(ext_reg_we_o),
        .ext_reg_waddr_i(rd_waddr_i),
        .ext_reg_wdata_i(ext_reg_wdata_o),
        .req_csr_i(1'b0),
        .csr_reg_we_i(1'b0),
        .csr_reg_waddr_i(5'h0),
        .csr_reg_wdata_i(32'h0),
        .req_bjp_i(req_bjp_o),
        .bjp_reg_we_i(bjp_op_jump_o),
        .bjp_reg_wdata_i(next_pc_i),
        .bjp_reg_waddr_i(rd_waddr_i),
        .rd_we_i(rd_we_i),
        .rd_waddr_i(rd_waddr_i),
        .alu_reg_wdata_i(alu_res_o),
        .reg_we_o(commit_reg_we_o),
        .reg_waddr_o(reg_waddr_o),
        .reg_wdata_o(reg_wdata_o)
    );

    assign reg_we_o = commit_reg_we_o;

    assign jump_flag_o = bjp_cmp_res_o | bjp_op_jump_o | sys_op_fence_o;
    assign jump_addr_o = sys_op_fence_o ? next_pc_i : bjp_res_o;
    assign hold_flag_o[0] = muldiv_stall_o | mem_stall_o[0] | ext_stall_o;
    assign hold_flag_o[1] = muldiv_stall_o | mem_stall_o[1] | ext_stall_o;

    assign mem_we_o = mem_mem_we_o;
    assign mem_wdata_o = mem_wdata;

endmodule
