`timescale 1ns / 1ps

`include "../../top/macros.v"

module id_ex(

    input wire clk,
    input wire rst_n,

    // from pipeline control
    input wire stall_id_ex_i,
    input wire flush_id_ex_i,

    // to ex
    input wire[`DATA_WIDTH-1:0] data_rs1_i,
    input wire[`DATA_WIDTH-1:0] data_rs2_i,
    input wire[`DATA_WIDTH-1:0] imm_i,
    input wire alu_src_i,
    input wire[`ALU_CTRL_WIDTH-1:0] alu_ctrl_i,

    output reg[`DATA_WIDTH-1:0] data_rs1_o,
    output reg[`DATA_WIDTH-1:0] data_rs2_o,
    output reg[`DATA_WIDTH-1:0] imm_o,
    output reg alu_src_o,
    output reg[`ALU_CTRL_WIDTH-1:0] alu_ctrl_o,

    // to ex for forwarding unit
    input wire[`GPR_ADDR_WIDTH-1:0] rs1_raddr_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rs2_raddr_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    output reg[`GPR_ADDR_WIDTH-1:0] rs1_raddr_o,
    output reg[`GPR_ADDR_WIDTH-1:0] rs2_raddr_o,
    output reg[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,

    // to mem
    input wire mem_read_i,
    input wire mem_write_i,
    input wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_i,
    input wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_i,
    output reg mem_read_o,
    output reg mem_write_o,
    output reg[`MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    output reg[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_o,

    // to wb
    input wire reg_write_i,
    input wire mem_to_reg_i,
    output reg reg_write_o,
    output reg mem_to_reg_o
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_rs1_o <= {`DATA_WIDTH{1'b0}};
            data_rs2_o <= {`DATA_WIDTH{1'b0}};
            imm_o <= {`DATA_WIDTH{1'b0}};
            rs1_raddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            rs2_raddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            rd_waddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            reg_write_o <= 1'b0;
            mem_to_reg_o <= 1'b0;
            mem_read_o <= 1'b0;
            mem_write_o <= 1'b0;
            mem_ctrl_o <= `MEM_CTRL_SW;
            custom_ctrl_o <= `CUSTOM_NONE;
            alu_src_o <= 1'b0;
            alu_ctrl_o <= `ALU_CTRL_ADD;
        end else if (flush_id_ex_i) begin
            data_rs1_o <= {`DATA_WIDTH{1'b0}};
            data_rs2_o <= {`DATA_WIDTH{1'b0}};
            imm_o <= {`DATA_WIDTH{1'b0}};
            rs1_raddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            rs2_raddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            rd_waddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            reg_write_o <= 1'b0;
            mem_to_reg_o <= 1'b0;
            mem_read_o <= 1'b0;
            mem_write_o <= 1'b0;
            mem_ctrl_o <= `MEM_CTRL_SW;
            custom_ctrl_o <= `CUSTOM_NONE;
            alu_src_o <= 1'b0;
            alu_ctrl_o <= `ALU_CTRL_ADD;
        end else if (!stall_id_ex_i) begin
            data_rs1_o <= data_rs1_i;
            data_rs2_o <= data_rs2_i;
            imm_o <= imm_i;
            rs1_raddr_o <= rs1_raddr_i;
            rs2_raddr_o <= rs2_raddr_i;
            rd_waddr_o <= rd_waddr_i;
            reg_write_o <= reg_write_i;
            mem_to_reg_o <= mem_to_reg_i;
            mem_read_o <= mem_read_i;
            mem_write_o <= mem_write_i;
            mem_ctrl_o <= mem_ctrl_i;
            custom_ctrl_o <= custom_ctrl_i;
            alu_src_o <= alu_src_i;
            alu_ctrl_o <= alu_ctrl_i;
        end
    end

endmodule
