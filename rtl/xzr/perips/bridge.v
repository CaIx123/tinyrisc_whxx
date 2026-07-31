`include "../core/defines.v"


module bridge(
    input wire clk,
    input wire rst,
    // RIB 接口
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    input wire req_i,
    input wire we_i,
    output wire[31:0] data_o,
    output wire hold_flag_o,

    // 8-bit 总线
    output reg[7:0] tx_8bit,
    input wire[7:0] rx_8bit
);
    reg [23:0] data_temp;
    wire [7:0] data_h = (state == S_D3) ? rx_8bit:8'b0;
    assign data_o = {data_h,data_temp};
    
    localparam S_IDLE = 0, S_ADDR = 1, S_D0 = 2, S_D1 = 3, S_D2 = 4, S_D3 = 5;
    reg [2:0] state;

    // 只要有请求或不在空闲态，就拉住流水线
    assign hold_flag_o = (req_i || state != S_IDLE);

    wire is_ram = (addr_i[31:28] == 4'h1);
    wire [7:0] word_addr_low = addr_i[9:2];

    // 关键优化：组合逻辑输出第一个字节 (CMD)
    always @(*) begin
        if (state == S_IDLE && req_i)
            tx_8bit = {1'b1, we_i, is_ram, 5'b0}; // 立即发出 Start+WE+Target
        else if (state == S_ADDR)
            tx_8bit = word_addr_low;
        else if (we_i) begin // 写数据段
            case(state)
                S_D0: tx_8bit = data_i[7:0];
                S_D1: tx_8bit = data_i[15:8];
                S_D2: tx_8bit = data_i[23:16];
                S_D3: tx_8bit = data_i[31:24];
                default: tx_8bit = 8'h0;
            endcase
        end else tx_8bit = 8'h0;
    end

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            state <= S_IDLE;
            //data_o <= 0;
            data_temp <= 0;
        end else begin
            case (state)
                S_IDLE: if (req_i) state <= S_ADDR;
                S_ADDR: state <= S_D0;
                S_D0: begin data_temp[7:0]   <= rx_8bit; state <= S_D1; end     //data_o
                S_D1: begin data_temp[15:8]  <= rx_8bit; state <= S_D2; end
                S_D2: begin data_temp[23:16] <= rx_8bit; state <= S_D3; end
                S_D3: begin state <= S_IDLE; end
            endcase
        end
    end
endmodule