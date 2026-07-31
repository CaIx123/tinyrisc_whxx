`timescale 1ns / 1ps

`include "defines_hjx.v"

module exu_ext_rt_hjx(

    input wire clk,
    input wire rst_n,

    input wire req_rt_i,
    input wire mem_req_ready_i,
    input wire mem_rsp_valid_i,
    input wire[31:0] mem_rdata_i,

    output wire rt_stall_o,
    output reg[31:0] rt_mem_addr_o,
    output reg[31:0] rt_mem_wdata_o,
    output reg rt_mem_we_o,
    output wire[3:0] rt_mem_sel_o,
    output wire rt_mem_req_valid_o,
    output wire rt_mem_rsp_ready_o,

    output wire[31:0] rt_reg_wdata_o,
    output wire rt_reg_we_o

    );

    localparam IIC_CTRL_ADDR       = 32'h7000_0000;
    localparam IIC_SLAVE_ADDR      = 32'h7001_0000;
    localparam IIC_INPUT_ADDR      = 32'h7003_0000;
    localparam IIC_STATUS_ADDR     = 32'h7004_0000;

    localparam LM75_SLAVE_ADDR     = 32'h0000_0048;
    localparam IIC_START_READ2     = 32'h0000_0003;

    localparam S_IDLE       = 4'd0;
    localparam S_ADDR_REQ   = 4'd1;
    localparam S_ADDR_RSP   = 4'd2;
    localparam S_START_REQ  = 4'd3;
    localparam S_START_RSP  = 4'd4;
    localparam S_STATUS_REQ = 4'd5;
    localparam S_STATUS_RSP = 4'd6;
    localparam S_INPUT_REQ  = 4'd7;
    localparam S_INPUT_RSP  = 4'd8;

    reg[3:0] state;
    reg done_seen;
    reg[31:0] temp_data;
    reg input_done_r;

    wire active = req_rt_i & (~done_seen);
    wire req_hsked = rt_mem_req_valid_o & mem_req_ready_i;
    wire rsp_hsked = rt_mem_rsp_ready_o & mem_rsp_valid_i;
    wire iic_done = mem_rdata_i[1];

    assign rt_mem_sel_o = 4'hf;
    assign rt_mem_rsp_ready_o = 1'b1;
    assign rt_mem_req_valid_o = (state == S_ADDR_REQ) |
                                (state == S_START_REQ) |
                                (state == S_STATUS_REQ) |
                                (state == S_INPUT_REQ);
    assign rt_stall_o = active;
    assign rt_reg_wdata_o = {24'h0, temp_data[14:7]};
    assign rt_reg_we_o = req_rt_i & input_done_r;

    always @(*) begin
        rt_mem_addr_o = 32'h0;
        rt_mem_wdata_o = 32'h0;
        rt_mem_we_o = 1'b0;

        case (state)
            S_ADDR_REQ: begin
                rt_mem_addr_o = IIC_SLAVE_ADDR;
                rt_mem_wdata_o = LM75_SLAVE_ADDR;
                rt_mem_we_o = 1'b1;
            end
            S_START_REQ: begin
                rt_mem_addr_o = IIC_CTRL_ADDR;
                rt_mem_wdata_o = IIC_START_READ2;
                rt_mem_we_o = 1'b1;
            end
            S_STATUS_REQ: begin
                rt_mem_addr_o = IIC_STATUS_ADDR;
            end
            S_INPUT_REQ: begin
                rt_mem_addr_o = IIC_INPUT_ADDR;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done_seen <= 1'b0;
            temp_data <= 32'h0;
            input_done_r <= 1'b0;
        end else begin
            input_done_r <= 1'b0;

            if (!req_rt_i) begin
                done_seen <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (active) begin
                        state <= S_ADDR_REQ;
                    end
                end
                S_ADDR_REQ: begin
                    if (req_hsked) begin
                        state <= S_ADDR_RSP;
                    end
                end
                S_ADDR_RSP: begin
                    if (rsp_hsked) begin
                        state <= S_START_REQ;
                    end
                end
                S_START_REQ: begin
                    if (req_hsked) begin
                        state <= S_START_RSP;
                    end
                end
                S_START_RSP: begin
                    if (rsp_hsked) begin
                        state <= S_STATUS_REQ;
                    end
                end
                S_STATUS_REQ: begin
                    if (req_hsked) begin
                        state <= S_STATUS_RSP;
                    end
                end
                S_STATUS_RSP: begin
                    if (rsp_hsked) begin
                        if (iic_done) begin
                            state <= S_INPUT_REQ;
                        end else begin
                            state <= S_STATUS_REQ;
                        end
                    end
                end
                S_INPUT_REQ: begin
                    if (req_hsked) begin
                        state <= S_INPUT_RSP;
                    end
                end
                S_INPUT_RSP: begin
                    if (rsp_hsked) begin
                        temp_data <= mem_rdata_i;
                        done_seen <= 1'b1;
                        input_done_r <= 1'b1;
                        state <= S_IDLE;
                    end
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
