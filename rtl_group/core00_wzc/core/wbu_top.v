`include "../marcos.v"

module wbu_top(

    input wire[`DATA_WIDTH-1:0] result_i,
    input wire[`DATA_WIDTH-1:0] mem_rdata_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    input wire reg_write_i,
    input wire mem_to_reg_i,

    output wire[`DATA_WIDTH-1:0] wb_wdata_o,
    output wire[`GPR_ADDR_WIDTH-1:0] wb_rd_waddr_o,
    output wire wb_reg_write_o

    );

    assign wb_wdata_o = mem_to_reg_i ? mem_rdata_i : result_i;
    assign wb_rd_waddr_o = rd_waddr_i;
    assign wb_reg_write_o = reg_write_i & (|rd_waddr_i);

endmodule
