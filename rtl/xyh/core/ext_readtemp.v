`include "defines.v"
`include "../tiny_macro.v"

// 扩展指令rT：通过IIC读取LM75温度传感器
// opcode=0101111, funct3=001
// 状态机流程：写IIC地址寄存器 -> 写温度寄存器指针0x00 -> 发起2字节读 -> 读回数据
// 取temp_data[14:7]写回寄存器，即8bit温度原始值，每位代表0.5 ℃
module ext_readtemp(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)

    input wire start_i,                      // 启动信号(来自exu_extension)
    input wire mem_req_ready_i,              // 访存请求就绪
    input wire mem_rsp_valid_i,              // 访存响应有效
    input wire[31:0] mem_rdata_i,            // IIC读回数据

    output wire ready_o,                     // 读取完成
    output wire bus_req_o,                   // 总线请求
    output wire bus_valid_o,                 // 总线请求有效
    output wire bus_we_o,                    // 总线写使能
    output wire[31:0] bus_addr_o,            // 总线地址(IIC寄存器)
    output wire[31:0] bus_wdata_o,           // 总线写数据
    output wire[3:0] bus_sel_o,              // 总线字节选择

    output wire[31:0] reg_wdata_o,           // 写回数据(temp_data[14:7])
    output wire reg_we_o,                    // 写回使能
    output wire stall_o                      // 暂停(运行期间保持)

    );

    localparam ST_IDLE       = 3'd0;
    localparam ST_WR_ADDR    = 3'd1;
    localparam ST_WR_PTR     = 3'd2;
    localparam ST_CMD_READ   = 3'd3;
    localparam ST_RD_DATA    = 3'd4;

    reg[2:0] state;
    reg running_r;
    reg ready_r;
    reg[15:0] temp_data_r;
    reg req_issued_r;
    reg done_hold_r;

    wire bus_req_hsked = bus_valid_o & mem_req_ready_i;
    wire bus_rsp_hsked = mem_rsp_valid_i & req_issued_r;// (req_issued_r | bus_req_hsked);
    wire start_fire = start_i & (~running_r) & (~done_hold_r);// & (~mem_stall_i);

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            running_r <= 1'b0;
            ready_r <= 1'b0;
            temp_data_r <= 16'h0;
            req_issued_r <= 1'b0;
            done_hold_r <= 1'b0;
        end else begin
            ready_r <= 1'b0;
            if (!start_i) begin
                done_hold_r <= 1'b0;
            end

            if (start_fire) begin
                running_r <= 1'b1;
                state <= ST_WR_ADDR;
                req_issued_r <= 1'b0;
            end else begin
                case (state)
                    ST_IDLE: begin
                        req_issued_r <= 1'b0;
                    end

                    ST_WR_ADDR: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            state <= ST_WR_PTR;
                            req_issued_r <= 1'b0;
                        end
                    end

                    ST_WR_PTR: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            state <= ST_CMD_READ;
                            req_issued_r <= 1'b0;
                        end
                    end

                    ST_CMD_READ: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            state <= ST_RD_DATA;
                            req_issued_r <= 1'b0;
                        end
                    end

                    ST_RD_DATA: begin
                        if (bus_req_hsked) begin
                            req_issued_r <= 1'b1;
                        end
                        if (bus_rsp_hsked) begin
                            temp_data_r <= mem_rdata_i[15:0];
                            running_r <= 1'b0;
                            ready_r <= 1'b1;
                            state <= ST_IDLE;
                            req_issued_r <= 1'b0;
                            done_hold_r <= 1'b1;
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

    assign bus_req_o = running_r;
    assign bus_valid_o = running_r;

    assign bus_addr_o =
        (state == ST_WR_ADDR)  ? `IIC_ADDR_REG :
        (state == ST_WR_PTR)   ? `IIC_TX_REG   :
        (state == ST_CMD_READ) ? `IIC_RX_REG   :
        (state == ST_RD_DATA)  ? `IIC_RX_REG   :
                                 32'h0;

    assign bus_wdata_o =
        (state == ST_WR_ADDR)  ? {24'h0, 1'b0, `LM75_I2C_ADDR} :
        (state == ST_WR_PTR)   ? 32'h0000_0000 :
        (state == ST_CMD_READ) ? 32'h0003_0000 :
                                 32'h0;

    assign bus_sel_o =
        (state == ST_WR_ADDR)  ? 4'b0001 :
        (state == ST_WR_PTR)   ? 4'b0111 :
        (state == ST_CMD_READ) ? 4'b0111 :
        (state == ST_RD_DATA)  ? 4'b1111 :
                                 4'b0000;

    assign bus_we_o = (state == ST_WR_ADDR) | (state == ST_WR_PTR) | (state == ST_CMD_READ);

    assign ready_o = ready_r;
    assign reg_wdata_o = {24'h0, temp_data_r[14:7]};
    assign reg_we_o = ready_r;
    assign stall_o = running_r | start_fire;

endmodule
