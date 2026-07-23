`include "../tiny_macro.v"

module exram(
    input wire clk,
    input wire rst_n,

    input wire[3:0] we_i,                   // write enable
    input wire[`RAM_AWIDTH - 1:0] addr_i,    // addr
    input wire[32 - 1:0] data_i,

    output reg[32 - 1:0] data_o         // read data
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
        if (!rst_n) begin
            data_o = 32'b0;
        end else begin
            data_o = _ram[addr_i];
        end
    end

endmodule
