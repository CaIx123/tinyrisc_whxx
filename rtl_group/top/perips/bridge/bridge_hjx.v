`timescale 1ns / 1ps

`include "../../macros.v"
module bridge_hjx(
    input wire clk,
    input wire rst_n,

    // exrom interface
    input wire s0_req_vld_i,
    input wire s0_rsp_rdy_i,
    input wire s0_we_i,
    input wire[31:0] s0_addr_i,
    input wire[31:0] s0_data_i,
    input wire[3:0] s0_sel_i,
    output wire[31:0] s0_data_o,
    output wire s0_req_rdy_o,
    output wire s0_rsp_vld_o,

    // exram interface
    input wire s1_req_vld_i,
    input wire s1_rsp_rdy_i,
    input wire s1_we_i,
    input wire[31:0] s1_addr_i,
    input wire[31:0] s1_data_i,
    input wire[3:0] s1_sel_i,
    output wire[31:0] s1_data_o,
    output wire s1_req_rdy_o,
    output wire s1_rsp_vld_o,

    output reg[`PWIDTH_O-1:0] tx_data_o,
    input wire[`PWIDTH_I-1:0] rx_data_i
    );
    wire transfer_done;
    wire transfer_ready;
    reg transfer_busy;
    wire[`EXCTRL_WIDTH-1:0] transfer_ctrl;
    wire req_vld = s0_req_vld_i | s1_req_vld_i;

    assign transfer_ready = ~transfer_busy;
    assign transfer_ctrl = (transfer_ready && req_vld) ? {
                        ~s1_req_vld_i,
                        2'b0,
                        s1_req_vld_i ? s1_we_i : s0_we_i,
                        s1_req_vld_i ? s1_sel_i : s0_sel_i} : 0;

    wire[27:0] rom_addr = s0_addr_i[`PWIDTH_O + 1:2];
    wire[27:0] ram_addr = s1_addr_i[`PWIDTH_O + 1:2];
    reg[`EXCTRL_WIDTH-1:0] ctrl_reg;
    reg[`EX_AWIDTH-1:0] addr_reg;
    reg[31:0] data_reg;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transfer_busy <= 0;
            ctrl_reg <= 0;
            addr_reg <= 0;
            data_reg <= 0;
        end else begin
            if(req_vld && transfer_ready) begin
                ctrl_reg <= transfer_ctrl;
                addr_reg <= s1_req_vld_i ? ram_addr : rom_addr;
                data_reg <= s1_req_vld_i ? s1_data_i : s0_data_i;
            end
            if(transfer_done) begin
                transfer_busy <= 0;
            end else if(transfer_ready) begin
                transfer_busy <= req_vld;
            end
        end
    end

    // transmission logic
    localparam STATE_CTRL = 0;
    localparam STATE_ADDR = 1;
    localparam STATE_DATA = 2;

    reg[1:0] state;
    reg[1:0] state_next;

    reg [31:0] rx_data_reg, rx_data;
    wire mem_slt = ctrl_reg[7];             // 1: rom, 0: ram
    wire[3:0] byte_sel = ctrl_reg[3:0];
    reg[3:0] byte_sel_mask;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_CTRL;
        end else begin
            state <= state_next;
        end
    end

    always @(*) begin
        case (state)
            STATE_CTRL: begin
                state_next = req_vld ? STATE_ADDR : STATE_CTRL;
            end
            STATE_ADDR: begin
                state_next = STATE_DATA;
            end
            STATE_DATA: begin
                state_next = transfer_done ? STATE_CTRL : STATE_DATA;
            end
            default: begin
                state_next = STATE_CTRL;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_sel_mask <= 4'b1111;
        end else begin
            if(state == STATE_DATA) begin
                casez(byte_sel & byte_sel_mask)
                    4'b???1: byte_sel_mask <= 4'b1110;
                    4'b??10: byte_sel_mask <= 4'b1100;
                    4'b?100: byte_sel_mask <= 4'b1000;
                    4'b1000: byte_sel_mask <= 4'b1111;
                    default: byte_sel_mask <= 4'b1111;
                endcase
            end else begin
                byte_sel_mask <= 4'b1111;
            end
        end
    end
    assign transfer_done =  (state == STATE_DATA) &&
                   ((byte_sel & byte_sel_mask) == 4'b0001 ||
                    (byte_sel & byte_sel_mask) == 4'b0010 ||
                    (byte_sel & byte_sel_mask) == 4'b0100 ||
                    (byte_sel & byte_sel_mask) == 4'b1000 );

    // tx data_o
    always @(*) begin
        case (state)
            STATE_CTRL: begin
                tx_data_o = transfer_ctrl;
            end
            STATE_ADDR: begin
                tx_data_o = addr_reg;
            end
            STATE_DATA: begin
                casez (byte_sel & byte_sel_mask)
                    4'b???1: tx_data_o = data_reg[7:0];
                    4'b??10: tx_data_o = data_reg[15:8];
                    4'b?100: tx_data_o = data_reg[23:16];
                    4'b1000: tx_data_o = data_reg[31:24];
                    default: tx_data_o = 0;
                endcase
            end
            default: begin
                tx_data_o = transfer_ctrl;
            end
        endcase
    end

    // rx data_i
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_reg <= 0;
        end else begin
            if(state == STATE_DATA) begin
                casez(byte_sel & byte_sel_mask)
                    4'b???1: rx_data_reg <= {24'b0, rx_data_i};
                    4'b??10: rx_data_reg <= {16'b0, rx_data_i, rx_data_reg[7:0]};
                    4'b?100: rx_data_reg <= {8'b0, rx_data_i, rx_data_reg[15:0]};
                    4'b1000: rx_data_reg <= 0;
                    default: rx_data_reg <= 0;
                endcase
            end else begin
                rx_data_reg <= 0;
            end
        end
    end
    always @(*) begin
        casez(byte_sel & byte_sel_mask)
            4'b???1: rx_data = {rx_data_reg[31:8], rx_data_i[7:0]};
            4'b??10: rx_data = {rx_data_reg[31:16], rx_data_i[7:0], rx_data_reg[7:0]};
            4'b?100: rx_data = {rx_data_reg[31:24], rx_data_i[7:0], rx_data_reg[15:0]};
            4'b1000: rx_data = {rx_data_i[7:0], rx_data_reg[23:0]};
            default: rx_data = rx_data_reg;
        endcase
    end
    assign s0_data_o = mem_slt ? rx_data : 0;
    assign s1_data_o = (~mem_slt) ? rx_data : 0;
    // handshakes
    // rsp_rdy is always 1
    assign s0_req_rdy_o = ~s1_req_vld_i && transfer_ready;
    assign s1_req_rdy_o = transfer_ready;
    assign s0_rsp_vld_o = (mem_slt) ? transfer_done : 0;
    assign s1_rsp_vld_o = (~mem_slt) ? transfer_done : 0;

endmodule
