`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../perips/tiny_macro.v"

module tb_bridge_soc_smoke;

    reg clk;
    reg rst_n;

    wire uart_tx_pin;
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;

    wire[31:0] x2  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[2];
    wire[31:0] x3  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire[31:0] x4  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[4];
    wire[31:0] x6  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[6];
    wire[31:0] x7  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[7];
    wire[31:0] x8  = u_soc.u_tinyriscv_core.u_gpr_reg.regs[8];
    wire[31:0] x26 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire[31:0] x27 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[27];

    always #10 clk = ~clk;

    task checkpoint;
        input[127:0] name;
        input pass;
        begin
            if (pass) begin
                $display("BRIDGE_SOC_CHECKPOINT_PASS %0s x2=%h x3=%h x4=%h x6=%h x7=%h x8=%h ram0=%h ram1=%h ram2=%h",
                         name, x2, x3, x4, x6, x7, x8,
                         u_fpga.u_exram._ram[0], u_fpga.u_exram._ram[1], u_fpga.u_exram._ram[2]);
            end else begin
                $display("BRIDGE_SOC_CHECKPOINT_FAIL %0s x2=%h x3=%h x4=%h x6=%h x7=%h x8=%h ram0=%h ram1=%h ram2=%h",
                         name, x2, x3, x4, x6, x7, x8,
                         u_fpga.u_exram._ram[0], u_fpga.u_exram._ram[1], u_fpga.u_exram._ram[2]);
                $finish;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        // lui  x5, 0x10000
        // addi x1, x0, 7
        // sw   x1, 0(x5)
        // lw   x2, 0(x5)
        // addi x3, x2, 5
        // sw   x3, 4(x5)
        // lw   x4, 4(x5)
        // beq  x4, x3, +8
        // addi x6, x0, 99
        // add  x6, x2, x4
        // jal  x7, +8
        // addi x6, x0, 123
        // sw   x6, 8(x5)
        // lw   x8, 8(x5)
        // addi x26, x0, 1
        // addi x27, x0, 1
        // jal  x0, 0
        u_fpga.u_exrom._ram[0] = 32'h100002b7;
        u_fpga.u_exrom._ram[1] = 32'h00700093;
        u_fpga.u_exrom._ram[2] = 32'h0012a023;
        u_fpga.u_exrom._ram[3] = 32'h0002a103;
        u_fpga.u_exrom._ram[4] = 32'h00510193;
        u_fpga.u_exrom._ram[5] = 32'h0032a223;
        u_fpga.u_exrom._ram[6] = 32'h0042a203;
        u_fpga.u_exrom._ram[7] = 32'h00320463;
        u_fpga.u_exrom._ram[8] = 32'h06300313;
        u_fpga.u_exrom._ram[9] = 32'h00410333;
        u_fpga.u_exrom._ram[10] = 32'h008003ef;
        u_fpga.u_exrom._ram[11] = 32'h07b00313;
        u_fpga.u_exrom._ram[12] = 32'h0062a423;
        u_fpga.u_exrom._ram[13] = 32'h0082a403;
        u_fpga.u_exrom._ram[14] = 32'h00100d13;
        u_fpga.u_exrom._ram[15] = 32'h00100d93;
        u_fpga.u_exrom._ram[16] = 32'h0000006f;

        #100;
        rst_n = 1'b1;

        wait (x2 == 32'd7);
        #40;
        checkpoint("load_ram0", x2 == 32'd7 && u_fpga.u_exram._ram[0] == 32'd7);

        wait (x4 == 32'd12);
        #40;
        checkpoint("load_ram1", x3 == 32'd12 && x4 == 32'd12 &&
                                u_fpga.u_exram._ram[1] == 32'd12);

        wait (x7 == 32'h2c);
        #40;
        checkpoint("branch_jal", x6 == 32'd19 && x7 == 32'h2c);

        wait (x8 == 32'd19);
        #40;
        checkpoint("post_jump_mem", x8 == 32'd19 &&
                                    u_fpga.u_exram._ram[2] == 32'd19);

        wait (x26 == 32'h1);
        #200;

        if (x2 == 32'd7 &&
            x3 == 32'd12 &&
            x4 == 32'd12 &&
            x6 == 32'd19 &&
            x7 == 32'h2c &&
            x8 == 32'd19 &&
            x27 == 32'h1 &&
            u_fpga.u_exram._ram[0] == 32'd7 &&
            u_fpga.u_exram._ram[1] == 32'd12 &&
            u_fpga.u_exram._ram[2] == 32'd19) begin
            $display("BRIDGE_SOC_MEM_PASS x2=%h x3=%h x4=%h x6=%h x7=%h x8=%h ram0=%h ram1=%h ram2=%h",
                     x2, x3, x4, x6, x7, x8,
                     u_fpga.u_exram._ram[0], u_fpga.u_exram._ram[1], u_fpga.u_exram._ram[2]);
        end else begin
            $display("BRIDGE_SOC_MEM_FAIL x2=%h x3=%h x4=%h x6=%h x7=%h x8=%h x26=%h x27=%h ram0=%h ram1=%h ram2=%h",
                     x2, x3, x4, x6, x7, x8, x26, x27,
                     u_fpga.u_exram._ram[0], u_fpga.u_exram._ram[1], u_fpga.u_exram._ram[2]);
            $finish;
        end

        $finish;
    end

    initial begin
        #200000;
        $display("BRIDGE_SOC_MEM_TIMEOUT x2=%h x3=%h x4=%h x6=%h x7=%h x8=%h x26=%h x27=%h ram0=%h ram1=%h ram2=%h",
                 x2, x3, x4, x6, x7, x8, x26, x27,
                 u_fpga.u_exram._ram[0], u_fpga.u_exram._ram[1], u_fpga.u_exram._ram[2]);
        $finish;
    end

    tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst_ext_i(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .uart_debug_pin(1'b0),
        .PWM_out_pin(),
        .IIC_SDA_pin(),
        .IIC_SCL_pin(),
        .bridge_tx_o(bridge_tx),
        .bridge_rx_i(bridge_rx)
    );

    FPGA_top u_fpga(
        .clk(clk),
        .rst_n(rst_n),
        .tx_data_i(bridge_tx),
        .rx_data_o(bridge_rx)
    );

endmodule
