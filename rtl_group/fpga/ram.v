`include "../core00_wzc/marcos_wzc.v"

module ram #(
    parameter RAM_DEPTH = 16,
    parameter DATA_WIDTH = 32,
    parameter RAM_ADDR_WIDTH = 4)(

    input wire clk,
    input wire rst_n,
    input wire[RAM_ADDR_WIDTH-1:0] addr_i,
    input wire[DATA_WIDTH-1:0] data_i,
    input wire[3:0] sel_i,
    input wire we_i,
	  output wire[DATA_WIDTH-1:0] data_o
    );

    gen_ram #(
        .DP(RAM_DEPTH),
        .DW(DATA_WIDTH),
        .MW(4),
        .AW(RAM_ADDR_WIDTH)
    ) u_ram(
        .clk(clk),
        .addr_i(addr_i),
        .data_i(data_i),
        .sel_i(sel_i),
        .we_i(we_i),
        .data_o(data_o)
    );

    // integer i;

    // initial begin
    //     for (i = 0; i < RAM_DEPTH; i = i + 1) begin
    //         u_ram.ram[i] = 32'h2000_0000 + i;
    //     end
    // end

endmodule
