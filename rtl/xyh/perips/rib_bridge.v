



















































































































































































































































































































































































































































`include "../tiny_macro.v"

// 片上-片外桥接模块(RIB侧)
// 将片上RIB总线对外部ROM/RAM的32bit访问转为8bit宽串行事务
// 事务流程：发送控制字节(含目标存储体/读写方向/字节掩码) -> 发送地址 -> 发送/接收数据
// 与ex_bridge成对工作，共同实现片外存储访问
module rib_bridge(
    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)

    // exrom interface (rib slave 0)
    input wire s0_req_vld_i,                 // ROM请求有效
    input wire s0_rsp_rdy_i,                 // ROM响应就绪
    input wire s0_we_i,                      // ROM写使能
    input wire[31:0] s0_addr_i,              // ROM地址
    input wire[31:0] s0_data_i,              // ROM写数据
    input wire[3:0] s0_sel_i,                // ROM字节选择
    output wire[31:0] s0_data_o,             // ROM读数据
    output wire s0_req_rdy_o,                // ROM请求就绪
    output wire s0_rsp_vld_o,                // ROM响应有效

    // exram interface (rib slave 1)
    input wire s1_req_vld_i,                 // RAM请求有效
    input wire s1_rsp_rdy_i,                 // RAM响应就绪
    input wire s1_we_i,                      // RAM写使能
    input wire[31:0] s1_addr_i,              // RAM地址
    input wire[31:0] s1_data_i,              // RAM写数据
    input wire[3:0] s1_sel_i,                // RAM字节选择
    output wire[31:0] s1_data_o,             // RAM读数据
    output wire s1_req_rdy_o,                // RAM请求就绪
    output wire s1_rsp_vld_o,                // RAM响应有效

    output reg[`PWIDTH_O-1:0] tx_data_o,     // 发往片外的串行数据
    input wire[`PWIDTH_I-1:0] rx_data_i      // 来自片外的串行数据
    );
    // tr reg
    wire tr_fn;
    wire tr_ready;
    reg tr_valid;
    wire [`EXCTRL_WIDTH-1:0] tr_ctrl; 
    wire req_vld = s0_req_vld_i | s1_req_vld_i;
    assign tr_ready = ~tr_valid;
    assign tr_ctrl = tr_ready ? {  
                        ~s1_req_vld_i, 
                        2'b0, 
                        s1_req_vld_i ? s1_we_i : s0_we_i, 
                        s1_req_vld_i ? s1_sel_i : s0_sel_i} : 0;

    wire[27:0] rom_addr = s0_addr_i[`PWIDTH_O + 1:2];
    wire[27:0] ram_addr = s1_addr_i[`PWIDTH_O + 1:2];
    // tr regs
    reg[`EXCTRL_WIDTH-1:0] ctrl_reg;
    reg[`EX_AWIDTH-1:0] addr_reg;
    reg[31:0] data_reg;
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            tr_valid <= 0;
            ctrl_reg <= 0;
            addr_reg <= 0;
            data_reg <= 0;
        end else begin
            if(req_vld && tr_ready) begin
                ctrl_reg <= tr_ctrl;
                addr_reg <= s1_req_vld_i ? ram_addr : rom_addr;
                data_reg <= s1_req_vld_i ? s1_data_i : s0_data_i;
            end
            if(tr_fn) begin
                tr_valid <= 0;
            end else if(tr_ready) begin
                tr_valid <= req_vld;
            end
        end
    end

    // transmission logic
    localparam TR_CTRL = 0, TR_ADDR = 1, TR_DATA = 2;
    reg [1:0] tr_state, next_tr_state;

    reg [31:0] rx_data_reg, rx_data;
    wire mem_slt = ctrl_reg[7];     // 1: rom, 0: ram
    wire tr_dir = ctrl_reg[4];      // 1: write, 0: read
    wire [3:0] byte_sel = ctrl_reg[3:0];  // byte_sel
    reg [3:0] byte_sel_bitmask;
    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            tr_state <= TR_CTRL;
        end else begin
            tr_state <= next_tr_state;
        end
    end

    always @(*) begin
        case (tr_state)
            TR_CTRL: next_tr_state = req_vld ? TR_ADDR : TR_CTRL;
            TR_ADDR: next_tr_state = TR_DATA;
            TR_DATA: next_tr_state = tr_fn ? TR_CTRL : TR_DATA;
            default: next_tr_state = TR_CTRL;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_sel_bitmask <= 4'b1111;
        end else begin
            if(tr_state == TR_DATA) begin
                casez(byte_sel & byte_sel_bitmask) 
                    4'b???1: byte_sel_bitmask <= 4'b1110;
                    4'b??10: byte_sel_bitmask <= 4'b1100;
                    4'b?100: byte_sel_bitmask <= 4'b1000;
                    4'b1000: byte_sel_bitmask <= 4'b1111;
                    default: byte_sel_bitmask <= 4'b1111;
                endcase
            end 
            else byte_sel_bitmask <= 4'b1111;
        end
    end
    assign tr_fn =  (tr_state == TR_DATA) && 
                   ((byte_sel & byte_sel_bitmask) == 4'b0001 ||
                    (byte_sel & byte_sel_bitmask) == 4'b0010 ||
                    (byte_sel & byte_sel_bitmask) == 4'b0100 ||
                    (byte_sel & byte_sel_bitmask) == 4'b1000 );

    // tx data_o
    always @(*) begin
        case (tr_state)
            TR_CTRL: begin
                tx_data_o = tr_ctrl;
            end
            TR_ADDR: begin
                tx_data_o = addr_reg;
            end
            TR_DATA: begin
                casez (byte_sel & byte_sel_bitmask)
                    4'b???1: tx_data_o = data_reg[7:0];
                    4'b??10: tx_data_o = data_reg[15:8];
                    4'b?100: tx_data_o = data_reg[23:16];
                    4'b1000: tx_data_o = data_reg[31:24]; 
                    default: tx_data_o = 0;
                endcase
            end
            default: tx_data_o = tr_ctrl;
        endcase
    end

    // rx data_i
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data_reg <= 0;
        end else begin
            if(tr_state == TR_DATA) begin
                casez(byte_sel & byte_sel_bitmask) 
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
        casez(byte_sel & byte_sel_bitmask) 
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
    assign s0_req_rdy_o = ~s1_req_vld_i && tr_ready;
    assign s1_req_rdy_o = tr_ready;
    assign s0_rsp_vld_o = (mem_slt) ? tr_fn : 0;
    assign s1_rsp_vld_o = (~mem_slt) ? tr_fn : 0;

endmodule