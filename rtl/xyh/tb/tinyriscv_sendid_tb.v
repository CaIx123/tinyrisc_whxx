`timescale 1 ns / 1 ps

`include "defines.v"
`include "../tiny_macro.v"

module tinyriscv_sendid_tb;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;

    wire uart_tx_pin;
    wire succ;
    wire [2:0] pwm_o;
    tri1 iic_scl;
    tri1 iic_sda;

    localparam integer SIM_TIMEOUT_NS = 100000000;
    localparam integer EXPECTED_BYTES = 10;

    reg [7:0] uart_buf [0:255];
    integer uart_count;
    integer i;

    `include "uart_debug_programmer.vh"

    always #10 clk = ~clk;

    always @(posedge clk) begin
        if (uart_program_done &&
            tinyriscv_sendid_tb_0.u_tinyriscv_soc_top.uart_0.tx_start) begin
            if (uart_count < 256) begin
                uart_buf[uart_count] = tinyriscv_sendid_tb_0.u_tinyriscv_soc_top.uart_0.data_i[7:0];
                uart_count = uart_count + 1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b1;
        uart_count = 0;
        #100;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
    end

    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_sendid_tb);
    end

    initial begin
        wait (uart_count >= EXPECTED_BYTES);
        repeat (2) @(posedge clk);
        $display("UART_CAPTURE_BEGIN");
        for (i = 0; i < uart_count; i = i + 1) begin
            $write("%c", uart_buf[i]);
        end
        $write("\n");
        $display("UART_CAPTURE_END");
        $finish;
    end

    initial begin
        #SIM_TIMEOUT_NS;
        $display("UART_CAPTURE_BEGIN");
        for (i = 0; i < uart_count; i = i + 1) begin
            $write("%c", uart_buf[i]);
        end
        $write("\n");
        $display("UART_CAPTURE_END");
        $finish;
    end

    tinyriscv_sys_top tinyriscv_sendid_tb_0(
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

endmodule
