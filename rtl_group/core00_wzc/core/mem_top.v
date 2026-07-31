`timescale 1ns / 1ps

`include "../../top/macros.v"

module mem_top(

    input wire clk,
    input wire rst_n,

    // from EX/MEM
    input wire[`DATA_WIDTH-1:0] result_i,
    input wire[`DATA_WIDTH-1:0] mem_wdata_i,
    input wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_i,
    input wire reg_write_i,
    input wire mem_to_reg_i,
    input wire mem_read_i,
    input wire mem_write_i,
    input wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_i,
    input wire[`CUSTOM_CTRL_WIDTH-1:0] custom_ctrl_i,

    // to RIB master
    output wire[`DATA_WIDTH-1:0] rib_addr_o,
    output wire[`DATA_WIDTH-1:0] rib_data_o,
    output wire[3:0] rib_sel_o,
    output wire rib_req_vld_o,
    input wire rib_req_rdy_i,
    output wire rib_rsp_rdy_o,
    input wire rib_rsp_vld_i,
    input wire[`DATA_WIDTH-1:0] rib_data_i,
    output wire rib_we_o,

    // to MEM/WB
    output wire[`DATA_WIDTH-1:0] result_o,
    output wire[`DATA_WIDTH-1:0] mem_rdata_o,
    output wire[`GPR_ADDR_WIDTH-1:0] rd_waddr_o,
    output wire reg_write_o,
    output wire mem_to_reg_o,

    // to pipeline control
    output wire stall_req_o

    );

    wire lsu_active = (custom_ctrl_i == `CUSTOM_NONE) & (mem_read_i | mem_write_i);
    wire sid_active = (custom_ctrl_i == `CUSTOM_SID);
    wire rt_active = (custom_ctrl_i == `CUSTOM_RT);
    wire ifu_active = (custom_ctrl_i == `CUSTOM_IF);

    wire lsu_start = lsu_active;
    wire sid_start = sid_active;
    wire rt_start = rt_active;
    wire ifu_start = ifu_active;

    wire lsu_busy;
    wire lsu_ready;
    wire[`DATA_WIDTH-1:0] lsu_rdata;
    wire[`DATA_WIDTH-1:0] lsu_rib_addr;
    wire[`DATA_WIDTH-1:0] lsu_rib_data;
    wire[3:0] lsu_rib_sel;
    wire lsu_rib_req_vld;
    wire lsu_rib_rsp_rdy;
    wire lsu_rib_we;

    wire sid_busy;
    wire sid_ready;
    wire[`DATA_WIDTH-1:0] sid_rib_addr;
    wire[`DATA_WIDTH-1:0] sid_rib_data;
    wire[3:0] sid_rib_sel;
    wire sid_rib_req_vld;
    wire sid_rib_rsp_rdy;
    wire sid_rib_we;

    wire rt_busy;
    wire rt_ready;
    wire[`DATA_WIDTH-1:0] rt_wdata;
    wire[`DATA_WIDTH-1:0] rt_rib_addr;
    wire[`DATA_WIDTH-1:0] rt_rib_data;
    wire[3:0] rt_rib_sel;
    wire rt_rib_req_vld;
    wire rt_rib_rsp_rdy;
    wire rt_rib_we;

    wire ifu_busy;
    wire ifu_ready;
    wire[`DATA_WIDTH-1:0] ifu_wdata;
    wire[`DATA_WIDTH-1:0] ifu_rib_addr;
    wire[`DATA_WIDTH-1:0] ifu_rib_data;
    wire[3:0] ifu_rib_sel;
    wire ifu_rib_req_vld;
    wire ifu_rib_rsp_rdy;
    wire ifu_rib_we;

    wire lsu_accept = lsu_ready;
    wire sid_accept = sid_ready;
    wire rt_accept = rt_ready;
    wire ifu_accept = ifu_ready;

    mem_lsu u_mem_lsu(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(lsu_start),
        .accept_i(lsu_accept),
        .mem_read_i(mem_read_i),
        .mem_write_i(mem_write_i),
        .addr_i(result_i),
        .wdata_i(mem_wdata_i),
        .mem_ctrl_i(mem_ctrl_i),
        .busy_o(lsu_busy),
        .ready_o(lsu_ready),
        .rdata_o(lsu_rdata),
        .rib_addr_o(lsu_rib_addr),
        .rib_data_o(lsu_rib_data),
        .rib_sel_o(lsu_rib_sel),
        .rib_req_vld_o(lsu_rib_req_vld),
        .rib_req_rdy_i(rib_req_rdy_i),
        .rib_rsp_rdy_o(lsu_rib_rsp_rdy),
        .rib_rsp_vld_i(rib_rsp_vld_i),
        .rib_data_i(rib_data_i),
        .rib_we_o(lsu_rib_we)
    );

    mem_sidu u_mem_sidu(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(sid_start),
        .accept_i(sid_accept),
        .busy_o(sid_busy),
        .ready_o(sid_ready),
        .rib_addr_o(sid_rib_addr),
        .rib_data_o(sid_rib_data),
        .rib_sel_o(sid_rib_sel),
        .rib_req_vld_o(sid_rib_req_vld),
        .rib_req_rdy_i(rib_req_rdy_i),
        .rib_rsp_rdy_o(sid_rib_rsp_rdy),
        .rib_rsp_vld_i(rib_rsp_vld_i),
        .rib_data_i(rib_data_i),
        .rib_we_o(sid_rib_we)
    );

    mem_rtu u_mem_rtu(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(rt_start),
        .accept_i(rt_accept),
        .busy_o(rt_busy),
        .ready_o(rt_ready),
        .reg_wdata_o(rt_wdata),
        .rib_addr_o(rt_rib_addr),
        .rib_data_o(rt_rib_data),
        .rib_sel_o(rt_rib_sel),
        .rib_req_vld_o(rt_rib_req_vld),
        .rib_req_rdy_i(rib_req_rdy_i),
        .rib_rsp_rdy_o(rt_rib_rsp_rdy),
        .rib_rsp_vld_i(rib_rsp_vld_i),
        .rib_data_i(rib_data_i),
        .rib_we_o(rt_rib_we)
    );

    mem_ifu u_mem_ifu(
        .clk(clk),
        .rst_n(rst_n),
        .start_i(ifu_start),
        .accept_i(ifu_accept),
        .rs1_data_i(mem_wdata_i),
        .less_result_i(result_i),
        .busy_o(ifu_busy),
        .ready_o(ifu_ready),
        .reg_wdata_o(ifu_wdata),
        .rib_addr_o(ifu_rib_addr),
        .rib_data_o(ifu_rib_data),
        .rib_sel_o(ifu_rib_sel),
        .rib_req_vld_o(ifu_rib_req_vld),
        .rib_req_rdy_i(rib_req_rdy_i),
        .rib_rsp_rdy_o(ifu_rib_rsp_rdy),
        .rib_rsp_vld_i(rib_rsp_vld_i),
        .rib_data_i(rib_data_i),
        .rib_we_o(ifu_rib_we)
    );

    assign rib_addr_o = sid_active ? sid_rib_addr :
                        rt_active ? rt_rib_addr :
                        ifu_active ? ifu_rib_addr :
                        lsu_rib_addr;
    assign rib_data_o = sid_active ? sid_rib_data :
                        rt_active ? rt_rib_data :
                        ifu_active ? ifu_rib_data :
                        lsu_rib_data;
    assign rib_sel_o = sid_active ? sid_rib_sel :
                       rt_active ? rt_rib_sel :
                       ifu_active ? ifu_rib_sel :
                       lsu_rib_sel;
    assign rib_req_vld_o = sid_active ? sid_rib_req_vld :
                           rt_active ? rt_rib_req_vld :
                           ifu_active ? ifu_rib_req_vld :
                           lsu_rib_req_vld;
    assign rib_rsp_rdy_o = sid_active ? sid_rib_rsp_rdy :
                           rt_active ? rt_rib_rsp_rdy :
                           ifu_active ? ifu_rib_rsp_rdy :
                           lsu_rib_rsp_rdy;
    assign rib_we_o = sid_active ? sid_rib_we :
                      rt_active ? rt_rib_we :
                      ifu_active ? ifu_rib_we :
                      lsu_rib_we;

    assign result_o = result_i;
    assign mem_rdata_o = rt_active ? rt_wdata :
                         ifu_active ? ifu_wdata :
                         lsu_rdata;
    assign rd_waddr_o = rd_waddr_i;
    assign reg_write_o = reg_write_i;
    assign mem_to_reg_o = mem_to_reg_i;

    assign stall_req_o = (lsu_active & (lsu_busy | (lsu_start & ~lsu_ready))) |
                         (sid_active & ~sid_ready) |
                         (rt_active & ~rt_ready) |
                         (ifu_active & ~ifu_ready);

endmodule
