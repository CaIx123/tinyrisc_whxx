module vld_rdy #(
    parameter CUT_READY = 0)(

    input wire clk,
    input wire rst_n,

    input wire vld_i,
    output wire rdy_o,
    input wire rdy_i,
    output wire vld_o

    );

    wire vld_set;
    wire vld_clr;
    wire vld_ena;
    wire vld_r;
    wire vld_nxt;

    // The valid will be set when input handshaked
    assign vld_set = vld_i & rdy_o;
    // The valid will be clr when output handshaked
    assign vld_clr = vld_o & rdy_i;

    assign vld_ena = vld_set | vld_clr;
    assign vld_nxt = vld_set | (~vld_clr);

    gen_en_dff #(1) vld_dff(clk, rst_n, vld_ena, vld_nxt, vld_r);

    assign vld_o = vld_r;

    if (CUT_READY == 1) begin
        // If cut ready, then only accept when stage is not full
        assign rdy_o = (~vld_r);
    end else begin
        // If not cut ready, then can accept when stage is not full or it is popping 
        assign rdy_o = (~vld_r) | vld_clr;
    end

endmodule
