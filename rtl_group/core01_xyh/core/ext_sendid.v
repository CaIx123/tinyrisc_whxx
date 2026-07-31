`timescale 1ns / 1ps

`include "defines_xyh.v"

// 扩展指令sID：通过UART发出学号的ASCII串
// opcode=0101111, funct3=000
// 状态机：先配置UART控制寄存器，再依次发送10个ASCII字节
// 学号内容固定为"2025210879"，不写回寄存器
module ext_sendid_xyh #(
    parameter integer STUDENT_ID = 2025210879,
    parameter [79:0] STUDENT_ID_ASCII = 80'h32303235323130383739
)(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire start_i,                      // 启动信号(来自exu_extension)
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    input wire[31:0] mem_rdata_i,            // 访存读数据(未使用)

    output wire ready_o,                     // 发送完成
    output wire bus_req_o,                   // 总线请求
    output wire bus_valid_o,                 // 总线请求有效
    output wire bus_we_o,                    // 总线写使能
    output wire[31:0] bus_addr_o,            // 总线地址(UART寄存器)
    output wire[31:0] bus_wdata_o,           // 总线写数据(ASCII字节)
    output wire[3:0] bus_sel_o,              // 总线字节选择

    // 没用上
    output wire[31:0] reg_wdata_o,           // 写回数据(学号后10位)
    output wire reg_we_o,                    // 写回使能(恒为0，不写回)
    output wire stall_o                      // 暂停(运行期间保持)

    );

    localparam ST_IDLE = 2'd0;
    localparam ST_CFG  = 2'd1;
    localparam ST_SEND = 2'd2;

    reg [1:0] state;
    reg running_r;
    reg ready_r;
    reg [3:0] byte_idx_r;
    reg req_issued_r;
    reg done_hold_r;

    wire bus_req_hsked = bus_valid_o & mem_req_ready_i;
    wire bus_rsp_hsked = req_issued_r & mem_rsp_valid_i;
    wire start_fire = start_i & (~running_r) & (~done_hold_r);

    reg [7:0] curr_ascii;
    wire last_byte = (byte_idx_r == 4'd9);

    always @ (*) begin
        case (byte_idx_r)
            4'd0: curr_ascii = STUDENT_ID_ASCII[79:72];
            4'd1: curr_ascii = STUDENT_ID_ASCII[71:64];
            4'd2: curr_ascii = STUDENT_ID_ASCII[63:56];
            4'd3: curr_ascii = STUDENT_ID_ASCII[55:48];
            4'd4: curr_ascii = STUDENT_ID_ASCII[47:40];
            4'd5: curr_ascii = STUDENT_ID_ASCII[39:32];
            4'd6: curr_ascii = STUDENT_ID_ASCII[31:24];
            4'd7: curr_ascii = STUDENT_ID_ASCII[23:16];
            4'd8: curr_ascii = STUDENT_ID_ASCII[15:8];
            4'd9: curr_ascii = STUDENT_ID_ASCII[7:0];
            default: curr_ascii = 8'h30;
        endcase
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            running_r <= 1'b0;
            ready_r <= 1'b0;
            byte_idx_r <= 4'h0;
            req_issued_r <= 1'b0;
            done_hold_r <= 1'b0;
        end else begin
            ready_r <= 1'b0;
            if (!start_i) begin
                done_hold_r <= 1'b0;
            end

            if (start_fire) begin
                state <= ST_CFG;
                running_r <= 1'b1;
                byte_idx_r <= 4'h0;
                req_issued_r <= 1'b0;
            end else begin
                case (state)
                    ST_IDLE: begin
                        req_issued_r <= 1'b0;
                    end

                    ST_CFG: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            state <= ST_SEND;
                            req_issued_r <= 1'b0;
                        end
                    end

                    ST_SEND: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            req_issued_r <= 1'b0;
                            if (last_byte) begin
                                state <= ST_IDLE;
                                running_r <= 1'b0;
                                ready_r <= 1'b1;
                                done_hold_r <= 1'b1;
                            end else begin
                                byte_idx_r <= byte_idx_r + 4'h1;
                            end
                        end
                    end

                    default: begin
                        state <= ST_IDLE;
                        running_r <= 1'b0;
                    end
                endcase
            end
        end
    end

    assign ready_o = ready_r;
    assign bus_req_o = running_r;
    assign bus_valid_o = running_r;
    assign bus_we_o = (state == ST_CFG) | (state == ST_SEND);
    assign bus_addr_o = (state == ST_CFG) ? `UART_CTRL_REG : `UART_TX_REG;
    assign bus_wdata_o = (state == ST_CFG) ? 32'h0000_0001 : {14'h0, 1'b1, 1'b0, 8'h0, curr_ascii};
    assign bus_sel_o = 4'b0001;

    assign reg_wdata_o = {22'h0, STUDENT_ID[9:0]};
    assign reg_we_o = 1'b0;
    assign stall_o = running_r | start_fire;

endmodule
