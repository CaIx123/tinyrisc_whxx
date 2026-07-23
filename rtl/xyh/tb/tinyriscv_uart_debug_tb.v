`timescale 1 ns / 1 ps

`include "defines.v"
`include "../rtl/tiny_macro.v"

module tinyriscv_uart_debug_tb;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;

    wire uart_tx_pin;
    wire succ;
    wire [2:0] pwm_o;
    tri1 iic_scl;
    tri1 iic_sda;

    wire [31:0] x3  = tinyriscv_uart_debug_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[3];
    wire [31:0] x26 = tinyriscv_uart_debug_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[26];
    wire [31:0] x27 = tinyriscv_uart_debug_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[27];

    localparam integer UART_BIT_CYCLES  = `UART_BAUD_115200 + 1;
    localparam integer UART_HALF_CYCLES = (UART_BIT_CYCLES + 1) / 2;
    localparam integer SIM_TIMEOUT_NS   = 50000000;
    localparam integer PACKET_LEN       = `UART_PACKET_LEN;

    reg [7:0] packet_mem [0:4095];
    integer packet_total_bytes;
    integer idx;
    integer r;
    reg [7:0] ack_byte;

    always #10 clk = ~clk;

    task automatic wait_uart_cycles(input integer cycles);
        integer k;
        begin
            for (k = 0; k < cycles; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic uart_send_byte(input [7:0] tx_byte);
        integer bit_idx;
        begin
            uart_rx_pin = 1'b0;
            wait_uart_cycles(UART_BIT_CYCLES);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                uart_rx_pin = tx_byte[bit_idx];
                wait_uart_cycles(UART_BIT_CYCLES);
            end
            uart_rx_pin = 1'b1;
            wait_uart_cycles(UART_BIT_CYCLES);
        end
    endtask

    task automatic uart_recv_byte(output [7:0] rx_byte);
        integer bit_idx;
        begin
            rx_byte = 8'h00;
            @(negedge uart_tx_pin);
            wait_uart_cycles(UART_HALF_CYCLES);
            if (uart_tx_pin === 1'b0) begin
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    wait_uart_cycles(UART_BIT_CYCLES);
                    rx_byte[bit_idx] = uart_tx_pin;
                end
                wait_uart_cycles(UART_BIT_CYCLES);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b1;
        packet_total_bytes = 0;
        #100;
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
        #20;
        uart_debug_pin = 1'b0;
    end

    initial begin
        $readmemh("uart_debug_packets.mem", packet_mem);
        packet_total_bytes = {packet_mem[0], packet_mem[1], packet_mem[2], packet_mem[3]};
    end

    initial begin : uart_debug_programmer
        @(negedge rst_n);
        @(posedge rst_n);
        #100;
        wait_uart_cycles(UART_BIT_CYCLES * 10);
        for (idx = 0; idx < packet_total_bytes; idx = idx + 1) begin
            uart_send_byte(packet_mem[idx + 4]);
            if (((idx + 1) % PACKET_LEN) == 0) begin
                uart_recv_byte(ack_byte);
            end
        end
        wait_uart_cycles(UART_BIT_CYCLES * 8);
        uart_debug_pin = 1'b1;
    end

    initial begin
        $dumpfile("tinyriscv_soc_tb.vcd");
        $dumpvars(0, tinyriscv_uart_debug_tb);
    end

    initial begin
        wait(x26 == 32'h1);
        #400;
        if (x27 == 32'h1) begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~");
        end else begin
            $display("~~~~~~~~~~~~~~~~~~~ TEST_FAIL ~~~~~~~~~~~~~~~~~~~");
            $display("fail testnum = %2d", x3);
            for (r = 0; r < 32; r = r + 1) begin
                $display("x%2d = 0x%x", r, tinyriscv_uart_debug_tb_0.u_tinyriscv_soc_top.u_tinyriscv_core.u_gpr_reg.regs[r]);
            end
        end
        $finish;
    end

    initial begin
        #SIM_TIMEOUT_NS;
        $display("Time Out.");
        $finish;
    end

    tinyriscv_sys_top tinyriscv_uart_debug_tb_0(
        .clk(clk),
        .rst(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(uart_debug_pin),
        .succ(succ),
        .pwm_o(pwm_o),
        .iic_scl(iic_scl),
        .iic_sda(iic_sda)
    );

endmodule
