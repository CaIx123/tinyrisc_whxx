`timescale 1ns / 1ps

`include "../../macros.v"

module bridge_wzc(
    input wire clk,
    input wire rst_n,

    // rom interface
    input wire s0_req_vld_i,
    input wire s0_rsp_rdy_i,
    input wire s0_we_i,
    input wire [31:0] s0_addr_i,
    input wire [31:0] s0_data_i,
    input wire [3:0] s0_sel_i,
    output wire [31:0] s0_data_o,
    output wire s0_req_rdy_o,
    output wire s0_rsp_vld_o,

    // ram interface
    input wire s1_req_vld_i,
    input wire s1_rsp_rdy_i,
    input wire s1_we_i,
    input wire [31:0] s1_addr_i,
    input wire [31:0] s1_data_i,
    input wire [3:0] s1_sel_i,
    output wire [31:0] s1_data_o,
    output wire s1_req_rdy_o,
    output wire s1_rsp_vld_o,

    output reg [`BRIDGE_WIDTH-1:0] tx_data_o,
    input wire [`BRIDGE_WIDTH-1:0] rx_data_i
    );

  localparam TR_CTRL = 2'd0;
  localparam TR_ADDR = 2'd1;
  localparam TR_DATA = 2'd2;

  localparam TR_RAM = 1'b0;
  localparam TR_ROM = 1'b1;
  localparam TR_READ = 1'b0;
  localparam TR_WRITE = 1'b1;
  localparam [1:0] TR_SINGLE = 2'b00;
  localparam [1:0] TR_ROM_BURST = 2'b11;

  reg [1:0] tr_state, tr_state_next;
  reg tr_dst, tr_dst_next;              
  reg [1:0] tr_burst, tr_burst_next;
  reg tr_mode, tr_mode_next;
  reg [3:0] tr_sel, tr_sel_next;
  reg [`BRIDGE_WIDTH-1:0] tr_addr, tr_addr_next;
  reg [31:0] tr_wdata, tr_wdata_next;
  reg [3:0] tr_sel_mask, tr_sel_mask_next;
  reg [1:0] burst_cnt, burst_cnt_next;
  reg [31:0] data_r, data_next;
  reg rsp_vld_r, rsp_vld_next;
  reg rsp_dst_r, rsp_dst_next;

  wire tr_ready = (tr_state == TR_CTRL) & ~rsp_vld_r;
  wire accept_s1 = s1_req_vld_i & tr_ready;
  wire accept_s0 = s0_req_vld_i & ~s1_req_vld_i & tr_ready;
  wire accept_req = accept_s0 | accept_s1;

  // 组装ctrl信号
  wire req_dst = accept_s1 ? TR_RAM : TR_ROM;
  wire req_mode = accept_s1 ? s1_we_i : s0_we_i;
  wire [3:0] req_sel = accept_s1 ? s1_sel_i : s0_sel_i;
  wire [`BRIDGE_WIDTH-1:0] req_addr =
      accept_s1 ? s1_addr_i[`BRIDGE_WIDTH+1:2] : s0_addr_i[`BRIDGE_WIDTH+1:2];
  wire [31:0] req_wdata = accept_s1 ? s1_data_i : s0_data_i;
  wire req_rom_full_word_read = accept_s0 & ~s0_we_i & (s0_sel_i == 4'b1111);
  wire [1:0] req_burst =
      (`ROM_READ_BURST & req_rom_full_word_read) ? TR_ROM_BURST : TR_SINGLE;
  wire [`BRIDGE_WIDTH-1:0] req_ctrl = {req_dst, req_burst, req_mode, req_sel};

  wire [3:0] tr_sel_left = tr_sel & tr_sel_mask;
  wire tr_word_finish = (tr_sel_left == 4'b0001) |
                        (tr_sel_left == 4'b0010) |
                        (tr_sel_left == 4'b0100) |
                        (tr_sel_left == 4'b1000);
  wire tr_burst_finish = (burst_cnt == tr_burst) & tr_word_finish;
  wire tr_finish = (tr_state == TR_DATA) & tr_burst_finish;
  wire read_word_fire = (tr_state == TR_DATA) & ~tr_mode & tr_word_finish;
  wire rom_stream_fire = read_word_fire & (tr_dst == TR_ROM) & (tr_burst != TR_SINGLE);

  wire [31:0] assembled_data =
      tr_sel_left[0] ? {24'b0, rx_data_i} :
      tr_sel_left[1] ? {16'b0, rx_data_i, data_r[7:0]} :
      tr_sel_left[2] ? {8'b0, rx_data_i, data_r[15:0]} :
      tr_sel_left[3] ? {rx_data_i, data_r[23:0]} :
                       data_r;

  wire rsp_fire = rsp_vld_r &
                  ((rsp_dst_r == TR_ROM & s0_rsp_rdy_i) |
                   (rsp_dst_r == TR_RAM & s1_rsp_rdy_i));

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tr_state <= TR_CTRL;
      tr_dst <= TR_ROM;
      tr_burst <= TR_SINGLE;
      tr_mode <= TR_READ;
      tr_sel <= 4'b0000;
      tr_addr <= {`BRIDGE_WIDTH{1'b0}};
      tr_wdata <= 32'b0;
      tr_sel_mask <= 4'b1111;
      burst_cnt <= 2'b00;
      data_r <= 32'b0;
      rsp_vld_r <= 1'b0;
      rsp_dst_r <= TR_ROM;
    end else begin
      tr_state <= tr_state_next;
      tr_dst <= tr_dst_next;
      tr_burst <= tr_burst_next;
      tr_mode <= tr_mode_next;
      tr_sel <= tr_sel_next;
      tr_addr <= tr_addr_next;
      tr_wdata <= tr_wdata_next;
      tr_sel_mask <= tr_sel_mask_next;
      burst_cnt <= burst_cnt_next;
      data_r <= data_next;
      rsp_vld_r <= rsp_vld_next;
      rsp_dst_r <= rsp_dst_next;
    end
  end

  always @(*) begin
    tr_state_next = tr_state;
    case (tr_state)
      TR_CTRL: begin
        if (accept_req) begin
          tr_state_next = TR_ADDR;
        end
      end
      TR_ADDR: begin
        tr_state_next = TR_DATA;
      end
      TR_DATA: begin
        if (tr_finish) begin
          tr_state_next = TR_CTRL;
        end
      end
      default: begin
        tr_state_next = TR_CTRL;
      end
    endcase
  end

  // Transaction register next-state logic.
  always @(*) begin
    tr_dst_next = tr_dst;
    tr_burst_next = tr_burst;
    tr_mode_next = tr_mode;
    tr_sel_next = tr_sel;
    tr_addr_next = tr_addr;
    tr_wdata_next = tr_wdata;
    tr_sel_mask_next = tr_sel_mask;
    burst_cnt_next = burst_cnt;
    data_next = data_r;
    rsp_vld_next = rsp_vld_r;
    rsp_dst_next = rsp_dst_r;

    if (rsp_fire) begin
      rsp_vld_next = 1'b0;
    end

    case (tr_state)
      TR_CTRL: begin
        tr_sel_mask_next = 4'b1111;
        burst_cnt_next = 2'b00;
        data_next = 32'b0;

        if (accept_req) begin
          tr_dst_next = req_dst;
          tr_burst_next = req_burst;
          tr_mode_next = req_mode;
          tr_sel_next = req_sel;
          tr_addr_next = req_addr;
          tr_wdata_next = req_wdata;
        end
      end
      TR_ADDR: begin
        tr_sel_mask_next = 4'b1111;
        burst_cnt_next = 2'b00;
      end
      TR_DATA: begin
        if (tr_mode) begin
          data_next = tr_wdata;
        end else begin
          data_next = assembled_data;
          if (tr_word_finish & ~tr_burst_finish) begin
            data_next = 32'b0;
          end
        end

        if (tr_word_finish) begin
          tr_sel_mask_next = 4'b1111;
          burst_cnt_next = tr_burst_finish ? 2'b00 : (burst_cnt + 1'b1);
        end else begin
          casez (tr_sel_left)
            4'b???1: tr_sel_mask_next = 4'b1110;
            4'b??10: tr_sel_mask_next = 4'b1100;
            4'b?100: tr_sel_mask_next = 4'b1000;
            default: tr_sel_mask_next = 4'b1111;
          endcase
        end

        if (tr_finish && !rom_stream_fire) begin
          rsp_vld_next = 1'b1;
          rsp_dst_next = tr_dst;
        end
      end
      default: begin
        tr_sel_mask_next = 4'b1111;
        burst_cnt_next = 2'b00;
        data_next = 32'b0;
      end
    endcase
  end

  function [`BRIDGE_WIDTH-1:0] select_tx_byte;
    input [3:0] sel_left;
    input [31:0] wdata;
    begin
      casez (sel_left)
        4'b???1: select_tx_byte = wdata[7:0];
        4'b??10: select_tx_byte = wdata[15:8];
        4'b?100: select_tx_byte = wdata[23:16];
        4'b1000: select_tx_byte = wdata[31:24];
        default: select_tx_byte = {`BRIDGE_WIDTH{1'b0}};
      endcase
    end
  endfunction

  always @(*) begin
    tx_data_o = {`BRIDGE_WIDTH{1'b0}};

    case (tr_state)
      TR_CTRL: begin
        tx_data_o = accept_req ? req_ctrl : {`BRIDGE_WIDTH{1'b0}};
      end
      TR_ADDR: begin
        tx_data_o = tr_addr;
      end
      TR_DATA: begin
        if (tr_mode) begin
          tx_data_o = select_tx_byte(tr_sel_left, tr_wdata);
        end
      end
      default: begin
        tx_data_o = {`BRIDGE_WIDTH{1'b0}};
      end
    endcase
  end

  assign s0_data_o = rom_stream_fire ? assembled_data :
                     ((rsp_vld_r && rsp_dst_r == TR_ROM) ? data_r : 32'b0);
  assign s1_data_o = (rsp_vld_r && rsp_dst_r == TR_RAM) ? data_r : 32'b0;

  assign s0_req_rdy_o = accept_s0;
  assign s1_req_rdy_o = accept_s1;

  assign s0_rsp_vld_o = rom_stream_fire | (rsp_vld_r && rsp_dst_r == TR_ROM);
  assign s1_rsp_vld_o = rsp_vld_r && rsp_dst_r == TR_RAM;

endmodule
