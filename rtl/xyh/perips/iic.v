`include "../core/defines.v"
`include "../tiny_macro.v"

// IIC(I2C)主机外设模块
// 寄存器映射：0x7001_0000 从机地址 / 0x7002_0000 发送数据 / 0x7003_0000 接收数据
// data_i[17]：0=立即响应，1=传输完成后响应
// data_i[16]：0=1字节传输，1=2字节传输
// 支持标准的I2C START -> 7bit地址+R/W -> ACK -> 数据字节 -> ACK -> STOP时序
module iic(

    input wire clk,                          // 时钟
    input wire rst_n,                        // 复位(低有效)
    input wire[31:0] addr_i,                 // 寄存器地址
    input wire[31:0] data_i,                 // 写数据
    input wire[3:0] sel_i,                   // 字节选择
    input wire we_i,                         // 写使能
    output wire[31:0] data_o,                // 读数据

    input wire req_valid_i,                  // 请求有效
    output wire req_ready_o,                 // 请求就绪
    output wire rsp_valid_o,                 // 响应有效
    input wire rsp_ready_i,                  // 响应就绪

    input wire iic_scl_i,                    // IIC SCL输入
    input wire iic_sda_i,                    // IIC SDA输入
    output wire iic_scl_oe_o,                // IIC SCL输出使能(开漏)
    output wire iic_sda_oe_o                 // IIC SDA输出使能(开漏)

    );

    localparam REG_ADDR = 28'h0010000;
    localparam REG_TX   = 28'h0020000;
    localparam REG_RX   = 28'h0030000;

    localparam IIC_DIV = `IIC_CLK_DIV;

    localparam S_IDLE       = 4'd0;
    localparam S_START      = 4'd1;
    localparam S_ADDR_LOW   = 4'd2;
    localparam S_ADDR_HIGH  = 4'd3;
    localparam S_ADDR_ACK_L = 4'd4;
    localparam S_ADDR_ACK_H = 4'd5;
    localparam S_DATA_LOW   = 4'd6;
    localparam S_DATA_HIGH  = 4'd7;
    localparam S_DATA_ACK_L = 4'd8;
    localparam S_DATA_ACK_H = 4'd9;
    localparam S_STOP_LOW   = 4'd10;
    localparam S_STOP_HIGH  = 4'd11;

    reg[7:0] slave_addr;
    reg[15:0] tx_data;
    reg[15:0] rx_data;
    reg[7:0] rx_shift;
    reg[7:0] addr_byte;
    reg[3:0] state;
    reg[15:0] clk_cnt;
    reg[2:0] bit_cnt;
    reg read_mode;
    reg busy;
    reg scl_oe;
    reg sda_oe;
    reg ack_addr;
    reg ack_data;
    reg two_bytes;
    reg byte_index;
    reg[27:0] active_reg_addr;
    reg[31:0] data_r;
    reg rsp_valid_r;
    reg wait_rsp_mode_r;

    wire[27:0] reg_addr = addr_i[27:0];
    wire tick = (clk_cnt == IIC_DIV);
    wire sda_in = iic_sda_i;
    wire[7:0] tx_byte = (two_bytes && (byte_index == 1'b0)) ? tx_data[15:8] : tx_data[7:0];
    wire final_byte = (~two_bytes) || (byte_index == 1'b1);

    wire is_data_cmd = we_i & ((reg_addr == REG_TX) | (reg_addr == REG_RX));
    wire need_wait_rsp = is_data_cmd & data_i[17];
    wire accept_common = rst_n & (~busy) & (~rsp_valid_r);
    wire req_fire = req_valid_i & req_ready_o;
    wire wen = req_fire & we_i;
    wire ren = req_fire & (~we_i);

    assign iic_scl_oe_o = scl_oe;
    assign iic_sda_oe_o = sda_oe;
    assign data_o = data_r;

    assign req_ready_o = accept_common;
    assign rsp_valid_o = rsp_valid_r;

    function [31:0] format_reg_data;
        input [27:0] reg_sel;
        begin
            case (reg_sel)
                REG_ADDR: format_reg_data = {busy, ack_addr, ack_data, 21'h0, slave_addr};
                REG_TX:   format_reg_data = {14'h0, wait_rsp_mode_r, two_bytes, tx_data};
                REG_RX:   format_reg_data = {14'h0, wait_rsp_mode_r, two_bytes, rx_data};
                default:  format_reg_data = 32'h0;
            endcase
        end
    endfunction

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 16'h0;
        end else if (busy) begin
            if (tick) begin
                clk_cnt <= 16'h0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= 16'h0;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_addr <= 8'h0;
            tx_data <= 16'h0;
            rx_data <= 16'h0;
            rx_shift <= 8'h0;
            addr_byte <= 8'h0;
            state <= S_IDLE;
            bit_cnt <= 3'h7;
            read_mode <= 1'b0;
            busy <= 1'b0;
            scl_oe <= 1'b0;
            sda_oe <= 1'b0;
            ack_addr <= 1'b1;
            ack_data <= 1'b1;
            two_bytes <= 1'b0;
            byte_index <= 1'b0;
            active_reg_addr <= 28'h0;
            data_r <= 32'h0;
            rsp_valid_r <= 1'b0;
            wait_rsp_mode_r <= 1'b0;
        end else begin
            if (rsp_valid_r & rsp_ready_i) begin
                rsp_valid_r <= 1'b0;
            end

            if (wen & (reg_addr == REG_ADDR)) begin
                if (sel_i[0]) begin
                    slave_addr <= data_i[7:0];
                end
                data_r <= {busy, ack_addr, ack_data, 21'h0, data_i[7:0]};
                rsp_valid_r <= 1'b1;
            end else if (ren) begin
                data_r <= format_reg_data(reg_addr);
                rsp_valid_r <= 1'b1;
            end else if (wen & ((reg_addr == REG_TX) | (reg_addr == REG_RX))) begin
                active_reg_addr <= reg_addr;
                wait_rsp_mode_r <= data_i[17];
                two_bytes <= data_i[16];
                byte_index <= 1'b0;
                bit_cnt <= 3'h7;
                addr_byte <= {slave_addr[6:0], reg_addr == REG_RX};
                read_mode <= (reg_addr == REG_RX);
                busy <= 1'b1;
                state <= S_START;
                scl_oe <= 1'b0;
                sda_oe <= 1'b0;
                ack_addr <= 1'b1;
                ack_data <= 1'b1;
                if (reg_addr == REG_TX) begin
                    tx_data <= data_i[15:0];
                end else begin
                    rx_data <= 16'h0;
                    rx_shift <= 8'h0;
                end
                if (!data_i[17]) begin
                    data_r <= {14'h0, data_i[17], data_i[16], data_i[15:0]};
                    rsp_valid_r <= 1'b1;
                end
            end else if (tick) begin
                case (state)
                    S_IDLE: begin
                        busy <= 1'b0;
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b0;
                    end
                    S_START: begin
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b1;
                        state <= S_ADDR_LOW;
                    end
                    S_ADDR_LOW: begin
                        scl_oe <= 1'b1;
                        sda_oe <= ~addr_byte[bit_cnt];
                        state <= S_ADDR_HIGH;
                    end
                    S_ADDR_HIGH: begin
                        scl_oe <= 1'b0;
                        if (bit_cnt == 3'h0) begin
                            bit_cnt <= 3'h7;
                            state <= S_ADDR_ACK_L;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state <= S_ADDR_LOW;
                        end
                    end
                    S_ADDR_ACK_L: begin
                        scl_oe <= 1'b1;
                        sda_oe <= 1'b0;
                        state <= S_ADDR_ACK_H;
                    end
                    S_ADDR_ACK_H: begin
                        scl_oe <= 1'b0;
                        ack_addr <= sda_in;
                        state <= S_DATA_LOW;
                    end
                    S_DATA_LOW: begin
                        scl_oe <= 1'b1;
                        if (read_mode) begin
                            sda_oe <= 1'b0;
                        end else begin
                            sda_oe <= ~tx_byte[bit_cnt];
                        end
                        state <= S_DATA_HIGH;
                    end
                    S_DATA_HIGH: begin
                        scl_oe <= 1'b0;
                        if (read_mode) begin
                            rx_shift[bit_cnt] <= sda_in;
                        end
                        if (bit_cnt == 3'h0) begin
                            bit_cnt <= 3'h7;
                            state <= S_DATA_ACK_L;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state <= S_DATA_LOW;
                        end
                    end
                    S_DATA_ACK_L: begin
                        scl_oe <= 1'b1;
                        if (read_mode) begin
                            sda_oe <= ~final_byte;
                        end else begin
                            sda_oe <= 1'b0;
                        end
                        state <= S_DATA_ACK_H;
                    end
                    S_DATA_ACK_H: begin
                        scl_oe <= 1'b0;
                        if (read_mode) begin
                            if (two_bytes && (byte_index == 1'b0)) begin
                                rx_data[15:8] <= rx_shift;
                            end else begin
                                rx_data[7:0] <= rx_shift;
                            end
                            if (!final_byte) begin
                                byte_index <= 1'b1;
                                rx_shift <= 8'h0;
                                state <= S_DATA_LOW;
                            end else begin
                                state <= S_STOP_LOW;
                            end
                        end else begin
                            ack_data <= sda_in;
                            if (!final_byte) begin
                                byte_index <= 1'b1;
                                state <= S_DATA_LOW;
                            end else begin
                                state <= S_STOP_LOW;
                            end
                        end
                    end
                    S_STOP_LOW: begin
                        scl_oe <= 1'b1;
                        sda_oe <= 1'b1;
                        state <= S_STOP_HIGH;
                    end
                    S_STOP_HIGH: begin
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b0;
                        busy <= 1'b0;
                        state <= S_IDLE;
                        if (wait_rsp_mode_r) begin
                            data_r <= format_reg_data(active_reg_addr);
                            rsp_valid_r <= 1'b1;
                        end
                        wait_rsp_mode_r <= 1'b0;
                    end
                    default: begin
                        state <= S_IDLE;
                        busy <= 1'b0;
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b0;
                        wait_rsp_mode_r <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
