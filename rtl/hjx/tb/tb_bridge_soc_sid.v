`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../perips/tiny_macro.v"

module tb_bridge_soc_sid;

    localparam integer UART_BIT_CYCLES = 434;

    reg clk;
    reg rst_n;

    wire uart_tx_pin;
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;

    reg[7:0] got[0:9];
    reg[7:0] exp[0:9];
    integer i;

    always #10 clk = ~clk;

    initial begin
        exp[0] = "2";
        exp[1] = "0";
        exp[2] = "2";
        exp[3] = "2";
        exp[4] = "0";
        exp[5] = "1";
        exp[6] = "2";
        exp[7] = "6";
        exp[8] = "6";
        exp[9] = "5";
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;

        // .insn i 0x2f, 0, x0, x0, 0
        // jal x0, 0
        u_fpga.u_exrom._ram[0] = 32'h0000002f;
        u_fpga.u_exrom._ram[1] = 32'h0000006f;

        #100;
        rst_n = 1'b1;

        for (i = 0; i < 10; i = i + 1) begin
            recv_uart_byte(got[i]);
            if (got[i] != exp[i]) begin
                $display("BRIDGE_SOC_SID_FAIL idx=%0d got=%h exp=%h", i, got[i], exp[i]);
                $finish;
            end
        end

        $display("BRIDGE_SOC_SID_PASS got=%c%c%c%c%c%c%c%c%c%c",
                 got[0], got[1], got[2], got[3], got[4],
                 got[5], got[6], got[7], got[8], got[9]);
        $finish;
    end

    initial begin
        #2000000;
        $display("BRIDGE_SOC_SID_TIMEOUT uart_tx=%b", uart_tx_pin);
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
                $display("BRIDGE_SOC_SID_FAIL bad_start_bit uart_tx=%b", uart_tx_pin);
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
