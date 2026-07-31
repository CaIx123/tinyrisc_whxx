`timescale 1ns / 1ps

`include "../../top/macros.v"

module exu_forwarding_unit(
  input wire[`GPR_ADDR_WIDTH-1:0] rs1_addr_i,
  input wire[`GPR_ADDR_WIDTH-1:0] rs2_addr_i,
  input wire[`GPR_ADDR_WIDTH-1:0] ex_mem_rd_addr_i,
  input wire[`GPR_ADDR_WIDTH-1:0] mem_wb_rd_addr_i,
  input wire ex_mem_reg_write_i,
  input wire mem_wb_reg_write_i,

  output reg [1:0] forward_a_o,
  output reg [1:0] forward_b_o
);
  always @(*) begin
    forward_a_o = 2'b0;
    forward_b_o = 2'b0;

    if (ex_mem_reg_write_i && (ex_mem_rd_addr_i != 0) && (ex_mem_rd_addr_i == rs1_addr_i)) begin
      forward_a_o = 2'b01;
    end else if (mem_wb_reg_write_i && (mem_wb_rd_addr_i != 0) && (mem_wb_rd_addr_i == rs1_addr_i)) begin
      forward_a_o = 2'b10;
    end

    if (ex_mem_reg_write_i && (ex_mem_rd_addr_i != 0) && (ex_mem_rd_addr_i == rs2_addr_i)) begin
      forward_b_o = 2'b01;
    end else if (mem_wb_reg_write_i && (mem_wb_rd_addr_i != 0) && (mem_wb_rd_addr_i == rs2_addr_i)) begin
      forward_b_o = 2'b10;
    end
  end

endmodule
