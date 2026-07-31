`timescale 1ns / 1ps

`include "../../top/macros.v"

module mem_ifu(

    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire accept_i,
    input wire[`DATA_WIDTH-1:0] rs1_data_i,
    input wire[`DATA_WIDTH-1:0] less_result_i,

    output wire busy_o,
    output wire ready_o,
    output wire[`DATA_WIDTH-1:0] reg_wdata_o,

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

    localparam IF_IDLE       = 3'd0;
    localparam IF_CTRL_REQ   = 3'd1;
    localparam IF_CTRL_RSP   = 3'd2;
    localparam IF_STATUS_REQ = 3'd3;
    localparam IF_STATUS_RSP = 3'd4;
    localparam IF_TX_REQ     = 3'd5;
    localparam IF_TX_RSP     = 3'd6;
    localparam IF_DONE       = 3'd7;

    localparam UART_CTRL_ADDR   = 32'h3000_0000;
    localparam UART_STATUS_ADDR = 32'h3000_0004;
    localparam UART_TXDATA_ADDR = 32'h3000_000c;

    reg[2:0] state, state_next;
    reg[`DATA_WIDTH-1:0] rs1_data_r, rs1_data_next;
    reg[`DATA_WIDTH-1:0] reg_wdata_r, reg_wdata_next;

    wire req_hasked = rib_req_vld_o & rib_req_rdy_i;
    wire rsp_hasked = rib_rsp_vld_i & rib_rsp_rdy_o;
    wire uart_busy = rib_data_i[0];

    // less_result_i[0] == 1 表示 rs1 < x31
    // 因此 fire 条件是 rs1 >= x31
    wire fire_cond = ~less_result_i[0];

    always @(*) begin
        state_next = state;
        rs1_data_next = rs1_data_r;
        reg_wdata_next = reg_wdata_r;

        case (state)
            IF_IDLE: begin
                if (start_i) begin
                    rs1_data_next = rs1_data_i;

                    if (fire_cond) begin
                        // fire: 通过 UART 发送 rs1[7:0]，rd 写 0
                        reg_wdata_next = {`DATA_WIDTH{1'b0}};
                        state_next = IF_CTRL_REQ;
                    end else begin
                        // not fire: rd = rs1
                        reg_wdata_next = rs1_data_i;
                        state_next = IF_DONE;
                    end
                end
            end

            // 先写 UART_CTRL = 1，打开 TX 使能
            IF_CTRL_REQ: begin
                if (req_hasked) begin
                    state_next = IF_CTRL_RSP;
                end
            end

            IF_CTRL_RSP: begin
                if (rsp_hasked) begin
                    state_next = IF_STATUS_REQ;
                end
            end

            // 读 UART_STATUS，检查 TX 是否 busy
            IF_STATUS_REQ: begin
                if (req_hasked) begin
                    state_next = IF_STATUS_RSP;
                end
            end

            IF_STATUS_RSP: begin
                if (rsp_hasked) begin
                    if (uart_busy) begin
                        state_next = IF_STATUS_REQ;
                    end else begin
                        state_next = IF_TX_REQ;
                    end
                end
            end

            // 写 UART_TXDATA = rs1[7:0]
            IF_TX_REQ: begin
                if (req_hasked) begin
                    state_next = IF_TX_RSP;
                end
            end

            IF_TX_RSP: begin
                if (rsp_hasked) begin
                    state_next = IF_DONE;
                end
            end

            IF_DONE: begin
                if (accept_i) begin
                    state_next = IF_IDLE;
                end
            end

            default: begin
                state_next = IF_IDLE;
                rs1_data_next = {`DATA_WIDTH{1'b0}};
                reg_wdata_next = {`DATA_WIDTH{1'b0}};
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IF_IDLE;
            rs1_data_r <= {`DATA_WIDTH{1'b0}};
            reg_wdata_r <= {`DATA_WIDTH{1'b0}};
        end else begin
            state <= state_next;
            rs1_data_r <= rs1_data_next;
            reg_wdata_r <= reg_wdata_next;
        end
    end

    assign busy_o = (state != IF_IDLE) & (state != IF_DONE);
    assign ready_o = (state == IF_DONE);
    assign reg_wdata_o = reg_wdata_r;

    assign rib_addr_o =
        (state == IF_CTRL_REQ) ? UART_CTRL_ADDR :
        (state == IF_TX_REQ)   ? UART_TXDATA_ADDR :
                                 UART_STATUS_ADDR;

    assign rib_data_o =
        (state == IF_CTRL_REQ) ? 32'h0000_0001 :
                                 {24'b0, rs1_data_r[7:0]};

    assign rib_sel_o = 4'b0001;

    assign rib_req_vld_o =
        (state == IF_CTRL_REQ)   |
        (state == IF_STATUS_REQ) |
        (state == IF_TX_REQ);

    assign rib_rsp_rdy_o =
        (state == IF_CTRL_RSP)   |
        (state == IF_STATUS_RSP) |
        (state == IF_TX_RSP);

    assign rib_we_o =
        (state == IF_CTRL_REQ) |
        (state == IF_TX_REQ);

endmodule
