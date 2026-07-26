`include "../marcos_wzc.v"

module ex_mem(

    input wire clk,
    input wire rst_n,

    input wire stall_ex_mem_i,

    // from EX
    input wire[`DATA_WIDTH-1:0] result_i,
    input wire[`DATA_WIDTH-1:0] mem_wdata_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    input wire mem_read_i,
    input wire mem_write_i,
    input wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_i,
    input wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_i,

    // to MEM
    output reg[`DATA_WIDTH-1:0] result_o,
    output reg[`DATA_WIDTH-1:0] mem_wdata_o,
    output reg[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output reg mem_read_o,
    output reg mem_write_o,
    output reg[`MEM_CTRL_WIDTH-1:0] mem_ctrl_o,
    output reg[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_o,

    // to WB
    input wire reg_write_i,
    output reg reg_write_o,
    input wire mem_to_reg_i,
    output reg mem_to_reg_o

    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_o <= {`DATA_WIDTH{1'b0}};
            mem_wdata_o <= {`DATA_WIDTH{1'b0}};
            rd_waddr_o <= {`GPR_ADDR_WIDTH{1'b0}};
            reg_write_o <= 1'b0;
            mem_to_reg_o <= 1'b0;
            mem_read_o <= 1'b0;
            mem_write_o <= 1'b0;
            mem_ctrl_o <= `MEM_CTRL_SW;
            custom_ctrl_o <= `CUSTOM_NONE;
        end else if (stall_ex_mem_i) begin
            result_o <= result_o;
            mem_wdata_o <= mem_wdata_o;
            rd_waddr_o <= rd_waddr_o;
            reg_write_o <= reg_write_o;
            mem_to_reg_o <= mem_to_reg_o;
            mem_read_o <= mem_read_o;
            mem_write_o <= mem_write_o;
            mem_ctrl_o <= mem_ctrl_o;
            custom_ctrl_o <= custom_ctrl_o;
        end else begin
            result_o <= result_i;
            mem_wdata_o <= mem_wdata_i;
            rd_waddr_o <= rd_waddr_i;
            reg_write_o <= reg_write_i;
            mem_to_reg_o <= mem_to_reg_i;
            mem_read_o <= mem_read_i;
            mem_write_o <= mem_write_i;
            mem_ctrl_o <= mem_ctrl_i;
            custom_ctrl_o <= custom_ctrl_i;
        end
    end

endmodule
