`timescale 1 ns / 1 ps

`include "defines.v"
`include "../rtl/tiny_macro.v"

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

    localparam integer UART_BIT_CYCLES = `UART_BAUD_115200 + 1;
    localparam integer UART_HALF_CYCLES = (UART_BIT_CYCLES + 1) / 2;
    localparam integer SIM_TIMEOUT_NS = 500000;
    localparam integer EXPECTED_BYTES = 10;

    reg [7:0] uart_buf [0:255];
    integer uart_count;
    integer i;

    always #10 clk = ~clk;

    task automatic wait_uart_cycles(input integer cycles);
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b0;
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

    initial begin : uart_monitor
        reg [7:0] rx_byte;
        @(negedge rst_n);
        @(posedge rst_n);
        wait_uart_cycles(UART_BIT_CYCLES * 2);
        forever begin
            @(negedge uart_tx_pin);
            wait_uart_cycles(UART_HALF_CYCLES);
            if (uart_tx_pin === 1'b0) begin
                rx_byte = 8'h00;
                for (i = 0; i < 8; i = i + 1) begin
                    wait_uart_cycles(UART_BIT_CYCLES);
                    rx_byte[i] = uart_tx_pin;
                end
                wait_uart_cycles(UART_BIT_CYCLES);
                if (uart_tx_pin === 1'b1) begin
                    if (uart_count < 256) begin
                        uart_buf[uart_count] = rx_byte;
                        uart_count = uart_count + 1;
                    end
                end
            end
        end
    end

    initial begin
        wait (uart_count >= EXPECTED_BYTES);
        wait_uart_cycles(UART_BIT_CYCLES * 4);
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

    initial begin
        $readmemh("inst.data", tinyriscv_sendid_tb_0.u_exmem_top.u_exrom._ram);
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
