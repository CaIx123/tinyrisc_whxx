`include "../tiny_macro.v"

// 外部RAM模型
// 与exrom类似，采用32bit字数组存储，支持按字节写
// 组合逻辑读出，复位时输出0
module exram(
    input wire clk,                          // 时钟
    input wire rst,                          // 复位(高有效)

    input wire[3:0] we_i,                    // 字节写使能
    input wire[`RAM_AWIDTH - 1:0] addr_i,    // 地址
    input wire[32 - 1:0] data_i,             // 写数据

    output reg[32 - 1:0] data_o              // 读数据
);

    reg[31:0] _ram[0:`RAM_DEPTH - 1];


    always @ (posedge clk) begin
        if (we_i[0]) begin
            _ram[addr_i][7:0] <= data_i[7:0];
        end
        if (we_i[1]) begin
            _ram[addr_i][15:8] <= data_i[15:8];
        end
        if (we_i[2]) begin
            _ram[addr_i][23:16] <= data_i[23:16];
        end
        if (we_i[3]) begin
            _ram[addr_i][31:24] <= data_i[31:24];
        end
    end

    always @ (*) begin
        if (rst == 1'b1) begin
            data_o = 32'b0;
        end else begin
            data_o = _ram[addr_i];
        end
    end

endmodule
