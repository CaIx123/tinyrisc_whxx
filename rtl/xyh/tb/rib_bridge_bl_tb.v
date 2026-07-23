`timescale 1ns / 1ps

`include "../rtl/tiny_macro.v"

module rib_bridge_bl_tb;

    reg clk;
    reg rst;

    reg s0_req_vld_i;
    reg s0_rsp_rdy_i;
    reg s0_we_i;
    reg [31:0] s0_addr_i;
    reg [31:0] s0_data_i;
    reg [3:0] s0_sel_i;
    wire [31:0] s0_data_o;
    wire s0_req_rdy_o;
    wire s0_rsp_vld_o;

    reg s1_req_vld_i;
    reg s1_rsp_rdy_i;
    reg s1_we_i;
    reg [31:0] s1_addr_i;
    reg [31:0] s1_data_i;
    reg [3:0] s1_sel_i;
    wire [31:0] s1_data_o;
    wire s1_req_rdy_o;
    wire s1_rsp_vld_o;

    wire [`PWIDTH_O-1:0] tx_data_o;
    wire [`PWIDTH_I-1:0] rx_data_i;

    reg [31:0] expect_data;

    rib_bridge u_rib_bridge_bl(
        .clk(clk),
        .rst(rst),
        .s0_req_vld_i(s0_req_vld_i),
        .s0_rsp_rdy_i(s0_rsp_rdy_i),
        .s0_we_i(s0_we_i),
        .s0_addr_i(s0_addr_i),
        .s0_data_i(s0_data_i),
        .s0_sel_i(s0_sel_i),
        .s0_data_o(s0_data_o),
        .s0_req_rdy_o(s0_req_rdy_o),
        .s0_rsp_vld_o(s0_rsp_vld_o),
        .s1_req_vld_i(s1_req_vld_i),
        .s1_rsp_rdy_i(s1_rsp_rdy_i),
        .s1_we_i(s1_we_i),
        .s1_addr_i(s1_addr_i),
        .s1_data_i(s1_data_i),
        .s1_sel_i(s1_sel_i),
        .s1_data_o(s1_data_o),
        .s1_req_rdy_o(s1_req_rdy_o),
        .s1_rsp_vld_o(s1_rsp_vld_o),
        .tx_data_o(tx_data_o),
        .rx_data_i(rx_data_i)
    );

    exmem_top u_exmem_top(
        .clk(clk),
        .rst(rst),
        .tx_data_i(tx_data_o),
        .rx_data_o(rx_data_i)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // initial begin
    //     $dumpfile("rib_bridge_bl_tb.vcd");
    //     $dumpvars(0, rib_bridge_bl_tb);
    // end

    always @(posedge clk) begin
        if (!rst && s0_req_vld_i && s1_req_vld_i) begin
            $display("ERROR: s0_req_vld_i and s1_req_vld_i are both high at time %0t", $time);
            $fatal(1);
        end
    end

    task clear_requests;
        begin
            s0_req_vld_i = 1'b0;
            s0_rsp_rdy_i = 1'b1;
            s0_we_i = 1'b0;
            s0_addr_i = 32'h0;
            s0_data_i = 32'h0;
            s0_sel_i = 4'h0;

            s1_req_vld_i = 1'b0;
            s1_rsp_rdy_i = 1'b1;
            s1_we_i = 1'b0;
            s1_addr_i = 32'h0;
            s1_data_i = 32'h0;
            s1_sel_i = 4'h0;
        end
    endtask

    task init_external_mem;
        begin
            u_exmem_top.u_exrom._ram[0] = 32'h11223344;
            u_exmem_top.u_exrom._ram[1] = 32'h55667788;
            u_exmem_top.u_exram._ram[0] = 32'h00000000;
            u_exmem_top.u_exram._ram[1] = 32'hA5A5A5A5;
        end
    endtask

    task do_s0_read;
        input [31:0] addr;
        input [3:0] sel;
        input [31:0] expected;
        begin
            @(posedge clk);
            expect_data = expected;
            s0_we_i = 1'b0;
            s0_addr_i = addr;
            s0_data_i = 32'h0;
            s0_sel_i = sel;
            s0_req_vld_i = 1'b1;
            @(posedge clk);
            wait (s0_rsp_vld_o == 1'b1);
            if (s0_data_o !== expect_data) begin
                $display("ERROR: s0 read mismatch at time %0t, got %h expect %h", $time, s0_data_o, expect_data);
            end
            s0_req_vld_i = 1'b0;
            s0_sel_i = 4'h0;
        end
    endtask

    task do_s1_write;
        input [31:0] addr;
        input [3:0] sel;
        input [31:0] data;
        begin
            @(posedge clk);
            s1_we_i = 1'b1;
            s1_addr_i = addr;
            s1_data_i = data;
            s1_sel_i = sel;
            s1_req_vld_i = 1'b1;
            @(posedge clk);
            wait (s1_rsp_vld_o == 1'b1);
            s1_req_vld_i = 1'b0;
            s1_we_i = 1'b0;
            s1_sel_i = 4'h0;
        end
    endtask

    task do_s1_read;
        input [31:0] addr;
        input [3:0] sel;
        input [31:0] expected;
        begin
            @(posedge clk);
            expect_data = expected;
            s1_we_i = 1'b0;
            s1_addr_i = addr;
            s1_data_i = 32'h0;
            s1_sel_i = sel;
            s1_req_vld_i = 1'b1;
            @(posedge clk);
            wait (s1_rsp_vld_o == 1'b1);
            if (s1_data_o !== expect_data) begin
                $display("ERROR: s1 read mismatch at time %0t, got %h expect %h", $time, s1_data_o, expect_data);
            end
            s1_req_vld_i = 1'b0;
            s1_sel_i = 4'h0;
        end
    endtask

    initial begin
        clear_requests();
        rst = 1'b1;
        repeat (4) @(posedge clk);
        init_external_mem();
        rst = 1'b0;
        repeat (2) @(posedge clk);

        do_s0_read(32'h0000_0000, 4'b1111, 32'h11223344);
        do_s0_read(32'h0000_0000, 4'b0011, 32'h00003344);

        do_s1_write(32'h0000_0000, 4'b1111, 32'hDEADBEEF);
        do_s1_read(32'h0000_0000, 4'b1111, 32'hDEADBEEF);

        do_s1_write(32'h0000_0004, 4'b0011, 32'h0000ABCD);
        do_s1_read(32'h0000_0004, 4'b0011, 32'h0000ABCD);

        repeat (10) @(posedge clk);
        $display("rib_bridge_bl_tb PASS");
    end

endmodule

