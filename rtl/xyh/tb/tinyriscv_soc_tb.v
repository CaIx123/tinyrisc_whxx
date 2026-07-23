`timescale 1 ns / 1 ps

`include "defines.v"

// select one option only
`define TEST_PROG  1

// testbench module
module tinyriscv_soc_tb;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;
    wire uart_tx_pin;

    always #10 clk = ~clk;     // 50MHz

    wire[31:0] x3 = tinyriscv_soc_top_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire[31:0] x26 = tinyriscv_soc_top_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire[31:0] x27 = tinyriscv_soc_top_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];

    integer r;


    initial begin
        clk = 0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b0;
        $display("test running...");
        #100
        rst_n = 1'b0;
        #100
        rst_n = 1'b1;
        #200

`ifdef TEST_PROG
        wait(x26 == 32'b1)   // wait sim end, when x26 == 1
        #400
        if (x27 == 32'b1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~ #####     ##     ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #    #   #  #   #       #     ~~~~~~~~~");
            $display("~~~~~~~~~ #    #  #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~ #####   ######       #       #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #  #    #  #    #~~~~~~~~~");
            $display("~~~~~~~~~ #       #    #   ####    #### ~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("~~~~~~~~~~######    ##       #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#        #  #      #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#####   #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       ######     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    #     ~~~~~~~~~~");
            $display("~~~~~~~~~~#       #    #     #    ######~~~~~~~~~~");
            $display("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1)
                $display("x%2d = 0x%x", r, tinyriscv_soc_top_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[r]);
        end
`endif


        $finish;
    end

    // sim timeout
    initial begin
        #1000000
        $display("Time Out.");
        $finish;
    end

    // read mem data
    initial begin
        $readmemh ("inst.data", tinyriscv_soc_top_0.u_exmem_top.u_exrom._ram);
    end

    // generate wave file, used by gtkwave
    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_soc_tb);
    end

    tinyriscv_sys_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(~uart_debug_pin)
    );

endmodule
