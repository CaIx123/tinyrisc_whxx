`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../perips/tiny_macro.v"

module tb_uart_debug_soc_if;

    localparam integer UART_BIT_CYCLES = 434;
    localparam integer PROGRAM_BYTES = 44;

    reg clk;
    reg rst_n;
    reg uart_rx_pin;
    reg uart_debug_pin;

    wire uart_tx_pin;
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;

    wire[31:0] x30 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[30];
    wire[31:0] x31 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[31];

    reg[7:0] pkt[0:34];
    reg[7:0] got;
    integer i;

    always #10 clk = ~clk;

    function[15:0] crc16_step;
        input[15:0] crc_i;
        input[7:0] data_i;
        integer b;
        reg[15:0] crc;
        begin
            crc = crc_i ^ {8'h00, data_i};
            for (b = 0; b < 8; b = b + 1) begin
                if (crc[0]) begin
                    crc = (crc >> 1) ^ 16'ha001;
                end else begin
                    crc = crc >> 1;
                end
            end
            crc16_step = crc;
        end
    endfunction

    task clear_packet;
        integer k;
        begin
            for (k = 0; k < 35; k = k + 1) begin
                pkt[k] = 8'h00;
            end
        end
    endtask

    task put_crc;
        integer k;
        reg[15:0] crc;
        begin
            crc = 16'hffff;
            for (k = 1; k <= 32; k = k + 1) begin
                crc = crc16_step(crc, pkt[k]);
            end
            pkt[33] = crc[7:0];
            pkt[34] = crc[15:8];
        end
    endtask

    task build_first_packet;
        input[31:0] file_size;
        begin
            clear_packet;
            pkt[0] = 8'h00;
            pkt[1] = "f";
            pkt[2] = "w";
            pkt[3] = ".";
            pkt[4] = "b";
            pkt[5] = "i";
            pkt[6] = "n";
            pkt[25] = file_size[31:24];
            pkt[26] = file_size[23:16];
            pkt[27] = file_size[15:8];
            pkt[28] = file_size[7:0];
            put_crc;
        end
    endtask

    task build_data_packet;
        input integer packet_idx;
        begin
            clear_packet;
            pkt[0] = 8'h01;

            if (packet_idx == 0) begin
                // 300007b7 00100713 00e7a023 08000f93
                // 00000f33 00af2f2f 01af2f2f 03af2f2f
                pkt[1]  = 8'hb7; pkt[2]  = 8'h07; pkt[3]  = 8'h00; pkt[4]  = 8'h30;
                pkt[5]  = 8'h13; pkt[6]  = 8'h07; pkt[7]  = 8'h10; pkt[8]  = 8'h00;
                pkt[9]  = 8'h23; pkt[10] = 8'ha0; pkt[11] = 8'he7; pkt[12] = 8'h00;
                pkt[13] = 8'h93; pkt[14] = 8'h0f; pkt[15] = 8'h00; pkt[16] = 8'h08;
                pkt[17] = 8'h33; pkt[18] = 8'h0f; pkt[19] = 8'h00; pkt[20] = 8'h00;
                pkt[21] = 8'h2f; pkt[22] = 8'h2f; pkt[23] = 8'haf; pkt[24] = 8'h00;
                pkt[25] = 8'h2f; pkt[26] = 8'h2f; pkt[27] = 8'haf; pkt[28] = 8'h01;
                pkt[29] = 8'h2f; pkt[30] = 8'h2f; pkt[31] = 8'haf; pkt[32] = 8'h03;
            end else begin
                // 02cf2f2f 000f2f2f 0000006f, then padding zeros
                pkt[1]  = 8'h2f; pkt[2]  = 8'h2f; pkt[3]  = 8'hcf; pkt[4]  = 8'h02;
                pkt[5]  = 8'h2f; pkt[6]  = 8'h2f; pkt[7]  = 8'h0f; pkt[8]  = 8'h00;
                pkt[9]  = 8'h6f; pkt[10] = 8'h00; pkt[11] = 8'h00; pkt[12] = 8'h00;
            end

            put_crc;
        end
    endtask

    task send_uart_byte;
        input[7:0] data;
        integer b;
        begin
            uart_rx_pin = 1'b0;
            repeat (UART_BIT_CYCLES) @(posedge clk);
            for (b = 0; b < 8; b = b + 1) begin
                uart_rx_pin = data[b];
                repeat (UART_BIT_CYCLES) @(posedge clk);
            end
            uart_rx_pin = 1'b1;
            repeat (UART_BIT_CYCLES) @(posedge clk);
        end
    endtask

    task send_packet;
        integer k;
        begin
            for (k = 0; k < 35; k = k + 1) begin
                send_uart_byte(pkt[k]);
            end
        end
    endtask

    task recv_uart_byte;
        output[7:0] data;
        integer b;
        begin
            data = 8'h00;
            @(negedge uart_tx_pin);
            repeat (UART_BIT_CYCLES / 2) @(posedge clk);
            #1;
            if (uart_tx_pin != 1'b0) begin
                $display("UART_DEBUG_SOC_IF_FAIL bad_start_bit uart_tx=%b", uart_tx_pin);
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

    task expect_ack;
        reg[7:0] resp;
        begin
            recv_uart_byte(resp);
            if (resp != 8'h06) begin
                $display("UART_DEBUG_SOC_IF_PHASE1_FAIL bad_ack resp=%h state=%0d",
                         resp, u_soc.u_uart_debug.state);
                $finish;
            end
        end
    endtask

    task send_packet_expect_ack;
        begin
            fork
                send_packet;
                expect_ack;
            join
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        uart_rx_pin = 1'b1;
        uart_debug_pin = 1'b1;
        got = 8'h0;

        #100;
        rst_n = 1'b1;

        // Let uart_debug initialize UART_CTRL/UART_BAUD before host traffic.
        #200000;

        build_first_packet(PROGRAM_BYTES);
        send_packet_expect_ack;

        build_data_packet(0);
        send_packet_expect_ack;

        build_data_packet(1);
        send_packet_expect_ack;

        #200000;

        if (u_fpga.u_exrom._ram[0]  == 32'h300007b7 &&
            u_fpga.u_exrom._ram[1]  == 32'h00100713 &&
            u_fpga.u_exrom._ram[2]  == 32'h00e7a023 &&
            u_fpga.u_exrom._ram[3]  == 32'h08000f93 &&
            u_fpga.u_exrom._ram[4]  == 32'h00000f33 &&
            u_fpga.u_exrom._ram[5]  == 32'h00af2f2f &&
            u_fpga.u_exrom._ram[6]  == 32'h01af2f2f &&
            u_fpga.u_exrom._ram[7]  == 32'h03af2f2f &&
            u_fpga.u_exrom._ram[8]  == 32'h02cf2f2f &&
            u_fpga.u_exrom._ram[9]  == 32'h000f2f2f &&
            u_fpga.u_exrom._ram[10] == 32'h0000006f) begin
            $display("UART_DEBUG_SOC_IF_PHASE1_PASS rom0=%h rom10=%h",
                     u_fpga.u_exrom._ram[0], u_fpga.u_exrom._ram[10]);
        end else begin
            $display("UART_DEBUG_SOC_IF_PHASE1_FAIL rom0=%h rom1=%h rom2=%h rom8=%h rom9=%h rom10=%h state=%0d",
                     u_fpga.u_exrom._ram[0], u_fpga.u_exrom._ram[1],
                     u_fpga.u_exrom._ram[2], u_fpga.u_exrom._ram[8],
                     u_fpga.u_exrom._ram[9], u_fpga.u_exrom._ram[10],
                     u_soc.u_uart_debug.state);
            $finish;
        end

        // Stop debug master, reset the SoC pipeline, then run from ROM[0].
        uart_debug_pin = 1'b0;
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        recv_uart_byte(got);
        repeat (UART_BIT_CYCLES + 100) @(posedge clk);

        if (got == 8'h8a && x30 == 32'h0 && x31 == 32'd128) begin
            $display("UART_DEBUG_SOC_IF_PHASE2_PASS got=%h x30=%h x31=%h",
                     got, x30, x31);
        end else begin
            $display("UART_DEBUG_SOC_IF_PHASE2_FAIL got=%h exp=8a x30=%h x31=%h",
                     got, x30, x31);
            $finish;
        end

        $display("UART_DEBUG_SOC_IF_PASS");
        $finish;
    end

    initial begin
        #60000000;
        $display("UART_DEBUG_SOC_IF_TIMEOUT rom0=%h rom8=%h rom9=%h rom10=%h x30=%h x31=%h state=%0d tx=%b rx=%b",
                 u_fpga.u_exrom._ram[0], u_fpga.u_exrom._ram[8],
                 u_fpga.u_exrom._ram[9], u_fpga.u_exrom._ram[10],
                 x30, x31, u_soc.u_uart_debug.state, uart_tx_pin, uart_rx_pin);
        $finish;
    end

    tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst_ext_i(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .uart_debug_pin(uart_debug_pin),
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
