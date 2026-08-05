`include "../../top/macros.v"

module exu_ext_if(

    input wire clk,
    input wire rst_n,

    input wire req_if_i,
    input wire[31:0] if_rs1_i,
    input wire[31:0] if_vth_i,
    input wire[31:0] if_imm_i,

    input wire mem_req_ready_i,
    input wire mem_rsp_valid_i,
    input wire[31:0] mem_rdata_i,

    output wire if_stall_o,
    output reg[31:0] if_mem_addr_o,
    output reg[31:0] if_mem_wdata_o,
    output reg if_mem_we_o,
    output wire[3:0] if_mem_sel_o,
    output wire if_mem_req_valid_o,
    output wire if_mem_rsp_ready_o,

    output wire[31:0] if_reg_wdata_o,
    output wire if_reg_we_o

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
    reg done_seen;
    reg[7:0] tx_data;
    reg send_done_r;

    wire imm_is_zero = (if_imm_i == 32'h0);
    wire need_send = imm_is_zero & (if_rs1_i >= if_vth_i);
    wire active = req_if_i & need_send & (~done_seen);
    wire req_hsked = if_mem_req_valid_o & mem_req_ready_i;
    wire rsp_hsked = if_mem_rsp_ready_o & mem_rsp_valid_i;
    wire tx_idle = ~mem_rdata_i[0];

    assign if_mem_sel_o = 4'hf;
    assign if_mem_rsp_ready_o = 1'b1;
    assign if_mem_req_valid_o = (state == S_CTRL_REQ) |
                                (state == S_STATUS_REQ) |
                                (state == S_TX_REQ) |
                                (state == S_DONE_REQ);
    assign if_stall_o = active;

    assign if_reg_wdata_o = need_send ? 32'h0 :
                             imm_is_zero ? if_rs1_i :
                             (if_rs1_i + if_imm_i);
    assign if_reg_we_o = req_if_i & ((~need_send) | send_done_r);

    always @(*) begin
        if_mem_addr_o = 32'h0;
        if_mem_wdata_o = 32'h0;
        if_mem_we_o = 1'b0;

        case (state)
            S_CTRL_REQ: begin
                if_mem_addr_o = UART_CTRL_ADDR;
                if_mem_wdata_o = 32'h1;
                if_mem_we_o = 1'b1;
            end
            S_STATUS_REQ: begin
                if_mem_addr_o = UART_STATUS_ADDR;
            end
            S_TX_REQ: begin
                if_mem_addr_o = UART_TXDATA_ADDR;
                if_mem_wdata_o = {24'h0, tx_data};
                if_mem_we_o = 1'b1;
            end
            S_DONE_REQ: begin
                if_mem_addr_o = UART_STATUS_ADDR;
            end
            default: begin
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done_seen <= 1'b0;
            tx_data <= 8'h0;
            send_done_r <= 1'b0;
        end else begin
            send_done_r <= 1'b0;

            if (!req_if_i) begin
                done_seen <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (active) begin
                        tx_data <= if_rs1_i[7:0];
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
                        state <= S_DONE_REQ;
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
                            send_done_r <= 1'b1;
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
