`timescale 1ns / 1ps

`include "../../top/macros.v"

module idu_hazard_detector(

    // from IF/ID decoder
    input wire[`GPR_ADDR_WIDTH-1:0] if_id_rs1_i,
    input wire[`GPR_ADDR_WIDTH-1:0] if_id_rs2_i,
    input wire if_id_rs1_re_i,
    input wire if_id_rs2_re_i,

    // from ID/EX pipeline register
    input wire id_ex_mem_to_reg_i,
    input wire[`GPR_ADDR_WIDTH-1:0] id_ex_rd_i,
    input wire id_ex_reg_write_i,

    // from EX/MEM pipeline register
    input wire ex_mem_mem_to_reg_i,
    input wire[`GPR_ADDR_WIDTH-1:0] ex_mem_rd_i,
    input wire ex_mem_reg_write_i,

    // from ID branch decision
    input wire branch_req_i,
    input wire branch_condition_i,

    // to PC / IF/ID / ID/EX pipeline control
    output wire pc_flush_o,
    output wire if_id_flush_o,
    output wire id_ex_flush_o,
    output wire branch_taken_o

    );

    wire rd_valid = id_ex_reg_write_i & (|id_ex_rd_i);
    wire ex_mem_rd_valid = ex_mem_reg_write_i & (|ex_mem_rd_i);
    wire rs1_hazard = if_id_rs1_re_i & (id_ex_rd_i == if_id_rs1_i);
    wire rs2_hazard = if_id_rs2_re_i & (id_ex_rd_i == if_id_rs2_i);
    wire ex_mem_rs1_hazard = if_id_rs1_re_i & (ex_mem_rd_i == if_id_rs1_i);
    wire ex_mem_rs2_hazard = if_id_rs2_re_i & (ex_mem_rd_i == if_id_rs2_i);
    wire id_ex_mem_hazard = id_ex_mem_to_reg_i & rd_valid & (rs1_hazard | rs2_hazard);
    wire branch_ex_hazard = branch_req_i & rd_valid & (rs1_hazard | rs2_hazard);
    wire ex_mem_stage_hazard = ex_mem_mem_to_reg_i & ex_mem_rd_valid & (ex_mem_rs1_hazard | ex_mem_rs2_hazard);

    assign pc_flush_o = id_ex_mem_hazard | branch_ex_hazard | ex_mem_stage_hazard;
    assign branch_taken_o = branch_req_i & branch_condition_i & ~branch_ex_hazard;
    assign if_id_flush_o = branch_taken_o;
    assign id_ex_flush_o = id_ex_mem_hazard | branch_ex_hazard | ex_mem_stage_hazard;

endmodule
