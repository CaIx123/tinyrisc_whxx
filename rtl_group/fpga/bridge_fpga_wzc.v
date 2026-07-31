`timescale 1ns / 1ps

`include "../top/macros.v"

module bridge_fpga_wzc(
    input wire clk,
    input wire rst_n,

    // kaisit soc interface
    input wire [`BRIDGE_WIDTH-1:0] rx_data_i,
    output reg [`BRIDGE_WIDTH-1:0] tx_data_o,

    // rom interface
    input wire [`INST_WIDTH-1:0] data_rom_i,
    output wire we_rom_o,
    output wire [3:0] sel_rom_o,
    output wire[`ROM_ADDR_WIDTH-1:0] addr_rom_o,
    output reg [`INST_WIDTH-1:0] data_rom_o,

    // exram interface
    input wire [`DATA_WIDTH-1:0] data_ram_i,
    output wire we_ram_o,
    output wire [3:0] sel_ram_o,
    output wire [`RAM_ADDR_WIDTH-1:0] addr_ram_o,
    output reg [`DATA_WIDTH-1:0] data_ram_o
);

  localparam TR_CTRL = 1;
  localparam TR_ADDR = 2;
  localparam TR_DATA = 3;

  reg [1:0] tr_state, tr_state_next;
  reg [`BRIDGE_WIDTH-1:0] ctrl_r, ctrl_next;
  reg [`ROM_ADDR_WIDTH-1:0] addr_r, addr_r_next;
  reg [3:0] tr_sel_mask, tr_sel_mask_next;

  wire tr_start = |rx_data_i[3:0];
  wire tr_dst = ctrl_r[7];              // 1: rom, 0: ram
  wire [1:0] tr_burst = ctrl_r[6:5];    // 11, 10, 01: burst, 00: single
  wire tr_mode = ctrl_r[4];             // 1: write, 0: read
  wire [3:0] tr_sel = ctrl_r[3:0];      // byte select
  wire [31:0] tr_data = tr_dst ? data_rom_i : data_ram_i;

  reg [1:0] burst_cnt, burst_cnt_next;

  wire tr_word_finish;
  wire tr_burst_finish;
  wire tr_finish;

  assign tr_word_finish = (tr_sel & tr_sel_mask) == 4'b0001 ||
                        (tr_sel & tr_sel_mask) == 4'b0010 ||
                        (tr_sel & tr_sel_mask) == 4'b0100 ||
                        (tr_sel & tr_sel_mask) == 4'b1000;
  assign tr_burst_finish = (burst_cnt == tr_burst) && tr_word_finish;                
  assign tr_finish = (tr_state == TR_DATA) && tr_burst_finish;

  always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tr_state <= TR_CTRL;
      ctrl_r <= {`BRIDGE_WIDTH{1'b0}};
      addr_r <= {`ROM_ADDR_WIDTH{1'b0}};
      tr_sel_mask <= 4'b1111;
      burst_cnt <= 2'b0;
    end else begin
      tr_state <= tr_state_next;
      ctrl_r <= ctrl_next;
      addr_r <= addr_r_next;
      tr_sel_mask <= tr_sel_mask_next;
      burst_cnt <= burst_cnt_next;
    end
  end

  // 状态转移逻辑
  always @(*) begin
    case (tr_state)
      TR_CTRL: tr_state_next = tr_start ? TR_ADDR : TR_CTRL;
      TR_ADDR: tr_state_next = TR_DATA;
      TR_DATA: tr_state_next = tr_finish ? TR_CTRL : TR_DATA;
      default: tr_state_next = TR_CTRL;
    endcase
  end

  // 丛发控制逻辑
  always @(*) begin
    case (tr_state)
      TR_CTRL: burst_cnt_next = 2'b0;
      TR_ADDR: burst_cnt_next = 2'b0;
      TR_DATA: burst_cnt_next = tr_word_finish ? burst_cnt + 1 : burst_cnt;
      default: burst_cnt_next = 2'b0;
    endcase
  end

  // tr_ctrl_r 控制逻辑
  always @ (*) begin
    if (tr_state == TR_CTRL && tr_start) begin
      ctrl_next = rx_data_i[`BRIDGE_WIDTH-1:0];
    end
    case (tr_state)
      TR_CTRL: begin
        if (tr_start) begin ctrl_next = rx_data_i[`BRIDGE_WIDTH-1:0]; end
        else begin ctrl_next = {`BRIDGE_WIDTH{1'b0}}; end
      end
      TR_ADDR: begin ctrl_next = ctrl_r; end
      TR_DATA: begin ctrl_next = ctrl_r; end
      default: ctrl_next = {`BRIDGE_WIDTH{1'b0}};
    endcase
  end

  // tr_addr_r 控制逻辑
  always @(*) begin
    case (tr_state)
      TR_CTRL: addr_r_next = {`ROM_ADDR_WIDTH{1'b0}};
      TR_ADDR: addr_r_next = rx_data_i[`ROM_ADDR_WIDTH-1:0];
      TR_DATA: addr_r_next = addr_r;
      default: addr_r_next = {`ROM_ADDR_WIDTH{1'b0}};
    endcase
  end

  // tr_sel_mask 控制逻辑
  always @(*) begin
    if (tr_state == TR_DATA && !tr_word_finish) begin
      casez (tr_sel & tr_sel_mask)
        4'b???1: tr_sel_mask_next = 4'b1110;
        4'b??10: tr_sel_mask_next = 4'b1100;
        4'b?100: tr_sel_mask_next = 4'b1000;
        4'b1000: tr_sel_mask_next = 4'b1111;
        default: tr_sel_mask_next = 4'b1111;
      endcase
    end else begin
      tr_sel_mask_next = 4'b1111;
    end
  end

  assign addr_rom_o = (tr_state == TR_ADDR) ? rx_data_i[`ROM_ADDR_WIDTH-1:0] :
                      (addr_r[`ROM_ADDR_WIDTH-1:0] + (tr_mode ? burst_cnt : burst_cnt_next));
  assign addr_ram_o = (tr_state == TR_ADDR) ? rx_data_i[`RAM_ADDR_WIDTH-1:0] :
                      (addr_r[`RAM_ADDR_WIDTH-1:0] + (tr_mode ? burst_cnt : burst_cnt_next));
  assign we_rom_o = (tr_state == TR_DATA && tr_mode && tr_dst) ? |(tr_sel & tr_sel_mask) : 1'b0;
  assign we_ram_o = (tr_state == TR_DATA && tr_mode && (~tr_dst)) ? |(tr_sel & tr_sel_mask) : 1'b0;
  assign sel_rom_o = (tr_state == TR_DATA && tr_dst) ? (tr_sel & tr_sel_mask) : 4'b0;
  assign sel_ram_o = (tr_state == TR_DATA && (~tr_dst)) ? (tr_sel & tr_sel_mask) : 4'b0;

  always @(*) begin
      tx_data_o = 0;
      casez (tr_sel & tr_sel_mask)
          4'b???1: begin 
              tx_data_o = tr_data [7:0];
              data_rom_o = {24'h0, rx_data_i[7:0]};
              data_ram_o = {24'h0, rx_data_i[7:0]};
          end
          4'b??10: begin
              tx_data_o = tr_data [15:8];
              data_rom_o = {16'h0, rx_data_i[7:0], 8'h0};
              data_ram_o = {16'h0, rx_data_i[7:0], 8'h0};
          end
          4'b?100: begin
              tx_data_o = tr_data [23:16];
              data_rom_o = {8'h0, rx_data_i[7:0], 16'h0};
              data_ram_o = {8'h0, rx_data_i[7:0], 16'h0};
          end 
          4'b1000: begin
              tx_data_o = tr_data [31:24];
              data_rom_o = {rx_data_i[7:0], 24'h0};
              data_ram_o = {rx_data_i[7:0], 24'h0};
          end
          default: begin
              tx_data_o = {`BRIDGE_WIDTH{1'b0}};
              data_rom_o = 32'h0;
              data_ram_o = 32'h0;
          end
      endcase

      if (tr_mode | (tr_state != TR_DATA)) begin
          tx_data_o = {`BRIDGE_WIDTH{1'b0}};
      end
  end


endmodule
