`include "defines.v"

// 扩展指令IF(Integrated&Fire)
// opcode=0101111, funct3=010
// imm!=0时：x[rd] = x[rs1] + sign_ext(imm)，执行积分累加
// imm==0且x[rs1]>=x31时：通过UART发送x[rs1][7:0]，x[rd]=0
// imm==0且x[rs1]<x31时：x[rd]=x[rs1]，直通
module ext_intfire_xyh(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire start_i,                      // 启动信号(来自exu_extension)
    input wire [31:0] rs1_data_i,            // rs1寄存器数据
    input wire [31:0] x31_data_i,            // x31寄存器数据(阈值)
    input wire [31:0] imm_i,                 // 立即数
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    input wire [31:0] mem_rdata_i,           // 访存读数据(未使用)

    output wire ready_o,                     // 运算完成
    output wire bus_req_o,                   // 总线请求
    output wire bus_valid_o,                 // 总线请求有效
    output wire bus_we_o,                    // 总线写使能
    output wire [31:0] bus_addr_o,           // 总线地址(UART寄存器)
    output wire [31:0] bus_wdata_o,          // 总线写数据
    output wire [3:0] bus_sel_o,             // 总线字节选择

    output wire [31:0] reg_wdata_o,          // 写回数据(结果)
    output wire reg_we_o,                    // 写回使能
    output wire stall_o                      // 暂停(运行期间保持)

    );

    localparam ST_IDLE      = 2'd0;
    localparam ST_LOCAL     = 2'd1;
    localparam ST_UART_CFG  = 2'd2;
    localparam ST_UART_SEND = 2'd3;

    reg [1:0] state;
    reg running_r;
    reg ready_r;
    reg [31:0] result_r;
    reg [7:0] uart_byte_r;
    reg done_hold_r;
    reg req_issued_r;

    wire imm_is_zero = (imm_i == 32'h0);
    wire need_uart_send = imm_is_zero & (rs1_data_i >= x31_data_i);
    wire start_fire = start_i & (~running_r) & (~done_hold_r);
    wire bus_req_hsked = bus_valid_o & mem_req_ready_i;
    wire bus_rsp_hsked = req_issued_r & mem_rsp_valid_i;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            running_r <= 1'b0;
            ready_r <= 1'b0;
            result_r <= 32'h0;
            uart_byte_r <= 8'h0;
            done_hold_r <= 1'b0;
            req_issued_r <= 1'b0;
        end else begin
            ready_r <= 1'b0;
            if (!start_i) begin
                done_hold_r <= 1'b0;
            end

            if (start_fire) begin
                running_r <= 1'b1;
                uart_byte_r <= rs1_data_i[7:0];
                req_issued_r <= 1'b0;

                if (!imm_is_zero) begin
                    result_r <= rs1_data_i + imm_i;
                    state <= ST_LOCAL;
                end else if (need_uart_send) begin
                    result_r <= 32'h0;
                    state <= ST_UART_CFG;
                end else begin
                    result_r <= rs1_data_i;
                    state <= ST_LOCAL;
                end
            end else begin
                case (state)
                    ST_IDLE: begin
                        req_issued_r <= 1'b0;
                    end

                    ST_LOCAL: begin
                        ready_r <= 1'b1;
                        running_r <= 1'b0;
                        state <= ST_IDLE;
                        done_hold_r <= 1'b1;
                        req_issued_r <= 1'b0;
                    end

                    ST_UART_CFG: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            state <= ST_UART_SEND;
                            req_issued_r <= 1'b0;
                        end
                    end

                    ST_UART_SEND: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            ready_r <= 1'b1;
                            running_r <= 1'b0;
                            state <= ST_IDLE;
                            done_hold_r <= 1'b1;
                            req_issued_r <= 1'b0;
                        end
                    end

                    default: begin
                        state <= ST_IDLE;
                        running_r <= 1'b0;
                        req_issued_r <= 1'b0;
                    end
                endcase
            end
        end
    end

    assign ready_o = ready_r;
    assign bus_req_o = running_r & ((state == ST_UART_CFG) | (state == ST_UART_SEND));
    assign bus_valid_o = bus_req_o;
    assign bus_we_o = bus_req_o;
    assign bus_addr_o = (state == ST_UART_CFG) ? `UART_CTRL_REG : `UART_TX_REG;
    assign bus_wdata_o = (state == ST_UART_CFG) ? 32'h0000_0001 : {14'h0, 1'b1, 1'b0, 8'h0, uart_byte_r};
    assign bus_sel_o = 4'b0001;

    assign reg_wdata_o = result_r;
    assign reg_we_o = ready_r;
    assign stall_o = running_r | start_fire;

endmodule
