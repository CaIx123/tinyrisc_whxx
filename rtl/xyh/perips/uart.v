`include "../core/defines.v"
`include "../tiny_macro.v"

// UART串口收发模块(默认: 115200, 8N1)
// MMIO寄存器映射：0x0 CTRL(控制/使能) / 0x4 STATUS(状态) / 0x8 BAUD(分频) / 0xC TXDATA(发送) / 0x10 RXDATA(接收)
// TX部分为状态机(S_IDLE/S_START/S_SEND_BYTE/S_STOP)，支持立即响应和发送完成后响应两种模式
// RX部分通过对rx_pin采样、检测起始位、按波特率中点采样恢复8bit数据
// 支持data_i[17]=1的延迟响应模式，用于确认发送完成的场景
module uart(

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

	output wire tx_pin,                      // UART发送引脚
    input wire rx_pin                        // UART接收引脚

    );

    // 波特率115200bps
    localparam BAUD_115200 = `UART_BAUD_115200;

    localparam S_IDLE       = 4'b0001;
    localparam S_START      = 4'b0010;
    localparam S_SEND_BYTE  = 4'b0100;
    localparam S_STOP       = 4'b1000;


    reg[3:0] state;
    reg[3:0] next_state;
    reg[15:0] cycle_cnt;
    reg tx_bit;
    reg[3:0] bit_cnt;

    reg rx_q0;
    reg rx_q1;
    wire rx_negedge;
    reg rx_start;                      // RX使能
    reg[3:0] rx_clk_edge_cnt;          // clk沿的个数
    reg rx_clk_edge_level;             // clk沿电平
    reg rx_done;
    reg[15:0] rx_clk_cnt;
    reg[15:0] rx_div_cnt;
    reg[7:0] rx_data;
    reg rx_over;

    // 寄存器(偏移)地址
    localparam UART_CTRL    = 8'h0;
    localparam UART_STATUS  = 8'h4;
    localparam UART_BAUD    = 8'h8;
    localparam UART_TXDATA  = 8'hc;
    localparam UART_RXDATA  = 8'h10;

    // UART控制寄存器，可读可写
    // bit[0]: UART TX使能, 1: enable, 0: disable
    // bit[1]: UART RX使能, 1: enable, 0: disable
    reg[31:0] uart_ctrl;

    // UART状态寄存器
    // 只读，bit[0]: TX空闲状态标志, 1: busy, 0: idle
    // 可读可写，bit[1]: RX接收完成标志, 1: over, 0: receiving
    reg[31:0] uart_status;

    // UART波特率寄存器(分频系数)，可读可写
    reg[31:0] uart_baud;

    // UART发送数据寄存器，可读可写
    reg[31:0] uart_tx;

    // UART接收数据寄存器，只读
    reg[31:0] uart_rx;

    reg rsp_valid_r;
    reg delayed_active_r;
    reg delayed_wait_rsp_r;

    wire need_wait_rsp = we_i & (addr_i[7:0] == UART_TXDATA) & data_i[17];
    wire accept_common = rst_n & (~rsp_valid_r) & (~delayed_active_r);
    wire delayed_req_ready = sel_i[0] & uart_ctrl[0] & (~uart_status[0]);
    wire req_fire = req_valid_i & req_ready_o;
    wire wen = we_i & req_fire;
    wire ren = (~we_i) & req_fire;
    wire write_reg_ctrl_en = wen & (addr_i[7:0] == UART_CTRL);
    wire write_reg_status_en = wen & (addr_i[7:0] == UART_STATUS);
    wire write_reg_baud_en = wen & (addr_i[7:0] == UART_BAUD);
    wire write_reg_txdata_en = wen & (addr_i[7:0] == UART_TXDATA);
    wire tx_start = write_reg_txdata_en & sel_i[0] & uart_ctrl[0] & (~uart_status[0]);
    wire rx_recv_over = uart_ctrl[1] & rx_over;

    assign req_ready_o = accept_common & ((~need_wait_rsp) | delayed_req_ready);
    assign rsp_valid_o = rsp_valid_r;

    assign tx_pin = tx_bit;


    // 写uart_rxdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx <= 32'h0;
        end else begin
            // 接收完成时，保存接收到的数据
            if (rx_recv_over) begin
                uart_rx[7:0] <= rx_data;
            end
        end
    end

    // delayed response control for TXDATA writes when data_i[17] == 1
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid_r <= 1'b0;
            delayed_active_r <= 1'b0;
            delayed_wait_rsp_r <= 1'b0;
        end else begin
            if (rsp_valid_r & rsp_ready_i) begin
                rsp_valid_r <= 1'b0;
            end

            if (req_fire & (~need_wait_rsp)) begin
                rsp_valid_r <= 1'b1;
            end

            if (req_fire & need_wait_rsp) begin
                delayed_active_r <= 1'b1;
                delayed_wait_rsp_r <= 1'b1;
            end

            if ((state == S_STOP) & (cycle_cnt == uart_baud[15:0]) & delayed_active_r) begin
                delayed_active_r <= 1'b0;
                if (delayed_wait_rsp_r) begin
                    rsp_valid_r <= 1'b1;
                    delayed_wait_rsp_r <= 1'b0;
                end
            end
        end
    end

    // 写uart_txdata
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx <= 32'h0;
        end else begin
            // 开始发送时，保存要发送的数据
            if (tx_start) begin
                uart_tx[7:0] <= data_i[7:0];
            end
        end
    end

    // 写uart_status
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_status <= 32'h0;
        end else begin
            if (write_reg_status_en & sel_i[0]) begin
                // 写RX完成标志
                uart_status[1] <= data_i[1];
            end else begin
                // 开始发送数据时，置位TX忙标志
                if (tx_start) begin
                    uart_status[0] <= 1'b1;
                // 发送完成时，清TX忙标志
                end else if ((state == S_STOP) & (cycle_cnt == uart_baud[15:0])) begin
                    uart_status[0] <= 1'b0;
                // 接收完成，置位接收完成标志
                end
                if (rx_recv_over) begin
                    uart_status[1] <= 1'b1;
                end
            end
        end
    end

    // 写uart_ctrl
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_ctrl <= 32'h0;
        end else begin
            if (write_reg_ctrl_en & sel_i[0]) begin
                uart_ctrl[7:0] <= data_i[7:0];
            end
        end
    end

    // 写uart_baud
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_baud <= BAUD_115200;
        end else begin
            if (write_reg_baud_en) begin
                if (sel_i[0]) begin
                    uart_baud[7:0] <= data_i[7:0];
                end
                if (sel_i[1]) begin
                    uart_baud[15:8] <= data_i[15:8];
                end
            end
        end
    end

    reg[31:0] data_r;

    // ??????
    always @ (*) begin
        case (addr_i[7:0])
            UART_CTRL:   data_r = uart_ctrl;
            UART_STATUS: data_r = uart_status;
            UART_BAUD:   data_r = uart_baud;
            UART_RXDATA: data_r = uart_rx;
            default:     data_r = 32'h0;
        endcase
    end

    assign data_o = data_r;

    // *************************** TX发送 ****************************

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @ (*) begin
        case (state)
            S_IDLE: begin
                if (tx_start) begin
                    next_state = S_START;
                end else begin
                    next_state = S_IDLE;
                end
            end
            S_START: begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    next_state = S_SEND_BYTE;
                end else begin
                    next_state = S_START;
                end
            end
            S_SEND_BYTE: begin
                if ((cycle_cnt == uart_baud[15:0]) & (bit_cnt == 4'd7)) begin
                    next_state = S_STOP;
                end else begin
                    next_state = S_SEND_BYTE;
                end
            end
            S_STOP: begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = S_STOP;
                end
            end
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // cycle_cnt
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 16'h0;
        end else begin
            if (state == S_IDLE) begin
                cycle_cnt <= 16'h0;
            end else begin
                if (cycle_cnt == uart_baud[15:0]) begin
                    cycle_cnt <= 16'h0;
                end else begin
                    cycle_cnt <= cycle_cnt + 16'h1;
                end
            end
        end
    end

    // bit_cnt
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 4'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    bit_cnt <= 4'h0;
                end
                S_SEND_BYTE: begin
                    if (cycle_cnt == uart_baud[15:0]) begin
                        bit_cnt <= bit_cnt + 4'h1;
                    end
                end
            endcase
        end
    end

    // tx_bit
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_bit <= 1'b1;
        end else begin
            case (state)
                S_IDLE, S_STOP: begin
                    tx_bit <= 1'b1;
                end
                S_START: begin
                    tx_bit <= 1'b0;
                end
                S_SEND_BYTE: begin
                    tx_bit <= uart_tx[bit_cnt];
                end
            endcase
        end
    end

    // *************************** RX接收 ****************************

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_q0 <= 1'b0;
            rx_q1 <= 1'b0;	
        end else begin
            rx_q0 <= rx_pin;
            rx_q1 <= rx_q0;
        end
    end

    // 下降沿检测(检测起始信号)
    assign rx_negedge = rx_q1 & (~rx_q0);

    // 产生开始接收数据信号，接收期间一直有效
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_start <= 1'b0;
        end else begin
            if (uart_ctrl[1]) begin
                if (rx_negedge) begin
                    rx_start <= 1'b1;
                end else if (rx_clk_edge_cnt == 4'd9) begin
                    rx_start <= 1'b0;
                end
            end else begin
                rx_start <= 1'b0;
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_div_cnt <= 16'h0;
        end else begin
            // 第一个时钟沿只需波特率分频系数的一半
            if (rx_start == 1'b1 && rx_clk_edge_cnt == 4'h0) begin
                rx_div_cnt <= {1'b0, uart_baud[15:1]};
            end else begin
                rx_div_cnt <= uart_baud[15:0];
            end
        end
    end

    // 对时钟进行计数
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_cnt <= 16'h0;
        end else if (rx_start == 1'b1) begin
            // 计数达到分频值
            if (rx_clk_cnt == rx_div_cnt) begin
                rx_clk_cnt <= 16'h0;
            end else begin
                rx_clk_cnt <= rx_clk_cnt + 16'h1;
            end
        end else begin
            rx_clk_cnt <= 16'h0;
        end
    end

    // 每当时钟计数达到分频值时产生一个上升沿脉冲
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end else if (rx_start == 1'b1) begin
            // 计数达到分频值
            if (rx_clk_cnt == rx_div_cnt) begin
                // 时钟沿个数达到最大值
                if (rx_clk_edge_cnt == 4'd9) begin
                    rx_clk_edge_cnt <= 4'h0;
                    rx_clk_edge_level <= 1'b0;
                end else begin
                    // 时钟沿个数加1
                    rx_clk_edge_cnt <= rx_clk_edge_cnt + 4'h1;
                    // 产生上升沿脉冲
                    rx_clk_edge_level <= 1'b1;
                end
            end else begin
                rx_clk_edge_level <= 1'b0;
            end
        end else begin
            rx_clk_edge_cnt <= 4'h0;
            rx_clk_edge_level <= 1'b0;
        end
    end

    // bit序列
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h0;
            rx_over <= 1'b0;
        end else begin
            if (rx_start == 1'b1) begin
                // 上升沿
                if (rx_clk_edge_level == 1'b1) begin
                    case (rx_clk_edge_cnt)
                        // 起始位
                        1: begin

                        end
                        // 第1位数据位
                        2: begin
                            if (rx_pin) begin
                                rx_data <= 8'h80;
                            end else begin
                                rx_data <= 8'h0;
                            end
                        end
                        // 剩余数据位
                        3, 4, 5, 6, 7, 8, 9: begin
                            rx_data <= {rx_pin, rx_data[7:1]};
                            // 最后一位接收完成，置位接收完成标志
                            if (rx_clk_edge_cnt == 4'h9) begin
                                rx_over <= 1'b1;
                            end
                        end
                    endcase
                end
            end else begin
                rx_data <= 8'h0;
                rx_over <= 1'b0;
            end
        end
    end

endmodule
