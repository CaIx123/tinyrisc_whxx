`include "defines.v"

module exu_ext_sid_hjx(

    input wire clk,
    input wire rst_n,

    input wire req_sid_i,
    input wire mem_req_ready_i,
    input wire mem_rsp_valid_i,
    input wire[31:0] mem_rdata_i,

    output wire sid_stall_o,
    output reg[31:0] sid_mem_addr_o,
    output reg[31:0] sid_mem_wdata_o,
    output reg sid_mem_we_o,
    output wire[3:0] sid_mem_sel_o,
    output wire sid_mem_req_valid_o,
    output wire sid_mem_rsp_ready_o

    );

    localparam UART_CTRL_ADDR   = 32'h3000_0000;
    localparam UART_STATUS_ADDR = 32'h3000_0004;
    localparam UART_TXDATA_ADDR = 32'h3000_000c;

    localparam S_IDLE       = 4'd0;
    localparam S_CTRL_REQ   = 4'd1;
    localparam S_CTRL_RSP   = 4'd2;
    localparam S_STATUS_REQ = 4'd3;
    localparam S_STATUS_RSP = 4'd4;
    localparam S_TX_REQ     = 4'd5;
    localparam S_TX_RSP     = 4'd6;
    localparam S_DONE_REQ   = 4'd7;
    localparam S_DONE_RSP   = 4'd8;

    reg[3:0] state;
    reg[3:0] char_idx;
    reg done_seen;

    wire active = req_sid_i & (~done_seen);
    wire req_hsked = sid_mem_req_valid_o & mem_req_ready_i;
    wire rsp_hsked = sid_mem_rsp_ready_o & mem_rsp_valid_i;
    wire tx_idle = ~mem_rdata_i[0];

    assign sid_mem_sel_o = 4'hf;
    assign sid_mem_rsp_ready_o = 1'b1;
    assign sid_mem_req_valid_o = (state == S_CTRL_REQ) |
                                 (state == S_STATUS_REQ) |
                                 (state == S_TX_REQ) |
                                 (state == S_DONE_REQ);
    assign sid_stall_o = active;

    function[7:0] sid_char;
        input[3:0] idx;
        begin
            case (idx)
                4'd0: sid_char = 8'h32; // 2
                4'd1: sid_char = 8'h30; // 0
                4'd2: sid_char = 8'h32; // 2
                4'd3: sid_char = 8'h32; // 2
                4'd4: sid_char = 8'h30; // 0
                4'd5: sid_char = 8'h31; // 1
                4'd6: sid_char = 8'h32; // 2
                4'd7: sid_char = 8'h36; // 6
                4'd8: sid_char = 8'h36; // 6
                4'd9: sid_char = 8'h35; // 5
                default: sid_char = 8'h0;
            endcase
        end
    endfunction

    always @(*) begin
        sid_mem_addr_o = 32'h0;
        sid_mem_wdata_o = 32'h0;
        sid_mem_we_o = 1'b0;

        case (state)
            S_CTRL_REQ: begin
                sid_mem_addr_o = UART_CTRL_ADDR;
                sid_mem_wdata_o = 32'h1;
                sid_mem_we_o = 1'b1;
            end
            S_STATUS_REQ: begin
                sid_mem_addr_o = UART_STATUS_ADDR;
            end
            S_DONE_REQ: begin
                sid_mem_addr_o = UART_STATUS_ADDR;
            end
            S_TX_REQ: begin
                sid_mem_addr_o = UART_TXDATA_ADDR;
                sid_mem_wdata_o = {24'h0, sid_char(char_idx)};
                sid_mem_we_o = 1'b1;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            char_idx <= 4'h0;
            done_seen <= 1'b0;
        end else begin
            if (!req_sid_i) begin
                done_seen <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    char_idx <= 4'h0;
                    if (active) begin
                        state <= S_CTRL_REQ;
                    end
                end
                S_CTRL_REQ: begin
                    if (req_hsked) begin
                        state <= S_CTRL_RSP;
                    end
                end
                S_CTRL_RSP: begin
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
                        if (tx_idle) begin
                            state <= S_TX_REQ;
                        end else begin
                            state <= S_STATUS_REQ;
                        end
                    end
                end
                S_TX_REQ: begin
                    if (req_hsked) begin
                        state <= S_TX_RSP;
                    end
                end
                S_TX_RSP: begin
                    if (rsp_hsked) begin
                        if (char_idx == 4'd9) begin
                            state <= S_DONE_REQ;
                        end else begin
                            char_idx <= char_idx + 1'b1;
                            state <= S_STATUS_REQ;
                        end
                    end
                end
                S_DONE_REQ: begin
                    if (req_hsked) begin
                        state <= S_DONE_RSP;
                    end
                end
                S_DONE_RSP: begin
                    if (rsp_hsked) begin
                        if (tx_idle) begin
                            done_seen <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            state <= S_DONE_REQ;
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
