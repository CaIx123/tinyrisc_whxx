`include "../marcos_wzc.v"

module exu_top(

    input wire clk,
    input wire rst_n,

    // from ID/EX
    // to alu_mux
    input wire[`DATA_WIDTH-1:0] data_rs1_i,
    input wire[`DATA_WIDTH-1:0] data_rs2_i,
    input wire[`DATA_WIDTH-1:0] imm_i,
    input wire alu_src_i,
    // to alu
    input wire[`ALU_CTRL_WIDTH-1:0] alu_ctrl_i,
    // to forwarding unit
    input wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    // to mem
    input wire mem_read_i,
    input wire mem_write_i,
    input wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_i,
    input wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_i,
    // to wb
    input wire reg_write_i,
    input wire mem_to_reg_i,

    // from EX/MEM and MEM/WB forwarding paths
    input wire[`DATA_WIDTH-1:0] result_ex_mem_i,
    input wire[`DATA_WIDTH-1:0] result_mem_wb_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_ex_mem_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_mem_wb_i,
    input wire reg_write_ex_mem_i,
    input wire reg_write_mem_wb_i,

    // to EX/MEM
    output wire[`DATA_WIDTH-1:0] result_o,
    output wire[`DATA_WIDTH-1:0] mem_wdata_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output wire reg_write_o,
    output wire mem_to_reg_o,
    output wire mem_read_o,
    output wire mem_write_o,
    output wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    output wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_o

    );

    wire[1:0] forward_a;
    wire[1:0] forward_b;

    wire[`DATA_WIDTH-1:0] src_a;
    wire[`DATA_WIDTH-1:0] src_b;
    wire[`DATA_WIDTH-1:0] data_rs2;

    wire[`DATA_WIDTH-1:0] alu_result;
    exu_forwarding_unit u_exu_forwarding_unit(
        .rs1_addr_i(rs1_raddr_i),
        .rs2_addr_i(rs2_raddr_i),
        .ex_mem_rd_addr_i(rd_waddr_ex_mem_i),
        .mem_wb_rd_addr_i(rd_waddr_mem_wb_i),
        .ex_mem_reg_write_i(reg_write_ex_mem_i),
        .mem_wb_reg_write_i(reg_write_mem_wb_i),
        .forward_a_o(forward_a),
        .forward_b_o(forward_b)
    );

    exu_alu_mux u_exu_alu_mux(
        .forward_a_i(forward_a),
        .forward_b_i(forward_b),
        .alu_src_i(alu_src_i),
        .result_ex_mem_i(result_ex_mem_i),
        .result_mem_wb_i(result_mem_wb_i),
        .data_rs1_i(data_rs1_i),
        .data_rs2_i(data_rs2_i),
        .imm_i(imm_i),
        .alu_src_a_o(src_a),
        .alu_src_b_o(src_b),
        .data_rs2_o(data_rs2)
    );

    exu_alu u_exu_alu(
        .alu_src_a_i(src_a),
        .alu_src_b_i(src_b),
        .alu_ctrl_i(alu_ctrl_i),
        .alu_result_o(alu_result)
    );

    assign result_o = alu_result;
    assign mem_wdata_o = (custom_ctrl_i == `CUSTOM_IF) ? src_a : data_rs2;
    assign rd_waddr_o = rd_waddr_i;
    assign reg_write_o = reg_write_i;
    assign mem_to_reg_o = mem_to_reg_i;
    assign mem_read_o = mem_read_i;
    assign mem_write_o = mem_write_i;
    assign mem_ctrl_o = mem_ctrl_i;
    assign custom_ctrl_o = custom_ctrl_i;
endmodule
