`include "../core/defines.v"
`include "../tiny_macro.v"

// UART烧录/调试下载模块
// 当debug_en_i有效时停住CPU，通过UART接收固件包
// 包格式：byte[0]=包号, byte[1..32]=payload(32字节), byte[33-34]=CRC16
// 第0包payload前4字节为固件总大小，后续包为程序数据
// CRC采用CRC16/Modbus(poly=0xA001, init=0xFFFF)
// 每包结束后通过UART回ACK(0x06)或NAK(0x15)
module uart_debug(

    input  wire        clk,                  // 时钟
    input  wire        rst_n,                // 复位(低有效)

    input  wire        debug_en_i,           // 调试使能(低电平时CPU正常运行，高电平时调试)

    output reg         req_valid_o,           // 总线请求有效
    input  wire        req_ready_i,           // 总线请求就绪

    input  wire        rsp_valid_i,           // 总线响应有效
    output reg         rsp_ready_o,           // 总线响应就绪

    output reg         mem_we_o,              // 存储器写使能
    output reg [31:0]  mem_addr_o,            // 存储器地址
    output reg [31:0]  mem_wdata_o,           // 存储器写数据
    output reg [3:0]   mem_sel_o,             // 存储器字节选择
    input  wire [31:0] mem_rdata_i            // 存储器读数据

    );

    localparam integer PACKET_LEN    = `UART_PACKET_LEN;
    localparam integer PAYLOAD_BYTES = `UART_PACKET_LEN - 3;

    localparam [7:0] PAYLOAD_START_INDEX = 8'd1;
    localparam [7:0] PAYLOAD_END_INDEX   = `UART_PACKET_LEN - 8'd3;

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

    localparam BUS_IDLE = 2'd0;
    localparam BUS_REQ  = 2'd1;
    localparam BUS_RSP  = 2'd2;

    reg [7:0] state;
    reg [1:0] bus_state;

    reg        bus_start;
    reg        bus_we;
    reg [31:0] bus_addr;
    reg [31:0] bus_wdata;
    reg [3:0]  bus_sel;
    reg [31:0] bus_rdata;
    reg        bus_done;

    reg [7:0]  rx_data [0:PACKET_LEN-1];
    reg [7:0]  rec_bytes_index;
    reg        current_is_first_packet;
    reg [15:0] remain_packet_count;
    reg [31:0] fw_file_size;
    reg [31:0] fw_bytes_remaining;

    reg [31:0] write_mem_addr;
    reg [7:0]  write_payload_index;
    reg [7:0]  write_valid_bytes;
    reg [31:0] write_mem_data;
    reg [3:0]  write_mem_sel;

    reg [15:0] crc_result;
    reg [3:0]  crc_bit_index;
    reg [7:0]  crc_byte_index;

    wire [7:0] write_index0 = PAYLOAD_START_INDEX + write_payload_index;
    wire [7:0] write_index1 = PAYLOAD_START_INDEX + write_payload_index + 8'd1;
    wire [7:0] write_index2 = PAYLOAD_START_INDEX + write_payload_index + 8'd2;
    wire [7:0] write_index3 = PAYLOAD_START_INDEX + write_payload_index + 8'd3;
    wire [7:0] bytes_left = write_valid_bytes - write_payload_index;
    wire [1:0] write_lane_offset = write_mem_addr[1:0];
    wire [7:0] bytes_to_word_end = 8'd4 - {6'd0, write_lane_offset};
    wire [7:0] write_chunk_bytes = (bytes_left < bytes_to_word_end) ? bytes_left : bytes_to_word_end;
    reg [31:0] next_write_mem_data;
    reg [3:0] next_write_mem_sel;
    wire [15:0] packet_count_calc = (fw_file_size + PAYLOAD_BYTES - 1) / PAYLOAD_BYTES;
    wire [31:0] ack_word = 32'h0002_0006;
    wire [31:0] nak_word = 32'h0002_0015;

    always @(*) begin
        next_write_mem_data = 32'h0;
        next_write_mem_sel = 4'b0000;

        if (write_chunk_bytes > 8'd0) begin
            case (write_lane_offset)
                2'd0: begin
                    next_write_mem_sel = (write_chunk_bytes == 8'd4) ? 4'b1111 :
                                         (write_chunk_bytes == 8'd3) ? 4'b0111 :
                                         (write_chunk_bytes == 8'd2) ? 4'b0011 :
                                         4'b0001;
                    next_write_mem_data[7:0] = rx_data[write_index0];
                    if (write_chunk_bytes > 8'd1) next_write_mem_data[15:8] = rx_data[write_index1];
                    if (write_chunk_bytes > 8'd2) next_write_mem_data[23:16] = rx_data[write_index2];
                    if (write_chunk_bytes > 8'd3) next_write_mem_data[31:24] = rx_data[write_index3];
                end
                2'd1: begin
                    next_write_mem_sel = (write_chunk_bytes == 8'd3) ? 4'b1110 :
                                         (write_chunk_bytes == 8'd2) ? 4'b0110 :
                                         4'b0010;
                    next_write_mem_data[15:8] = rx_data[write_index0];
                    if (write_chunk_bytes > 8'd1) next_write_mem_data[23:16] = rx_data[write_index1];
                    if (write_chunk_bytes > 8'd2) next_write_mem_data[31:24] = rx_data[write_index2];
                end
                2'd2: begin
                    next_write_mem_sel = (write_chunk_bytes == 8'd2) ? 4'b1100 : 4'b0100;
                    next_write_mem_data[23:16] = rx_data[write_index0];
                    if (write_chunk_bytes > 8'd1) next_write_mem_data[31:24] = rx_data[write_index1];
                end
                default: begin
                    next_write_mem_sel = 4'b1000;
                    next_write_mem_data[31:24] = rx_data[write_index0];
                end
            endcase
        end
    end

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
                        rsp_ready_o <= 1'b1;
                        bus_state   <= BUS_RSP;
                    end
                end

                BUS_RSP: begin
                    if (rsp_valid_i) begin
                        bus_rdata   <= mem_rdata_i;
                        req_valid_o <= 1'b0;
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
            fw_bytes_remaining <= 32'h0;

            write_mem_addr <= `ROM_START_ADDR;
            write_payload_index <= 8'h0;
            write_valid_bytes <= 8'h0;
            write_mem_data <= 32'h0;
            write_mem_sel <= 4'h0;

            crc_result <= 16'h0;
            crc_bit_index <= 4'h0;
            crc_byte_index <= 8'h0;
        end else begin
            bus_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    state <= S_INIT_UART_CTRL;
                end

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

                S_INIT_UART_BAUD: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_BAUD_REG;
                    bus_wdata <= `UART_BAUD_115200;
                    bus_sel   <= 4'b1111;
                    bus_start <= 1'b1;
                    state <= S_INIT_UART_BAUD_WAIT;
                end

                S_INIT_UART_BAUD_WAIT: begin
                    if (bus_done) begin
                        state <= S_REC_FIRST_PACKET;
                    end
                end

                S_REC_FIRST_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    current_is_first_packet <= 1'b1;
                    remain_packet_count <= 16'h0;
                    fw_file_size <= 32'h0;
                    fw_bytes_remaining <= 32'h0;
                    write_mem_addr <= `ROM_START_ADDR;
                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end

                S_REC_REMAIN_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    current_is_first_packet <= 1'b0;
                    state <= S_CLEAR_UART_RX_OVER_FLAG;
                end

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
                        if (rec_bytes_index == (PACKET_LEN - 1)) begin
                            state <= S_CRC_START;
                        end else begin
                            rec_bytes_index <= rec_bytes_index + 8'd1;
                            state <= S_CLEAR_UART_RX_OVER_FLAG;
                        end
                    end
                end

                S_CRC_START: begin
                    crc_result <= 16'hffff;
                    crc_bit_index <= 4'd0;
                    crc_byte_index <= PAYLOAD_START_INDEX;
                    fw_file_size <= {rx_data[1], rx_data[2], rx_data[3], rx_data[4]};
                    state <= S_CRC_CALC;
                end

                S_CRC_CALC: begin
                    if (crc_bit_index == 4'd0) begin
                        crc_result <= crc_result ^ {8'h00, rx_data[crc_byte_index]};
                        crc_bit_index <= 4'd1;
                    end else begin
                        if (crc_result[0]) begin
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
                    if (crc_result == {rx_data[PACKET_LEN - 1], rx_data[PACKET_LEN - 2]}) begin
                        if (current_is_first_packet) begin
                            fw_bytes_remaining <= fw_file_size;
                            remain_packet_count <= packet_count_calc;
                            state <= S_SEND_ACK;
                        end else begin
                            if (fw_bytes_remaining >= PAYLOAD_BYTES) begin
                                write_valid_bytes <= PAYLOAD_BYTES;
                                fw_bytes_remaining <= fw_bytes_remaining - PAYLOAD_BYTES;
                            end else begin
                                write_valid_bytes <= fw_bytes_remaining[7:0];
                                fw_bytes_remaining <= 32'h0;
                            end
                            remain_packet_count <= remain_packet_count - 16'd1;
                            write_payload_index <= 8'h0;
                            state <= S_WRITE_MEM_PREP;
                        end
                    end else begin
                        state <= S_SEND_NAK;
                    end
                end

                S_WRITE_MEM_PREP: begin
                    if (write_payload_index >= write_valid_bytes) begin
                        state <= S_SEND_ACK;
                    end else begin
                        write_mem_data <= next_write_mem_data;
                        write_mem_sel <= next_write_mem_sel;
                        state <= S_WRITE_MEM_REQ;
                    end
                end

                S_WRITE_MEM_REQ: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= write_mem_addr;
                    bus_wdata <= write_mem_data;
                    bus_sel   <= write_mem_sel;
                    bus_start <= 1'b1;
                    state <= S_WRITE_MEM_WAIT;
                end

                S_WRITE_MEM_WAIT: begin
                    if (bus_done) begin
                        write_mem_addr <= write_mem_addr + write_chunk_bytes;
                        write_payload_index <= write_payload_index + write_chunk_bytes;
                        state <= S_WRITE_MEM_PREP;
                    end
                end

                S_SEND_ACK: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_TX_REG;
                    bus_wdata <= ack_word;
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

                S_SEND_NAK: begin
                    bus_we    <= 1'b1;
                    bus_addr  <= `UART_TX_REG;
                    bus_wdata <= nak_word;
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
