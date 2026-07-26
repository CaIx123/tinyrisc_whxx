`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../macros.v"

module tb_bridge_soc_if;

    localparam integer UART_BIT_CYCLES = 434;

    reg clk;
    reg rst_n;

    wire uart_tx_pin;
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;

    wire[31:0] x30 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[30];
    wire[31:0] x31 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[31];

    reg[7:0] got;

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        got = 8'h0;

        // IF.dump:
        // lui  a5, 0x30000      // UART base
        // li   a4, 1
        // sw   a4, 0(a5)        // UART_CTRL = 1
        // addi x31, x0, 128     // Vth
        // add  x30, x0, x0      // Vmem = 0
        // IF   x30, x30, 0x0a   // x30 = 10
        // IF   x30, x30, 0x1a   // x30 = 36
        // IF   x30, x30, 0x3a   // x30 = 94
        // IF   x30, x30, 0x2c   // x30 = 138
        // IF   x30, x30, 0x00   // send 0x8a, x30 = 0
        // jal  x0, 0
        u_fpga.u_exrom._ram[0]  = 32'h300007b7;
        u_fpga.u_exrom._ram[1]  = 32'h00100713;
        u_fpga.u_exrom._ram[2]  = 32'h00e7a023;
        u_fpga.u_exrom._ram[3]  = 32'h08000f93;
        u_fpga.u_exrom._ram[4]  = 32'h00000f33;
        u_fpga.u_exrom._ram[5]  = 32'h00af2f2f;
        u_fpga.u_exrom._ram[6]  = 32'h01af2f2f;
        u_fpga.u_exrom._ram[7]  = 32'h03af2f2f;
        u_fpga.u_exrom._ram[8]  = 32'h02cf2f2f;
        u_fpga.u_exrom._ram[9]  = 32'h000f2f2f;
        u_fpga.u_exrom._ram[10] = 32'h0000006f;

        #100;
        rst_n = 1'b1;

        recv_uart_byte(got);

        repeat (UART_BIT_CYCLES + 100) @(posedge clk);

        if (got == 8'h8a && x30 == 32'h0 && x31 == 32'd128) begin
            $display("BRIDGE_SOC_IF_PASS got=%h x30=%h x31=%h", got, x30, x31);
        end else begin
            $display("BRIDGE_SOC_IF_FAIL got=%h exp=8a x30=%h x31=%h", got, x30, x31);
            $finish;
        end

        $finish;
    end

    initial begin
        #2000000;
        $display("BRIDGE_SOC_IF_TIMEOUT uart_tx=%b x30=%h x31=%h", uart_tx_pin, x30, x31);
        $finish;
    end

    task recv_uart_byte;
        output[7:0] data;
        integer b;
        begin
            data = 8'h00;
            @(negedge uart_tx_pin);
            repeat (UART_BIT_CYCLES / 2) @(posedge clk);
            #1;
            if (uart_tx_pin != 1'b0) begin
                $display("BRIDGE_SOC_IF_FAIL bad_start_bit uart_tx=%b", uart_tx_pin);
                $finish;
            end
            for (b = 0; b < 8; b = b + 1) begin
                repeat (UART_BIT_CYCLES) @(posedge clk);
                #1;
                data[b] = uart_tx_pin;
            end
            repeat (UART_BIT_CYCLES) @(posedge clk);
        end
    endtask

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
