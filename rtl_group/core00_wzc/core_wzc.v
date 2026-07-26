`include "marcos_wzc.v"

// WZC core wrapper with external shared-GPR and RIB master interfaces.
module core_wzc (
    input wire clk,
    input wire rst_n,
    input wire debug_halt_i,

    output wire gpr_we_o,
    output wire [`GPR_ADDR_WIDTH-1:0] gpr_waddr_o,
    output wire [`DATA_WIDTH-1:0] gpr_wdata_o,
    output wire [`GPR_ADDR_WIDTH-1:0] gpr_raddr1_o,
    input wire [`DATA_WIDTH-1:0] gpr_rdata1_i,
    output wire [`GPR_ADDR_WIDTH-1:0] gpr_raddr2_o,
    input wire [`DATA_WIDTH-1:0] gpr_rdata2_i,

    output wire [`DATA_WIDTH-1:0] if_addr_o,
    output wire [`DATA_WIDTH-1:0] if_data_o,
    output wire [3:0] if_sel_o,
    output wire if_req_vld_o,
    input wire if_req_rdy_i,
    output wire if_rsp_rdy_o,
    input wire if_rsp_vld_i,
    input wire [`DATA_WIDTH-1:0] if_data_i,
    output wire if_we_o,

    output wire [`DATA_WIDTH-1:0] mem_addr_o,
    output wire [`DATA_WIDTH-1:0] mem_data_o,
    output wire [3:0] mem_sel_o,
    output wire mem_req_vld_o,
    input wire mem_req_rdy_i,
    output wire mem_rsp_rdy_o,
    input wire mem_rsp_vld_i,
    input wire [`DATA_WIDTH-1:0] mem_data_i,
    output wire mem_we_o
);

    kalsit_core u_kalsit_core (
        .clk(clk),
        .rst_n(rst_n),
        .debug_halt_i(debug_halt_i),
        .gpr_we_o(gpr_we_o),
        .gpr_waddr_o(gpr_waddr_o),
        .gpr_wdata_o(gpr_wdata_o),
        .gpr_raddr1_o(gpr_raddr1_o),
        .gpr_rdata1_i(gpr_rdata1_i),
        .gpr_raddr2_o(gpr_raddr2_o),
        .gpr_rdata2_i(gpr_rdata2_i),
        .if_addr_o(if_addr_o),
        .if_data_o(if_data_o),
        .if_sel_o(if_sel_o),
        .if_req_vld_o(if_req_vld_o),
        .if_req_rdy_i(if_req_rdy_i),
        .if_rsp_rdy_o(if_rsp_rdy_o),
        .if_rsp_vld_i(if_rsp_vld_i),
        .if_data_i(if_data_i),
        .if_we_o(if_we_o),
        .mem_addr_o(mem_addr_o),
        .mem_data_o(mem_data_o),
        .mem_sel_o(mem_sel_o),
        .mem_req_vld_o(mem_req_vld_o),
        .mem_req_rdy_i(mem_req_rdy_i),
        .mem_rsp_rdy_o(mem_rsp_rdy_o),
        .mem_rsp_vld_i(mem_rsp_vld_i),
        .mem_data_i(mem_data_i),
        .mem_we_o(mem_we_o)
    );

endmodule
