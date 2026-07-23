`timescale 1 ns / 1 ps

`include "defines.v"

module tinyriscv_readtemp_tb;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;
    wire uart_tx_pin;
    wire succ;
    wire [2:0] pwm_o;
    tri1 iic_scl;
    tri1 iic_sda;

    wire [31:0] x3 = tinyriscv_readtemp_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire [31:0] x26 = tinyriscv_readtemp_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire [31:0] x27 = tinyriscv_readtemp_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];

    integer r;

    always #10 clk = ~clk;

    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_readtemp_tb);
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b0;
        $display("test running...");
        #100;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        #200;

        wait (x26 == 32'h1)
        #400;
        if (x27 == 32'h1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1) begin
                $display("x%2d = 0x%x", r, tinyriscv_readtemp_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[r]);
            end
        end

        $finish;
    end

    initial begin
        #5000000;
        $display("Time Out.");
        $finish;
    end

    initial begin
        $readmemh("inst.data", tinyriscv_readtemp_tb_0.u_exmem_top.u_exrom._ram);
    end

    tinyriscv_sys_top tinyriscv_readtemp_tb_0(
        .clk(clk),
        .rst(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(~uart_debug_pin),
        .succ(succ),
        .pwm_o(pwm_o),
        .iic_scl(iic_scl),
        .iic_sda(iic_sda)
    );

    lm75 u_lm75(
        .clk(clk),
        .rst(~rst_n),
        .iic_scl(iic_scl),
        .iic_sda(iic_sda)
    );

endmodule
