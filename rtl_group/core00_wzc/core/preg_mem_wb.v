`timescale 1ns / 1ps

`include "../../top/macros.v"

module mem_wb(

    input wire clk,
    input wire rst_n,

    input wire stall_mem_wb_i,

    // from MEM
    input wire[`DATA_WIDTH-1:0] result_i,
    input wire[`DATA_WIDTH-1:0] mem_rdata_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    input wire reg_write_i,
    input wire mem_to_reg_i,

    // to WB
    output reg[`DATA_WIDTH-1:0] result_o,
    output reg[`DATA_WIDTH-1:0] mem_rdata_o,
    output reg[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output reg reg_write_o,
    output reg mem_to_reg_o

    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_o <= {`DATA_WIDTH{1'b0}};
            mem_rdata_o <= {`DATA_WIDTH{1'b0}};
            rd_waddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            reg_write_o <= 1'b0;
            mem_to_reg_o <= 1'b0;
        end else if (stall_mem_wb_i) begin
            result_o <= result_o;
            mem_rdata_o <= mem_rdata_o;
            rd_waddr_o <= rd_waddr_o;
            reg_write_o <= reg_write_o;
            mem_to_reg_o <= mem_to_reg_o;
        end else begin
            result_o <= result_i;
            mem_rdata_o <= mem_rdata_i;
            rd_waddr_o <= rd_waddr_i;
            reg_write_o <= reg_write_i;
            mem_to_reg_o <= mem_to_reg_i;
        end
    end

endmodule
