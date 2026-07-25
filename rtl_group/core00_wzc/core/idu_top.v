`include "../marcos.v"

module idu_top(

    input wire clk,
    input wire rst_n,

    // from IF/ID
    input wire[`INST_WIDTH-1:0] inst_i,
    input wire[`PC_WIDTH-1:0] pc_i,

    // from WB
    input wire wb_reg_write_i,
    input wire[`GPR_ADDR_WIDTH-1:0] wb_rd_waddr_i,
    input wire[`DATA_WIDTH-1:0] wb_wdata_i,

    // external shared GPR interface
    output wire gpr_we_o,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_waddr_o,
    output wire[`DATA_WIDTH-1:0] gpr_wdata_o,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_raddr1_o,
    input wire[`DATA_WIDTH-1:0] gpr_rdata1_i,
    output wire[`GPR_ADDR_WIDTH-1:0] gpr_raddr2_o,
    input wire[`DATA_WIDTH-1:0] gpr_rdata2_i,

    // from ID/EX, for hazard detector
    input wire id_ex_mem_to_reg_i,
    input wire[`GPR_ADDR_WIDTH-1:0] id_ex_rd_waddr_i,
    input wire id_ex_reg_write_i,

    // from EX and WB, for ID-stage branch/jalr forwarding
    input wire[`DATA_WIDTH-1:0] ex_mem_result_i,
    input wire[`GPR_ADDR_WIDTH-1:0] ex_mem_rd_waddr_i,
    input wire ex_mem_reg_write_i,
    input wire ex_mem_mem_to_reg_i,
    // to IF/PC
    output wire branch_req_o,
    output wire branch_taken_o,
    output wire[`PC_WIDTH-1:0] branch_addr_o,
    output wire pc_flush_o,
    output wire if_id_flush_o,
    output wire id_ex_flush_o,

    // to EX
    output wire[`DATA_WIDTH-1:0] data_rs1_o,
    output wire[`DATA_WIDTH-1:0] data_rs2_o,
    output wire[`DATA_WIDTH-1:0] imm_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output wire reg_write_o,
    output wire mem_to_reg_o,
    output wire mem_read_o,
    output wire mem_write_o,
    output wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    output wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_o,
    output wire alu_src_o,
    output wire[`ALU_CTRL_WIDTH-1:0] alu_ctrl_o

    );

    wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr;
    wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr;
    wire rs1_re;
    wire rs2_re;
    wire[`GPR_ADDR_WIDTH-1:0] rd_waddr;
    wire reg_write;
    wire mem_to_reg;
    wire alu_src;
    wire[`ALU_CTRL_WIDTH-1:0] alu_ctrl;
    wire mem_read;
    wire mem_write;
    wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl;
    wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl;

    wire[`DATA_WIDTH-1:0] imm;
    wire[`DATA_WIDTH-1:0] data_rs1;
    wire[`DATA_WIDTH-1:0] data_rs2;

    wire branch_req;
    wire branch_condition;
    wire hazard_id_ex_flush;

    idu_decoder u_idu_decoder(
        .inst_i(inst_i),
        .rs1_raddr_o(rs1_raddr),
        .rs2_raddr_o(rs2_raddr),
        .rs1_re_o(rs1_re),
        .rs2_re_o(rs2_re),
        .rd_waddr_o(rd_waddr),
        .reg_write_o(reg_write),
        .mem_to_reg_o(mem_to_reg),
        .alu_src_o(alu_src),
        .alu_ctrl_o(alu_ctrl),
        .mem_read_o(mem_read),
        .mem_write_o(mem_write),
        .mem_ctrl_o(mem_ctrl),
        .custom_ctrl_o(custom_ctrl),
        .branch_o()
    );

    idu_imm_gen u_idu_imm_gen(
        .inst_i(inst_i),
        .imm_o(imm)
    );

    idu_gpr_mux u_idu_gpr_mux(
        .inst_i(inst_i),
        .pc_i(pc_i),
        .rdata1_i(gpr_rdata1_i),
        .rdata2_i(gpr_rdata2_i),
        .data_rs1_o(data_rs1),
        .data_rs2_o(data_rs2)
    );

    idu_branch_predictor u_idu_branch_predictor(
        .inst_i(inst_i),
        .pc_i(pc_i),
        .imm_i(imm),
        .rs1_raddr_i(rs1_raddr),
        .rs2_raddr_i(rs2_raddr),
        .rdata1_i(gpr_rdata1_i),
        .rdata2_i(gpr_rdata2_i),
        .ex_mem_result_i(ex_mem_result_i),
        .ex_mem_rd_waddr_i(ex_mem_rd_waddr_i),
        .ex_mem_reg_write_i(ex_mem_reg_write_i),
        .ex_mem_mem_to_reg_i(ex_mem_mem_to_reg_i),
        .branch_req_o(branch_req),
        .branch_condition_o(branch_condition),
        .branch_addr_o(branch_addr_o)
    );

    idu_hazard_detector u_idu_hazard_detector(
        .if_id_rs1_i(rs1_raddr),
        .if_id_rs2_i(rs2_raddr),
        .if_id_rs1_re_i(rs1_re),
        .if_id_rs2_re_i(rs2_re),
        .id_ex_mem_to_reg_i(id_ex_mem_to_reg_i),
        .id_ex_rd_i(id_ex_rd_waddr_i),
        .id_ex_reg_write_i(id_ex_reg_write_i),
        .ex_mem_mem_to_reg_i(ex_mem_mem_to_reg_i),
        .ex_mem_rd_i(ex_mem_rd_waddr_i),
        .ex_mem_reg_write_i(ex_mem_reg_write_i),
        .branch_req_i(branch_req),
        .branch_condition_i(branch_condition),
        .pc_flush_o(pc_flush_o),
        .if_id_flush_o(if_id_flush_o),
        .id_ex_flush_o(hazard_id_ex_flush),
        .branch_taken_o(branch_taken_o)
    );

    assign id_ex_flush_o = hazard_id_ex_flush;
    assign branch_req_o = branch_req;

    assign data_rs1_o = data_rs1;
    assign data_rs2_o = data_rs2;
    assign gpr_we_o = wb_reg_write_i;
    assign gpr_waddr_o = wb_rd_waddr_i;
    assign gpr_wdata_o = wb_wdata_i;
    assign gpr_raddr1_o = rs1_raddr;
    assign gpr_raddr2_o = rs2_raddr;
    assign imm_o = imm;
    assign rs1_raddr_o = (inst_i[6:0] == `OPCODE_TYPE_I_JALR) ? {`GPR_ADDR_WIDTH{1'b0}} : rs1_raddr;
    assign rs2_raddr_o = rs2_raddr;
    assign rd_waddr_o = rd_waddr;
    assign reg_write_o = reg_write;
    assign mem_to_reg_o = mem_to_reg;
    assign mem_read_o = mem_read;
    assign mem_write_o = mem_write;
    assign mem_ctrl_o = mem_ctrl;
    assign custom_ctrl_o = custom_ctrl;
    assign alu_src_o = alu_src;
    assign alu_ctrl_o = alu_ctrl;

endmodule
