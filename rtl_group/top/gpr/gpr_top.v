`timescale 1ns / 1ps

`include "../macros.v"

module gpr_top (
    input wire clk,
    input wire rst_n,
    input wire [1:0] chip_sel_i,

    input wire wzc_we_i,
    input wire [`GPR_ADDR_WIDTH-1:0] wzc_waddr_i,
    input wire [`DATA_WIDTH-1:0] wzc_wdata_i,
    input wire [`GPR_ADDR_WIDTH-1:0] wzc_raddr1_i,
    input wire [`GPR_ADDR_WIDTH-1:0] wzc_raddr2_i,
    output wire [`DATA_WIDTH-1:0] wzc_rdata1_o,
    output wire [`DATA_WIDTH-1:0] wzc_rdata2_o,

    input wire xyh_we_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xyh_waddr_i,
    input wire [`DATA_WIDTH-1:0] xyh_wdata_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xyh_raddr1_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xyh_raddr2_i,
    output wire [`DATA_WIDTH-1:0] xyh_rdata1_o,
    output wire [`DATA_WIDTH-1:0] xyh_rdata2_o,

    input wire hjx_we_i,
    input wire [`GPR_ADDR_WIDTH-1:0] hjx_waddr_i,
    input wire [`DATA_WIDTH-1:0] hjx_wdata_i,
    input wire [`GPR_ADDR_WIDTH-1:0] hjx_raddr1_i,
    input wire [`GPR_ADDR_WIDTH-1:0] hjx_raddr2_i,
    output wire [`DATA_WIDTH-1:0] hjx_rdata1_o,
    output wire [`DATA_WIDTH-1:0] hjx_rdata2_o,

    input wire xzr_we_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xzr_waddr_i,
    input wire [`DATA_WIDTH-1:0] xzr_wdata_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xzr_raddr1_i,
    input wire [`GPR_ADDR_WIDTH-1:0] xzr_raddr2_i,
    output wire [`DATA_WIDTH-1:0] xzr_rdata1_o,
    output wire [`DATA_WIDTH-1:0] xzr_rdata2_o,
    output wire [`DATA_WIDTH-1:0] x27_o
);

    wire chip_wzc = chip_sel_i == 2'b00;
    wire chip_xyh = chip_sel_i == 2'b01;
    wire chip_hjx = chip_sel_i == 2'b10;
    wire chip_xzr = chip_sel_i == 2'b11;

    /*
     * Request MUX: only the selected core can drive the shared GPR.
     * This includes both asynchronous read addresses and the write port.
     */
    wire gpr_we = chip_wzc ? wzc_we_i :
                  chip_xyh ? xyh_we_i :
                  chip_hjx ? hjx_we_i :
                             xzr_we_i;

    wire [`GPR_ADDR_WIDTH-1:0] gpr_waddr =
                  chip_wzc ? wzc_waddr_i :
                  chip_xyh ? xyh_waddr_i :
                  chip_hjx ? hjx_waddr_i :
                             xzr_waddr_i;

    wire [`DATA_WIDTH-1:0] gpr_wdata =
                  chip_wzc ? wzc_wdata_i :
                  chip_xyh ? xyh_wdata_i :
                  chip_hjx ? hjx_wdata_i :
                             xzr_wdata_i;

    wire [`GPR_ADDR_WIDTH-1:0] gpr_raddr1 =
                  chip_wzc ? wzc_raddr1_i :
                  chip_xyh ? xyh_raddr1_i :
                  chip_hjx ? hjx_raddr1_i :
                             xzr_raddr1_i;

    wire [`GPR_ADDR_WIDTH-1:0] gpr_raddr2 =
                  chip_wzc ? wzc_raddr2_i :
                  chip_xyh ? xyh_raddr2_i :
                  chip_hjx ? hjx_raddr2_i :
                             xzr_raddr2_i;

    wire [`DATA_WIDTH-1:0] gpr_rdata1;
    wire [`DATA_WIDTH-1:0] gpr_rdata2;

    gpr u_gpr (
        .clk(clk),
        .rst_n(rst_n),
        .we_i(gpr_we),
        .waddr_i(gpr_waddr),
        .wdata_i(gpr_wdata),
        .raddr1_i(gpr_raddr1),
        .rdata1_o(gpr_rdata1),
        .raddr2_i(gpr_raddr2),
        .rdata2_o(gpr_rdata2)
    );

    /*
     * Response DEMUX: the selected core receives the two read results.
     * Every inactive core sees zero, avoiding propagation and switching of
     * shared-GPR read data into inactive core logic.
     */
    assign wzc_rdata1_o = chip_wzc ? gpr_rdata1 : {`DATA_WIDTH{1'b0}};
    assign wzc_rdata2_o = chip_wzc ? gpr_rdata2 : {`DATA_WIDTH{1'b0}};
    assign xyh_rdata1_o = chip_xyh ? gpr_rdata1 : {`DATA_WIDTH{1'b0}};
    assign xyh_rdata2_o = chip_xyh ? gpr_rdata2 : {`DATA_WIDTH{1'b0}};
    assign hjx_rdata1_o = chip_hjx ? gpr_rdata1 : {`DATA_WIDTH{1'b0}};
    assign hjx_rdata2_o = chip_hjx ? gpr_rdata2 : {`DATA_WIDTH{1'b0}};
    assign xzr_rdata1_o = chip_xzr ? gpr_rdata1 : {`DATA_WIDTH{1'b0}};
    assign xzr_rdata2_o = chip_xzr ? gpr_rdata2 : {`DATA_WIDTH{1'b0}};

    assign x27_o = u_gpr.regs[27];

endmodule
