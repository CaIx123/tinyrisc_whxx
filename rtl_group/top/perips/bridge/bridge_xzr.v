`timescale 1ns / 1ps

`include "../../macros.v"

module bridge_xzr(
    input wire clk,
    input wire rst_n,

    input wire s0_req_vld_i,
    input wire s0_rsp_rdy_i,
    input wire s0_we_i,
    input wire [31:0] s0_addr_i,
    input wire [31:0] s0_data_i,
    input wire [3:0] s0_sel_i,
    output wire [31:0] s0_data_o,
    output wire s0_req_rdy_o,
    output wire s0_rsp_vld_o,

    input wire s1_req_vld_i,
    input wire s1_rsp_rdy_i,
    input wire s1_we_i,
    input wire [31:0] s1_addr_i,
    input wire [31:0] s1_data_i,
    input wire [3:0] s1_sel_i,
    output wire [31:0] s1_data_o,
    output wire s1_req_rdy_o,
    output wire s1_rsp_vld_o,

    output reg [7:0] tx_data_o,
    input wire [7:0] rx_data_i
);
    localparam ST_IDLE = 3'd0;
    localparam ST_CMD  = 3'd1;
    localparam ST_ADDR = 3'd2;
    localparam ST_D0   = 3'd3;
    localparam ST_D1   = 3'd4;
    localparam ST_D2   = 3'd5;
    localparam ST_D3   = 3'd6;
    localparam ST_RSP  = 3'd7;

    reg [2:0] state;
    reg owner_ram_r;
    reg we_r;
    reg [7:0] addr_r;
    reg [31:0] wdata_r;
    reg [31:0] rdata_r;

    wire accept_s1 = (state == ST_IDLE) & s1_req_vld_i;
    wire accept_s0 = (state == ST_IDLE) & ~s1_req_vld_i & s0_req_vld_i;
    wire rsp_ready = owner_ram_r ? s1_rsp_rdy_i : s0_rsp_rdy_i;

    assign s0_req_rdy_o = (state == ST_IDLE) & ~s1_req_vld_i;
    assign s1_req_rdy_o = (state == ST_IDLE);
    assign s0_rsp_vld_o = (state == ST_RSP) & ~owner_ram_r;
    assign s1_rsp_vld_o = (state == ST_RSP) & owner_ram_r;
    assign s0_data_o = ~owner_ram_r ? rdata_r : 32'b0;
    assign s1_data_o = owner_ram_r ? rdata_r : 32'b0;

    always @(*) begin
        case (state)
            ST_CMD:  tx_data_o = {1'b1, we_r, owner_ram_r, 5'b0};
            ST_ADDR: tx_data_o = addr_r;
            ST_D0:   tx_data_o = we_r ? wdata_r[7:0]   : 8'b0;
            ST_D1:   tx_data_o = we_r ? wdata_r[15:8]  : 8'b0;
            ST_D2:   tx_data_o = we_r ? wdata_r[23:16] : 8'b0;
            ST_D3:   tx_data_o = we_r ? wdata_r[31:24] : 8'b0;
            default: tx_data_o = 8'b0;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            owner_ram_r <= 1'b0;
            we_r <= 1'b0;
            addr_r <= 8'b0;
            wdata_r <= 32'b0;
            rdata_r <= 32'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (accept_s1 | accept_s0) begin
                        owner_ram_r <= accept_s1;
                        we_r <= accept_s1 ? s1_we_i : s0_we_i;
                        addr_r <= accept_s1 ? s1_addr_i[9:2] : s0_addr_i[9:2];
                        wdata_r <= accept_s1 ? s1_data_i : s0_data_i;
                        rdata_r <= 32'b0;
                        state <= ST_CMD;
                    end
                end
                ST_CMD:  state <= ST_ADDR;
                ST_ADDR: state <= ST_D0;
                ST_D0: begin
                    if (!we_r) rdata_r[7:0] <= rx_data_i;
                    state <= ST_D1;
                end
                ST_D1: begin
                    if (!we_r) rdata_r[15:8] <= rx_data_i;
                    state <= ST_D2;
                end
                ST_D2: begin
                    if (!we_r) rdata_r[23:16] <= rx_data_i;
                    state <= ST_D3;
                end
                ST_D3: begin
                    if (!we_r) rdata_r[31:24] <= rx_data_i;
                    state <= ST_RSP;
                end
                ST_RSP: begin
                    if (rsp_ready) state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

    wire unused_sel = ^{s0_sel_i, s1_sel_i};
endmodule
