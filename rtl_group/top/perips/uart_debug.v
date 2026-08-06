`timescale 1ns / 1ps

`include "../macros.v"

module uart_debug #(
    parameter [31:0] UART_BAUD_DIV = `UART_BAUD_115200
)(

    input  wire        clk,
    input  wire        rst_n,          // 同步低有效复位

    input  wire        debug_en_i,     // debug 模式使能

    // RIB master request channel
    output reg         req_valid_o,
    input  wire        req_ready_i,

    // RIB master response channel
    input  wire        rsp_valid_i,
    output reg         rsp_ready_o,

    // RIB master payload
    output reg         mem_we_o,
    output reg [31:0]  mem_addr_o,
    output reg [31:0]  mem_wdata_o,
    output reg [3:0]   mem_sel_o,
    input  wire [31:0] mem_rdata_i

    );


    // ============================================================
    // 35-byte packet 格式
    // ============================================================
    localparam integer PACKET_LEN    = `UART_PACKET_LEN;       // 35
    localparam integer PAYLOAD_BYTES = `UART_PACKET_LEN - 3;   // 32
    localparam integer PAYLOAD_SHIFT = 5;                      // 32 = 2^5

    // byte[0]      : header
    // byte[1:32]   : payload
    // byte[33]     : CRC low
    // byte[34]     : CRC high
    localparam [7:0] PAYLOAD_START_INDEX = 8'd1;
    localparam [7:0] PAYLOAD_END_INDEX   = `UART_PACKET_LEN - 8'd3;
    localparam [7:0] FIRST_PACKET_SIZE_INDEX = 8'd25;


    // ============================================================
    // main FSM states
    // ============================================================

    localparam S_IDLE                         = 8'd0;

    localparam S_INIT_UART_CTRL               = 8'd1;
    localparam S_INIT_UART_CTRL_WAIT          = 8'd2;
    localparam S_INIT_UART_BAUD               = 8'd3;
    localparam S_INIT_UART_BAUD_WAIT          = 8'd4;

    localparam S_REC_FIRST_PACKET             = 8'd5;
    localparam S_REC_REMAIN_PACKET            = 8'd6;

    localparam S_CLEAR_UART_RX_OVER_FLAG      = 8'd7;
    localparam S_CLEAR_UART_RX_OVER_FLAG_WAIT = 8'd8;

    localparam S_READ_UART_STATUS             = 8'd9;
    localparam S_READ_UART_STATUS_WAIT        = 8'd10;

    localparam S_READ_UART_RX                 = 8'd11;
    localparam S_READ_UART_RX_WAIT            = 8'd12;

    localparam S_CRC_START                    = 8'd13;
    localparam S_CRC_CALC                     = 8'd14;
    localparam S_CRC_END                      = 8'd15;

    localparam S_WRITE_MEM_PREP               = 8'd16;
    localparam S_WRITE_MEM_REQ                = 8'd17;
    localparam S_WRITE_MEM_WAIT               = 8'd18;

    localparam S_SEND_ACK                     = 8'd19;
    localparam S_SEND_ACK_WAIT                = 8'd20;

    localparam S_SEND_NAK                     = 8'd21;
    localparam S_SEND_NAK_WAIT                = 8'd22;

    reg [7:0] state;


    // ============================================================
    // bus access helper FSM
    // ============================================================

    localparam BUS_IDLE = 2'd0;
    localparam BUS_REQ  = 2'd1;
    localparam BUS_RSP  = 2'd2;

    reg [1:0] bus_state;

    reg        bus_start;
    reg        bus_we;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    reg [3:0]  bus_sel;

    reg [31:0] bus_rdata;
    reg        bus_done;


    // 总线访问子状态机
    always @(posedge clk) begin
        if (!rst_n || !debug_en_i) begin
            bus_state   <= BUS_IDLE;

            req_valid_o <= 1'b0;
            rsp_ready_o <= 1'b0;

            mem_we_o    <= 1'b0;
            mem_addr_o  <= 32'h0;
            mem_wdata_o <= 32'h0;
            mem_sel_o   <= 4'b0000;

            bus_rdata   <= 32'h0;
            bus_done    <= 1'b0;
        end else begin
            bus_done <= 1'b0;

            case (bus_state)

                BUS_IDLE: begin
                    req_valid_o <= 1'b0;
                    rsp_ready_o <= 1'b0;

                    if (bus_start) begin
                        mem_we_o    <= bus_we;
                        mem_addr_o  <= bus_addr;
                        mem_wdata_o <= bus_wdata;
                        mem_sel_o   <= bus_sel;

                        req_valid_o <= 1'b1;
                        bus_state   <= BUS_REQ;
                    end
                end

                BUS_REQ: begin
                    if (req_ready_i) begin
                        req_valid_o <= 1'b0;
                        rsp_ready_o <= 1'b1;
                        bus_state   <= BUS_RSP;
                    end
                end

                BUS_RSP: begin
                    if (rsp_valid_i) begin
                        bus_rdata   <= mem_rdata_i;
                        rsp_ready_o <= 1'b0;
                        bus_done    <= 1'b1;
                        bus_state   <= BUS_IDLE;
                    end
                end

                default: begin
                    bus_state   <= BUS_IDLE;
                    req_valid_o <= 1'b0;
                    rsp_ready_o <= 1'b0;
                end

            endcase
        end
    end


    // ============================================================
    // packet / write / CRC registers
    // ============================================================

    reg [7:0] rx_data [0:PACKET_LEN-1];

    reg [7:0]  rec_bytes_index;
    reg        current_is_first_packet;

    reg [15:0] remain_packet_count;
    reg [31:0] fw_file_size;

    reg [31:0] write_mem_addr;
    reg [31:0] write_mem_data;

    reg [7:0] write_mem_byte_index0;
    reg [7:0] write_mem_byte_index1;
    reg [7:0] write_mem_byte_index2;
    reg [7:0] write_mem_byte_index3;

    reg [15:0] crc_result;
    reg [3:0]  crc_bit_index;
    reg [7:0]  crc_byte_index;


    // ============================================================
    // main control FSM
    // ============================================================

    always @(posedge clk) begin
        if (!rst_n || !debug_en_i) begin

            state <= S_IDLE;

            bus_start <= 1'b0;
            bus_we    <= 1'b0;
            bus_addr  <= 32'h0;
            bus_wdata <= 32'h0;
            bus_sel   <= 4'b0000;

            rec_bytes_index <= 8'h0;
            current_is_first_packet <= 1'b1;

            remain_packet_count <= 16'h0;
            fw_file_size <= 32'h0;

            write_mem_addr <= `ROM_START_ADDR;
            write_mem_data <= 32'h0;

            write_mem_byte_index0 <= 8'h0;
            write_mem_byte_index1 <= 8'h0;
            write_mem_byte_index2 <= 8'h0;
            write_mem_byte_index3 <= 8'h0;

            crc_result <= 16'h0;
            crc_bit_index <= 4'h0;
            crc_byte_index <= 8'h0;

        end else begin

            bus_start <= 1'b0;

            case (state)

                // ------------------------------------------------
                // debug 模式启动后，初始化 UART
                // ------------------------------------------------

                S_IDLE: begin
                    state <= S_INIT_UART_CTRL;
                end

                // 写 UART_CTRL = 0x3
                // uart_ctrl[0] = 1: TX enable
                // uart_ctrl[1] = 1: RX enable
                S_INIT_UART_CTRL: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_CTRL_REG;
                    bus_wdata <= 32'h3;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_INIT_UART_CTRL_WAIT;
                end

                S_INIT_UART_CTRL_WAIT: begin
                    if (bus_done) begin
                        state <= S_INIT_UART_BAUD;
                    end
                end

                // 写 UART_BAUD
                S_INIT_UART_BAUD: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_BAUD_REG;
                    bus_wdata <= UART_BAUD_DIV;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_INIT_UART_BAUD_WAIT;
                end

                S_INIT_UART_BAUD_WAIT: begin
                    if (bus_done) begin
                        state <= S_REC_FIRST_PACKET;
                    end
                end


                // ------------------------------------------------
                // 准备接收首包 / 后续包
                // ------------------------------------------------

                S_REC_FIRST_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    current_is_first_packet <= 1'b1;
                    remain_packet_count <= 16'h0;

                    write_mem_addr <= `ROM_START_ADDR;

                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end

                S_REC_REMAIN_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    current_is_first_packet <= 1'b0;

                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end


                // ------------------------------------------------
                // 接收一个 UART byte
                // ------------------------------------------------

                // 清除 UART_STATUS[1]，即 RX_OVER
                S_CLEAR_UART_RX_OVER_FLAG: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_STATUS_REG;
                    bus_wdata <= 32'h0;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_CLEAR_UART_RX_OVER_FLAG_WAIT;
                end

                S_CLEAR_UART_RX_OVER_FLAG_WAIT: begin
                    if (bus_done) begin
                        state <= S_READ_UART_STATUS;
                    end
                end

                // 读 UART_STATUS
                S_READ_UART_STATUS: begin
                    bus_we    <= 1'b0;
                    bus_addr  <= `UART_STATUS_REG;
                    bus_wdata <= 32'h0;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_READ_UART_STATUS_WAIT;
                end

                S_READ_UART_STATUS_WAIT: begin
                    if (bus_done) begin
                        if ((bus_rdata & `UART_RX_OVER_FLAG) == `UART_RX_OVER_FLAG) begin
                            state <= S_READ_UART_RX;
                        end else begin
                            state <= S_READ_UART_STATUS;
                        end
                    end
                end

                // 读 UART_RX_REG
                S_READ_UART_RX: begin
                    bus_we    <= 1'b0;
                    bus_addr  <= `UART_RX_REG;
                    bus_wdata <= 32'h0;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_READ_UART_RX_WAIT;
                end

                S_READ_UART_RX_WAIT: begin
                    if (bus_done) begin
                        rx_data[rec_bytes_index] <= bus_rdata[7:0];

                        if (rec_bytes_index == (`UART_PACKET_LEN - 8'd1)) begin
                            state <= S_CRC_START;
                        end else begin
                            rec_bytes_index <= rec_bytes_index + 8'd1;
                            state <= S_CLEAR_UART_RX_OVER_FLAG;
                        end
                    end
                end


                // ------------------------------------------------
                // CRC16 计算
                // 计算范围：
                //   rx_data[1] 到 rx_data[32]
                // CRC 存放：
                //   rx_data[33] = crc low byte
                //   rx_data[34] = crc high byte
                // ------------------------------------------------

                S_CRC_START: begin
                    crc_result <= 16'hffff;
                    crc_bit_index <= 4'd0;
                    crc_byte_index <= PAYLOAD_START_INDEX;

                    // 首包格式和 sim/test_uart_debug.py 保持一致：
                    // byte[1:24]  为文件名区域
                    // byte[25:28] 为固件大小，大端拼接
                    if (current_is_first_packet) begin
                        fw_file_size <= {rx_data[FIRST_PACKET_SIZE_INDEX],
                                         rx_data[FIRST_PACKET_SIZE_INDEX + 8'd1],
                                         rx_data[FIRST_PACKET_SIZE_INDEX + 8'd2],
                                         rx_data[FIRST_PACKET_SIZE_INDEX + 8'd3]};
                    end

                    state <= S_CRC_CALC;
                end

                S_CRC_CALC: begin
                    if (crc_bit_index == 4'd0) begin
                        if (crc_byte_index <= PAYLOAD_END_INDEX) begin
                            crc_result <= crc_result ^ {8'h00, rx_data[crc_byte_index]};
                            crc_bit_index <= 4'd1;
                        end else begin
                            state <= S_CRC_END;
                        end
                    end else begin
                        if (crc_result[0] == 1'b1) begin
                            crc_result <= {1'b0, crc_result[15:1]} ^ 16'ha001;
                        end else begin
                            crc_result <= {1'b0, crc_result[15:1]};
                        end

                        if (crc_bit_index == 4'd8) begin
                            if (crc_byte_index == PAYLOAD_END_INDEX) begin
                                state <= S_CRC_END;
                            end else begin
                                crc_byte_index <= crc_byte_index + 8'd1;
                                crc_bit_index <= 4'd0;
                            end
                        end else begin
                            crc_bit_index <= crc_bit_index + 4'd1;
                        end
                    end
                end

                S_CRC_END: begin
                    if (crc_result == {rx_data[`UART_PACKET_LEN - 8'd1],
                                       rx_data[`UART_PACKET_LEN - 8'd2]}) begin

                        if (current_is_first_packet) begin
                            // 后续每个 packet 有 32 byte payload
                            // remain_packet_count = ceil(fw_file_size / 32)
                            remain_packet_count <= (fw_file_size + 32'd31) >> PAYLOAD_SHIFT;

                            state <= S_SEND_ACK;
                        end else begin
                            // 当前数据包 CRC 正确，准备写入 memory
                            remain_packet_count <= remain_packet_count - 16'd1;

                            write_mem_byte_index0 <= 8'd1;
                            write_mem_byte_index1 <= 8'd2;
                            write_mem_byte_index2 <= 8'd3;
                            write_mem_byte_index3 <= 8'd4;

                            state <= S_WRITE_MEM_PREP;
                        end

                    end else begin
                        state <= S_SEND_NAK;
                    end
                end


                // ------------------------------------------------
                // 写 memory
                // 32 byte payload，每 4 byte 拼成一个 32-bit word
                // 小端序：
                //   mem_wdata[7:0]   = rx_data[index0]
                //   mem_wdata[15:8]  = rx_data[index1]
                //   mem_wdata[23:16] = rx_data[index2]
                //   mem_wdata[31:24] = rx_data[index3]
                // ------------------------------------------------

                S_WRITE_MEM_PREP: begin
                    if ((write_mem_byte_index0 <= PAYLOAD_END_INDEX) &&
                        (write_mem_byte_index1 <= PAYLOAD_END_INDEX) &&
                        (write_mem_byte_index2 <= PAYLOAD_END_INDEX) &&
                        (write_mem_byte_index3 <= PAYLOAD_END_INDEX)) begin
                        write_mem_data <= {
                            rx_data[write_mem_byte_index3],
                            rx_data[write_mem_byte_index2],
                            rx_data[write_mem_byte_index1],
                            rx_data[write_mem_byte_index0]
                        };

                        state <= S_WRITE_MEM_REQ;
                    end else begin
                        state <= S_SEND_ACK;
                    end
                end

                S_WRITE_MEM_REQ: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= write_mem_addr;
                    bus_wdata <= write_mem_data;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_WRITE_MEM_WAIT;
                end

                S_WRITE_MEM_WAIT: begin
                    if (bus_done) begin
                        write_mem_addr <= write_mem_addr + 32'd4;

                        write_mem_byte_index0 <= write_mem_byte_index0 + 8'd4;
                        write_mem_byte_index1 <= write_mem_byte_index1 + 8'd4;
                        write_mem_byte_index2 <= write_mem_byte_index2 + 8'd4;
                        write_mem_byte_index3 <= write_mem_byte_index3 + 8'd4;

                        state <= S_WRITE_MEM_PREP;
                    end
                end


                // ------------------------------------------------
                // 发送 ACK
                // ------------------------------------------------

                S_SEND_ACK: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_TX_REG;
                    bus_wdata <= `UART_RESP_ACK;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_SEND_ACK_WAIT;
                end

                S_SEND_ACK_WAIT: begin
                    if (bus_done) begin
                        if (remain_packet_count > 16'd0) begin
                            state <= S_REC_REMAIN_PACKET;
                        end else begin
                            state <= S_REC_FIRST_PACKET;
                        end
                    end
                end


                // ------------------------------------------------
                // 发送 NAK
                // ------------------------------------------------

                S_SEND_NAK: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_TX_REG;
                    bus_wdata <= `UART_RESP_NAK;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;

                    state <= S_SEND_NAK_WAIT;
                end

                S_SEND_NAK_WAIT: begin
                    if (bus_done) begin
                        if (current_is_first_packet) begin
                            state <= S_REC_FIRST_PACKET;
                        end else begin
                            state <= S_REC_REMAIN_PACKET;
                        end
                    end
                end


                default: begin
                    state <= S_IDLE;
                end

            endcase
        end
    end

endmodule
