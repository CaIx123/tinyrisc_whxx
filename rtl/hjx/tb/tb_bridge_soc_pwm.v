`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../perips/tiny_macro.v"

module tb_bridge_soc_pwm;

    reg clk;
    reg rst_n;

    wire uart_tx_pin;
    wire[3:0] pwm_out_pin;

    wire[31:0] x2  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[2];
    wire[31:0] x3  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire[31:0] x4  = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[4];
    wire[31:0] x26 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire[31:0] x27 = u_fpga_soc.u_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];

    integer i;
    integer pwm0_high_cnt;
    integer pwm0_low_cnt;

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        pwm0_high_cnt = 0;
        pwm0_low_cnt = 0;

        // lui  x5, 0x60000       // A0: 0x6000_0000
        // lui  x6, 0x60100       // B0: 0x6010_0000
        // lui  x7, 0x60040       // C : 0x6004_0000
        // addi x1, x0, 4
        // sw   x1, 0(x5)
        // addi x1, x0, 2
        // sw   x1, 0(x6)
        // addi x1, x0, 1
        // sw   x1, 0(x7)
        // lw   x2, 0(x5)
        // lw   x3, 0(x6)
        // lw   x4, 0(x7)
        // addi x26, x0, 1
        // addi x27, x0, 1
        // jal  x0, 0
        u_fpga_soc.u_fpga_top.u_exrom._ram[0]  = 32'h600002b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[1]  = 32'h60100337;
        u_fpga_soc.u_fpga_top.u_exrom._ram[2]  = 32'h600403b7;
        u_fpga_soc.u_fpga_top.u_exrom._ram[3]  = 32'h00400093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[4]  = 32'h0012a023;
        u_fpga_soc.u_fpga_top.u_exrom._ram[5]  = 32'h00200093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[6]  = 32'h00132023;
        u_fpga_soc.u_fpga_top.u_exrom._ram[7]  = 32'h00100093;
        u_fpga_soc.u_fpga_top.u_exrom._ram[8]  = 32'h0013a023;
        u_fpga_soc.u_fpga_top.u_exrom._ram[9]  = 32'h0002a103;
        u_fpga_soc.u_fpga_top.u_exrom._ram[10] = 32'h00032183;
        u_fpga_soc.u_fpga_top.u_exrom._ram[11] = 32'h0003a203;
        u_fpga_soc.u_fpga_top.u_exrom._ram[12] = 32'h00100d13;
        u_fpga_soc.u_fpga_top.u_exrom._ram[13] = 32'h00100d93;
        u_fpga_soc.u_fpga_top.u_exrom._ram[14] = 32'h0000006f;

        #100;
        rst_n = 1'b1;

        wait (x26 == 32'h1);

        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            if (pwm_out_pin[0]) begin
                pwm0_high_cnt = pwm0_high_cnt + 1;
            end else begin
                pwm0_low_cnt = pwm0_low_cnt + 1;
            end
        end

        if (x2 == 32'd4 &&
            x3 == 32'd2 &&
            x4 == 32'd1 &&
            x27 == 32'h1 &&
            u_fpga_soc.u_soc_top.u_pwm.pwm_a0 == 32'd4 &&
            u_fpga_soc.u_soc_top.u_pwm.pwm_b0 == 32'd2 &&
            u_fpga_soc.u_soc_top.u_pwm.pwm_c[0] == 1'b1 &&
            pwm0_high_cnt != 0 &&
            pwm0_low_cnt != 0) begin
            $display("BRIDGE_SOC_PWM_PASS x2=%h x3=%h x4=%h pwm_a0=%h pwm_b0=%h pwm_c=%h high=%0d low=%0d",
                     x2, x3, x4, u_fpga_soc.u_soc_top.u_pwm.pwm_a0, u_fpga_soc.u_soc_top.u_pwm.pwm_b0,
                     u_fpga_soc.u_soc_top.u_pwm.pwm_c, pwm0_high_cnt, pwm0_low_cnt);
        end else begin
            $display("BRIDGE_SOC_PWM_FAIL x2=%h x3=%h x4=%h x26=%h x27=%h pwm_a0=%h pwm_b0=%h pwm_c=%h pwm_out=%b high=%0d low=%0d",
                     x2, x3, x4, x26, x27, u_fpga_soc.u_soc_top.u_pwm.pwm_a0, u_fpga_soc.u_soc_top.u_pwm.pwm_b0,
                     u_fpga_soc.u_soc_top.u_pwm.pwm_c, pwm_out_pin, pwm0_high_cnt, pwm0_low_cnt);
            $finish;
        end

        $finish;
    end

    initial begin
        #200000;
        $display("BRIDGE_SOC_PWM_TIMEOUT x2=%h x3=%h x4=%h x26=%h x27=%h pwm_a0=%h pwm_b0=%h pwm_c=%h pwm_out=%b",
                 x2, x3, x4, x26, x27, u_fpga_soc.u_soc_top.u_pwm.pwm_a0, u_fpga_soc.u_soc_top.u_pwm.pwm_b0,
                 u_fpga_soc.u_soc_top.u_pwm.pwm_c, pwm_out_pin);
        $finish;
    end

    tinyriscv_soc_fpga_top u_fpga_soc(
        .clk(clk),
        .rst_ext_i(rst_n),
        .succ(),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .uart_debug_pin(1'b0),
        .PWM_out_pin(pwm_out_pin),
        .IIC_SDA_pin(),
        .IIC_SCL_pin()
    );

endmodule
