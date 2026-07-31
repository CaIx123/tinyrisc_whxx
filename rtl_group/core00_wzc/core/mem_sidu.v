`timescale 1ns / 1ps

`include "../../top/macros.v"

module mem_sidu(

    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire accept_i,

    output wire busy_o,
    output wire ready_o,

    // to RIB master
    output wire[`DATA_WIDTH-1:0] rib_addr_o,
    output wire[`DATA_WIDTH-1:0] rib_data_o,
    output wire[3:0] rib_sel_o,
    output wire rib_req_vld_o,
    input wire rib_req_rdy_i,
    output wire rib_rsp_rdy_o,
    input wire rib_rsp_vld_i,
    input wire[`DATA_WIDTH-1:0] rib_data_i,
    output wire rib_we_o

    );

    localparam SID_IDLE       = 3'd0;
    localparam SID_CTRL_REQ   = 3'd1;
    localparam SID_CTRL_RSP   = 3'd2;
    localparam SID_STATUS_REQ = 3'd3;
    localparam SID_STATUS_RSP = 3'd4;
    localparam SID_TX_REQ     = 3'd5;
    localparam SID_TX_RSP     = 3'd6;
    localparam SID_DONE       = 3'd7;

    localparam UART_CTRL_ADDR   = 32'h3000_0000;
    localparam UART_STATUS_ADDR = 32'h3000_0004;
    localparam UART_TXDATA_ADDR = 32'h3000_000c;

    reg[2:0] state, state_next;
    reg[3:0] char_idx, char_idx_next;

    wire req_hasked = rib_req_vld_o & rib_req_rdy_i;
    wire rsp_hasked = rib_rsp_vld_i & rib_rsp_rdy_o;

    wire is_last_char = (char_idx == 4'd9);
    wire uart_busy = rib_data_i[0];

    reg[7:0] send_data;

    always @(*) begin
        case (char_idx)
            4'd0: send_data = 8'h32; // 2
            4'd1: send_data = 8'h30; // 0
            4'd2: send_data = 8'h32; // 2
            4'd3: send_data = 8'h35; // 5
            4'd4: send_data = 8'h32; // 2
            4'd5: send_data = 8'h31; // 1
            4'd6: send_data = 8'h30; // 0
            4'd7: send_data = 8'h39; // 9
            4'd8: send_data = 8'h31; // 1
            4'd9: send_data = 8'h33; // 3
            default: send_data = 8'h00;
        endcase
    end

    always @(*) begin
        state_next = state;
        char_idx_next = char_idx;

        case (state)
            SID_IDLE: begin
                char_idx_next = 4'd0;
                if (start_i) begin
                    state_next = SID_CTRL_REQ;
                end
            end

            // 先写 UART_CTRL = 1，打开 TX 使能
            SID_CTRL_REQ: begin
                if (req_hasked) begin
                    state_next = SID_CTRL_RSP;
                end
            end

            SID_CTRL_RSP: begin
                if (rsp_hasked) begin
                    state_next = SID_STATUS_REQ;
                end
            end

            // 读 UART_STATUS，检查 TX 是否 busy
            SID_STATUS_REQ: begin
                if (req_hasked) begin
                    state_next = SID_STATUS_RSP;
                end
            end

            SID_STATUS_RSP: begin
                if (rsp_hasked) begin
                    if (uart_busy) begin
                        state_next = SID_STATUS_REQ;
                    end else begin
                        state_next = SID_TX_REQ;
                    end
                end
            end

            // 写 UART_TXDATA，发送当前字符
            SID_TX_REQ: begin
                if (req_hasked) begin
                    state_next = SID_TX_RSP;
                end
            end

            SID_TX_RSP: begin
                if (rsp_hasked) begin
                    if (is_last_char) begin
                        state_next = SID_DONE;
                    end else begin
                        char_idx_next = char_idx + 1'b1;
                        state_next = SID_STATUS_REQ;
                    end
                end
            end

            SID_DONE: begin
                if (accept_i) begin
                    state_next = SID_IDLE;
                end
            end

            default: begin
                state_next = SID_IDLE;
                char_idx_next = 4'd0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= SID_IDLE;
            char_idx <= 4'd0;
        end else begin
            state <= state_next;
            char_idx <= char_idx_next;
        end
    end

    assign busy_o = (state != SID_IDLE) & (state != SID_DONE);
    assign ready_o = (state == SID_DONE);

    assign rib_addr_o =
        (state == SID_CTRL_REQ) ? UART_CTRL_ADDR :
        (state == SID_TX_REQ)   ? UART_TXDATA_ADDR :
                                  UART_STATUS_ADDR;

    assign rib_data_o =
        (state == SID_CTRL_REQ) ? 32'h0000_0001 :
                                  {24'b0, send_data};

    assign rib_sel_o = 4'b0001;

    assign rib_req_vld_o =
        (state == SID_CTRL_REQ)   |
        (state == SID_STATUS_REQ) |
        (state == SID_TX_REQ);

    assign rib_rsp_rdy_o =
        (state == SID_CTRL_RSP)   |
        (state == SID_STATUS_RSP) |
        (state == SID_TX_RSP);

    assign rib_we_o =
        (state == SID_CTRL_REQ) |
        (state == SID_TX_REQ);

endmodule
