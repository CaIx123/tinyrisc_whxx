`include "../marcos_wzc.v"

module kalsit_core(

    input wire clk,
    input wire rst_n,
    input wire debug_halt_i,

    // External GPR interface
    output wire gpr_we_o,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_waddr_o,
    output wire[`DATA_WIDTH-1:0] gpr_wdata_o,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_raddr1_o,
    input wire[`DATA_WIDTH-1:0] gpr_rdata1_i,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_raddr2_o,
    input wire[`DATA_WIDTH-1:0] gpr_rdata2_i,

    // IF RIB master
    output wire[`DATA_WIDTH-1:0] if_addr_o,
    output wire[`DATA_WIDTH-1:0] if_data_o,
    output wire[3:0] if_sel_o,
    output wire if_req_vld_o,
    input wire if_req_rdy_i,
    output wire if_rsp_rdy_o,
    input wire if_rsp_vld_i,
    input wire[`DATA_WIDTH-1:0] if_data_i,
    output wire if_we_o,

    // MEM RIB master
    output wire[`DATA_WIDTH-1:0] mem_addr_o,
    output wire[`DATA_WIDTH-1:0] mem_data_o,
    output wire[3:0] mem_sel_o,
    output wire mem_req_vld_o,
    input wire mem_req_rdy_i,
    output wire mem_rsp_rdy_o,
    input wire mem_rsp_vld_i,
    input wire[`DATA_WIDTH-1:0] mem_data_i,
    output wire mem_we_o

    );

    wire pc_stall;
    wire if_id_stall;
    wire if_id_hold;
    wire id_ex_stall;
    wire id_ex_flush;
    wire ex_mem_stall;
    wire mem_wb_stall;

    wire if_inst_valid;
    wire[`INST_WIDTH-1:0] if_inst;
    wire[`PC_WIDTH-1:0] if_pc;
    wire[`INST_WIDTH-1:0] if_id_inst;
    wire[`PC_WIDTH-1:0] if_id_pc;

    wire branch_req;
    wire branch_taken;
    wire[`PC_WIDTH-1:0] branch_addr;
    wire pc_flush;
    wire if_id_flush;
    wire id_ex_flush_hazard;

    wire[`DATA_WIDTH-1:0] id_data_rs1;
    wire[`DATA_WIDTH-1:0] id_data_rs2;
    wire[`DATA_WIDTH-1:0] id_imm;
    wire[`GPR_ADDR_WIDTH-1:0] id_rs1_raddr;
    wire[`GPR_ADDR_WIDTH-1:0] id_rs2_raddr;
    wire[`GPR_ADDR_WIDTH-1:0] id_rd_waddr;
    wire id_reg_write;
    wire id_mem_to_reg;
    wire id_mem_read;
    wire id_mem_write;
    wire[`MEM_CTRL_WIDTH-1:0] id_mem_ctrl;
    wire[`CUSTOM_CTRL_WIDTH-1:0] id_custom_ctrl;
    wire id_alu_src;
    wire[`ALU_CTRL_WIDTH-1:0] id_alu_ctrl;

    wire[`DATA_WIDTH-1:0] id_ex_data_rs1;
    wire[`DATA_WIDTH-1:0] id_ex_data_rs2;
    wire[`DATA_WIDTH-1:0] id_ex_imm;
    wire[`GPR_ADDR_WIDTH-1:0] id_ex_rs1_raddr;
    wire[`GPR_ADDR_WIDTH-1:0] id_ex_rs2_raddr;
    wire[`GPR_ADDR_WIDTH-1:0] id_ex_rd_waddr;
    wire id_ex_reg_write;
    wire id_ex_mem_to_reg;
    wire id_ex_mem_read;
    wire id_ex_mem_write;
    wire[`MEM_CTRL_WIDTH-1:0] id_ex_mem_ctrl;
    wire[`CUSTOM_CTRL_WIDTH-1:0] id_ex_custom_ctrl;
    wire id_ex_alu_src;
    wire[`ALU_CTRL_WIDTH-1:0] id_ex_alu_ctrl;

    wire[`DATA_WIDTH-1:0] ex_result;
    wire[`DATA_WIDTH-1:0] ex_mem_wdata;
    wire[`GPR_ADDR_WIDTH-1:0] ex_rd_waddr;
    wire ex_reg_write;
    wire ex_mem_to_reg;
    wire ex_mem_read;
    wire ex_mem_write;
    wire[`MEM_CTRL_WIDTH-1:0] ex_mem_ctrl;
    wire[`CUSTOM_CTRL_WIDTH-1:0] ex_custom_ctrl;

    wire[`DATA_WIDTH-1:0] ex_mem_result;
    wire[`DATA_WIDTH-1:0] ex_mem_mem_wdata;
    wire[`GPR_ADDR_WIDTH-1:0] ex_mem_rd_waddr;
    wire ex_mem_reg_write;
    wire ex_mem_mem_to_reg;
    wire ex_mem_mem_read;
    wire ex_mem_mem_write;
    wire[`MEM_CTRL_WIDTH-1:0] ex_mem_mem_ctrl;
    wire[`CUSTOM_CTRL_WIDTH-1:0] ex_mem_custom_ctrl;

    wire[`DATA_WIDTH-1:0] mem_result;
    wire[`DATA_WIDTH-1:0] mem_rdata;
    wire[`GPR_ADDR_WIDTH-1:0] mem_rd_waddr;
    wire mem_reg_write;
    wire mem_mem_to_reg;
    wire stall_req_mem;

    wire[`DATA_WIDTH-1:0] mem_wb_result;
    wire[`DATA_WIDTH-1:0] mem_wb_rdata;
    wire[`GPR_ADDR_WIDTH-1:0] mem_wb_rd_waddr;
    wire mem_wb_reg_write;
    wire mem_wb_mem_to_reg;

    wire[`DATA_WIDTH-1:0] wb_wdata;
    wire[`GPR_ADDR_WIDTH-1:0] wb_rd_waddr;
    wire wb_reg_write;
    wire[`DATA_WIDTH-1:0] ex_mem_forward_data;

    pipeline_ctrl u_pipeline_ctrl(
        .stall_req_mem_i(stall_req_mem),
        .debug_halt_i(debug_halt_i),
        .stall_req_ifetch_i(~if_inst_valid),
        .branch_i(branch_req),
        .pc_stall_o(pc_stall),
        .if_id_stall_o(if_id_stall),
        .id_ex_stall_o(id_ex_stall),
        .id_ex_flush_o(id_ex_flush),
        .ex_mem_stall_o(ex_mem_stall),
        .mem_wb_stall_o(mem_wb_stall)
    );

    assign if_id_hold = if_id_stall | pc_flush;

    ifu u_ifu(
        .clk(clk),
        .rst_n(rst_n),
        .branch_taken_i(branch_taken),
        .branch_addr_i(branch_addr),
        .pc_stall_i(pc_stall),
        .if_id_stall_i(if_id_stall),
        .pc_flush_i(pc_flush),
        .if_id_flush_i(if_id_flush),
        .debug_halt_i(debug_halt_i),
        .inst_o(if_inst),
        .pc_o(if_pc),
        .inst_valid_o(if_inst_valid),
        .ibus_addr_o(if_addr_o),
        .ibus_data_i(if_data_i),
        .ibus_data_o(if_data_o),
        .ibus_sel_o(if_sel_o),
        .ibus_we_o(if_we_o),
        .req_valid_o(if_req_vld_o),
        .req_ready_i(if_req_rdy_i),
        .rsp_valid_i(if_rsp_vld_i),
        .rsp_ready_o(if_rsp_rdy_o)
    );

    if_id u_if_id(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(if_inst),
        .pc_i(if_pc),
        .stall_if_id_i(if_id_hold),
        .flush_if_id_i(if_id_flush),
        .inst_o(if_id_inst),
        .pc_o(if_id_pc)
    );

    idu_top u_idu_top(
        .clk(clk),
        .rst_n(rst_n),
        .inst_i(if_id_inst),
        .pc_i(if_id_pc),
        .wb_reg_write_i(wb_reg_write),
        .wb_rd_waddr_i(wb_rd_waddr),
        .wb_wdata_i(wb_wdata),
        .gpr_we_o(gpr_we_o),
        .gpr_waddr_o(gpr_waddr_o),
        .gpr_wdata_o(gpr_wdata_o),
        .gpr_raddr1_o(gpr_raddr1_o),
        .gpr_rdata1_i(gpr_rdata1_i),
        .gpr_raddr2_o(gpr_raddr2_o),
        .gpr_rdata2_i(gpr_rdata2_i),
        .id_ex_mem_to_reg_i(id_ex_mem_to_reg),
        .id_ex_rd_waddr_i(id_ex_rd_waddr),
        .id_ex_reg_write_i(id_ex_reg_write),
        .ex_mem_result_i(ex_mem_result),
        .ex_mem_rd_waddr_i(ex_mem_rd_waddr),
        .ex_mem_reg_write_i(ex_mem_reg_write),
        .ex_mem_mem_to_reg_i(ex_mem_mem_to_reg),
        .branch_req_o(branch_req),
        .branch_taken_o(branch_taken),
        .branch_addr_o(branch_addr),
        .pc_flush_o(pc_flush),
        .if_id_flush_o(if_id_flush),
        .id_ex_flush_o(id_ex_flush_hazard),
        .data_rs1_o(id_data_rs1),
        .data_rs2_o(id_data_rs2),
        .imm_o(id_imm),
        .rs1_raddr_o(id_rs1_raddr),
        .rs2_raddr_o(id_rs2_raddr),
        .rd_waddr_o(id_rd_waddr),
        .reg_write_o(id_reg_write),
        .mem_to_reg_o(id_mem_to_reg),
        .mem_read_o(id_mem_read),
        .mem_write_o(id_mem_write),
        .mem_ctrl_o(id_mem_ctrl),
        .custom_ctrl_o(id_custom_ctrl),
        .alu_src_o(id_alu_src),
        .alu_ctrl_o(id_alu_ctrl)
    );

    id_ex u_id_ex(
        .clk(clk),
        .rst_n(rst_n),
        .stall_id_ex_i(id_ex_stall),
        .flush_id_ex_i(id_ex_flush | id_ex_flush_hazard),
        .data_rs1_i(id_data_rs1),
        .data_rs2_i(id_data_rs2),
        .imm_i(id_imm),
        .alu_src_i(id_alu_src),
        .alu_ctrl_i(id_alu_ctrl),
        .data_rs1_o(id_ex_data_rs1),
        .data_rs2_o(id_ex_data_rs2),
        .imm_o(id_ex_imm),
        .alu_src_o(id_ex_alu_src),
        .alu_ctrl_o(id_ex_alu_ctrl),
        .rs1_raddr_i(id_rs1_raddr),
        .rs2_raddr_i(id_rs2_raddr),
        .rd_waddr_i(id_rd_waddr),
        .rs1_raddr_o(id_ex_rs1_raddr),
        .rs2_raddr_o(id_ex_rs2_raddr),
        .rd_waddr_o(id_ex_rd_waddr),
        .mem_read_i(id_mem_read),
        .mem_write_i(id_mem_write),
        .mem_ctrl_i(id_mem_ctrl),
        .custom_ctrl_i(id_custom_ctrl),
        .mem_read_o(id_ex_mem_read),
        .mem_write_o(id_ex_mem_write),
        .mem_ctrl_o(id_ex_mem_ctrl),
        .custom_ctrl_o(id_ex_custom_ctrl),
        .reg_write_i(id_reg_write),
        .mem_to_reg_i(id_mem_to_reg),
        .reg_write_o(id_ex_reg_write),
        .mem_to_reg_o(id_ex_mem_to_reg)
    );

    exu_top u_exu_top(
        .clk(clk),
        .rst_n(rst_n),
        .data_rs1_i(id_ex_data_rs1),
        .data_rs2_i(id_ex_data_rs2),
        .imm_i(id_ex_imm),
        .alu_src_i(id_ex_alu_src),
        .alu_ctrl_i(id_ex_alu_ctrl),
        .rs1_raddr_i(id_ex_rs1_raddr),
        .rs2_raddr_i(id_ex_rs2_raddr),
        .rd_waddr_i(id_ex_rd_waddr),
        .reg_write_i(id_ex_reg_write),
        .mem_to_reg_i(id_ex_mem_to_reg),
        .mem_read_i(id_ex_mem_read),
        .mem_write_i(id_ex_mem_write),
        .mem_ctrl_i(id_ex_mem_ctrl),
        .custom_ctrl_i(id_ex_custom_ctrl),
        .result_ex_mem_i(ex_mem_forward_data),
        .result_mem_wb_i(wb_wdata),
        .rd_waddr_ex_mem_i(ex_mem_rd_waddr),
        .rd_waddr_mem_wb_i(wb_rd_waddr),
        .reg_write_ex_mem_i(ex_mem_reg_write),
        .reg_write_mem_wb_i(wb_reg_write),
        .result_o(ex_result),
        .mem_wdata_o(ex_mem_wdata),
        .rd_waddr_o(ex_rd_waddr),
        .reg_write_o(ex_reg_write),
        .mem_to_reg_o(ex_mem_to_reg),
        .mem_read_o(ex_mem_read),
        .mem_write_o(ex_mem_write),
        .mem_ctrl_o(ex_mem_ctrl),
        .custom_ctrl_o(ex_custom_ctrl)
    );

    assign ex_mem_forward_data = ex_mem_mem_to_reg ? mem_rdata : ex_mem_result;

    ex_mem u_ex_mem(
        .clk(clk),
        .rst_n(rst_n),
        .stall_ex_mem_i(ex_mem_stall),
        .result_i(ex_result),
        .mem_wdata_i(ex_mem_wdata),
        .rd_waddr_i(ex_rd_waddr),
        .mem_read_i(ex_mem_read),
        .mem_write_i(ex_mem_write),
        .mem_ctrl_i(ex_mem_ctrl),
        .custom_ctrl_i(ex_custom_ctrl),
        .result_o(ex_mem_result),
        .mem_wdata_o(ex_mem_mem_wdata),
        .rd_waddr_o(ex_mem_rd_waddr),
        .mem_read_o(ex_mem_mem_read),
        .mem_write_o(ex_mem_mem_write),
        .mem_ctrl_o(ex_mem_mem_ctrl),
        .custom_ctrl_o(ex_mem_custom_ctrl),
        .reg_write_i(ex_reg_write),
        .reg_write_o(ex_mem_reg_write),
        .mem_to_reg_i(ex_mem_to_reg),
        .mem_to_reg_o(ex_mem_mem_to_reg)
    );

    mem_top u_mem_top(
        .clk(clk),
        .rst_n(rst_n),
        .result_i(ex_mem_result),
        .mem_wdata_i(ex_mem_mem_wdata),
        .rd_waddr_i(ex_mem_rd_waddr),
        .reg_write_i(ex_mem_reg_write),
        .mem_to_reg_i(ex_mem_mem_to_reg),
        .mem_read_i(ex_mem_mem_read),
        .mem_write_i(ex_mem_mem_write),
        .mem_ctrl_i(ex_mem_mem_ctrl),
        .custom_ctrl_i(ex_mem_custom_ctrl),
        .rib_addr_o(mem_addr_o),
        .rib_data_o(mem_data_o),
        .rib_sel_o(mem_sel_o),
        .rib_req_vld_o(mem_req_vld_o),
        .rib_req_rdy_i(mem_req_rdy_i),
        .rib_rsp_rdy_o(mem_rsp_rdy_o),
        .rib_rsp_vld_i(mem_rsp_vld_i),
        .rib_data_i(mem_data_i),
        .rib_we_o(mem_we_o),
        .result_o(mem_result),
        .mem_rdata_o(mem_rdata),
        .rd_waddr_o(mem_rd_waddr),
        .reg_write_o(mem_reg_write),
        .mem_to_reg_o(mem_mem_to_reg),
        .stall_req_o(stall_req_mem)
    );

    mem_wb u_mem_wb(
        .clk(clk),
        .rst_n(rst_n),
        .stall_mem_wb_i(mem_wb_stall),
        .result_i(mem_result),
        .mem_rdata_i(mem_rdata),
        .rd_waddr_i(mem_rd_waddr),
        .reg_write_i(mem_reg_write),
        .mem_to_reg_i(mem_mem_to_reg),
        .result_o(mem_wb_result),
        .mem_rdata_o(mem_wb_rdata),
        .rd_waddr_o(mem_wb_rd_waddr),
        .reg_write_o(mem_wb_reg_write),
        .mem_to_reg_o(mem_wb_mem_to_reg)
    );

    wbu_top u_wbu_top(
        .result_i(mem_wb_result),
        .mem_rdata_i(mem_wb_rdata),
        .rd_waddr_i(mem_wb_rd_waddr),
        .reg_write_i(mem_wb_reg_write),
        .mem_to_reg_i(mem_wb_mem_to_reg),
        .wb_wdata_o(wb_wdata),
        .wb_rd_waddr_o(wb_rd_waddr),
        .wb_reg_write_o(wb_reg_write)
    );

endmodule
