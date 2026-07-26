`include "../core00_wzc/marcos_wzc.v"

module rom #(
    parameter ROM_DEPTH = 256,
    parameter INST_WIDTH = 32,
    parameter ROM_ADDR_WIDTH = 8)(

    input wire clk,
    input wire rst_n,
    input wire[ROM_ADDR_WIDTH-1:0] addr_i,
    input wire[INST_WIDTH-1:0] data_i,
    input wire[3:0] sel_i,
    input wire we_i,
	  output wire[INST_WIDTH-1:0] data_o
    );

    gen_ram #(
        .DP(ROM_DEPTH),
        .DW(INST_WIDTH),
        .MW(4),
        .AW(ROM_ADDR_WIDTH)
    ) u_gen_ram(
        .clk(clk),
        .addr_i(addr_i),
        .data_i(data_i),
        .sel_i(sel_i),
        .we_i(we_i),
        .data_o(data_o)
    );

    // integer i;

    // initial begin
    //     for (i = 0; i < ROM_DEPTH; i = i + 1) begin
    //         u_gen_ram.ram[i] = 32'h1000_0000 + i;
    //     end
    // end

endmodule
