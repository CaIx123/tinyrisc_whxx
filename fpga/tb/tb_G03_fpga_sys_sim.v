`timescale 1ns / 1ps

`include "macros.v"

// FPGA-only regression testbench.
// Firmware reaches the real 256-word FPGA ROM through UART debug and the
// bridge; the 16-word FPGA RAM remains the storage instantiated by fpga_top.
module tb_G03_fpga_sys_sim;

    localparam integer UART_DEBUG_BAUD_DIV = 5;
    localparam integer UART_BIT_CYCLES = UART_DEBUG_BAUD_DIV + 1;
    localparam integer UART_PACKET_BYTES = `UART_PACKET_LEN;
    localparam integer UART_PAYLOAD_BYTES = UART_PACKET_BYTES - 3;
    localparam integer MAX_EXEC_CYCLES = 100000;

    reg clk;
    reg rst_n;
    reg debug_en;
    reg [1:0] chip_sel;
    reg uart_rx;
    tri1 i2c_scl;
    tri1 i2c_sda;

    wire succ;
    wire uart_tx;
    wire [3:0] pwm;

    reg [7:0] packet [0:UART_PACKET_BYTES-1];
    reg [`INST_WIDTH-1:0] firmware [0:`ROM_DEPTH-1];
    reg [1023:0] firmware_path;
    integer program_words;
    integer index;
    integer failures;

    wire [`DATA_WIDTH-1:0] x26 = dut.u_g03_soc.u_gpr_top.u_gpr.regs[26];
    wire [`DATA_WIDTH-1:0] x27 = dut.u_g03_soc.u_gpr_top.x27_o;

    always #10 clk = ~clk;

    function [15:0] crc16_step;
        input [15:0] crc_i;
        input [7:0] data_i;
        integer bit_index;
        reg [15:0] crc;
        begin
            crc = crc_i ^ {8'h00, data_i};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                crc = crc[0] ? ((crc >> 1) ^ 16'ha001) : (crc >> 1);
            crc16_step = crc;
        end
    endfunction

    task clear_packet;
        integer packet_index;
        begin
            for (packet_index = 0; packet_index < UART_PACKET_BYTES;
                 packet_index = packet_index + 1)
                packet[packet_index] = 8'h00;
        end
    endtask

    task append_crc;
        integer payload_index;
        reg [15:0] crc;
        begin
            crc = 16'hffff;
            for (payload_index = 1; payload_index <= UART_PAYLOAD_BYTES;
                 payload_index = payload_index + 1)
                crc = crc16_step(crc, packet[payload_index]);
            packet[UART_PACKET_BYTES - 2] = crc[7:0];
            packet[UART_PACKET_BYTES - 1] = crc[15:8];
        end
    endtask

    task build_first_packet;
        input [31:0] firmware_size;
        begin
            clear_packet;
            packet[0] = 8'h00;
            packet[1] = "g";
            packet[2] = "0";
            packet[3] = "3";
            packet[4] = ".";
            packet[5] = "b";
            packet[6] = "i";
            packet[7] = "n";
            // uart_debug stores the big-endian byte count at payload[25:28].
            packet[25] = firmware_size[31:24];
            packet[26] = firmware_size[23:16];
            packet[27] = firmware_size[15:8];
            packet[28] = firmware_size[7:0];
            append_crc;
        end
    endtask

    task build_data_packet;
        input integer packet_number;
        integer payload_index;
        integer word_index;
        reg [`INST_WIDTH-1:0] word_data;
        begin
            clear_packet;
            packet[0] = 8'h01;
            for (payload_index = 0; payload_index < UART_PAYLOAD_BYTES;
                 payload_index = payload_index + 1) begin
                word_index = packet_number * 8 + (payload_index / 4);
                word_data = word_index < program_words ? firmware[word_index] : `INST_NOP;
                case (payload_index % 4)
                    0: packet[payload_index + 1] = word_data[7:0];
                    1: packet[payload_index + 1] = word_data[15:8];
                    2: packet[payload_index + 1] = word_data[23:16];
                    default: packet[payload_index + 1] = word_data[31:24];
                endcase
            end
            append_crc;
        end
    endtask

    task send_uart_byte;
        input [7:0] data;
        integer bit_index;
        begin
            uart_rx = 1'b0;
            repeat (UART_BIT_CYCLES) @(posedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = data[bit_index];
                repeat (UART_BIT_CYCLES) @(posedge clk);
            end
            uart_rx = 1'b1;
            repeat (UART_BIT_CYCLES) @(posedge clk);
        end
    endtask

    task send_packet;
        integer packet_index;
        begin
            for (packet_index = 0; packet_index < UART_PACKET_BYTES;
                 packet_index = packet_index + 1)
                send_uart_byte(packet[packet_index]);
        end
    endtask

    task recv_uart_byte;
        output [7:0] data;
        integer bit_index;
        begin
            data = 8'h00;
            @(negedge uart_tx);
            repeat (UART_BIT_CYCLES + (UART_BIT_CYCLES / 2)) @(posedge clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                data[bit_index] = uart_tx;
                repeat (UART_BIT_CYCLES) @(posedge clk);
            end
        end
    endtask

    task send_packet_expect_ack;
        reg [7:0] response;
        begin
            fork
                send_packet;
                recv_uart_byte(response);
            join
            if (response != `UART_RESP_ACK) begin
                $display("FPGA_UART_DOWNLOAD_FAIL chip=%b response=%h header=%h",
                         chip_sel, response, packet[0]);
                failures = failures + 1;
            end
        end
    endtask

    task download_firmware;
        integer packet_number;
        integer packet_count;
        begin
            build_first_packet(program_words * 4);
            send_packet_expect_ack;
            packet_count = (program_words + 7) / 8;
            for (packet_number = 0; packet_number < packet_count;
                 packet_number = packet_number + 1) begin
                build_data_packet(packet_number);
                send_packet_expect_ack;
            end
        end
    endtask

    task prepare_uart_debug;
        begin
            rst_n = 1'b0;
            debug_en = 1'b0;
            uart_rx = 1'b1;
            repeat (8) @(posedge clk);
            rst_n = 1'b1;
            debug_en = 1'b1;
            repeat (512) @(posedge clk);
        end
    endtask

    task start_selected_core;
        begin
            debug_en = 1'b0;
            rst_n = 1'b0;
            repeat (8) @(posedge clk);
            rst_n = 1'b1;
            repeat (8) @(posedge clk);
        end
    endtask

    task wait_for_pass;
        integer cycles;
        reg seen_clear;
        begin
            cycles = 0;
            seen_clear = 1'b0;
            while (cycles < MAX_EXEC_CYCLES && !(seen_clear && x26 === 32'd1)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (x26 === 32'd0 && x27 === 32'd0)
                    seen_clear = 1'b1;
            end
            if (seen_clear && x26 === 32'd1)
                repeat (20) @(posedge clk);

            if (!seen_clear || x26 !== 32'd1 || x27 !== 32'd1 || succ !== 1'b0) begin
                $display("FPGA_TEST_FAIL chip=%b cycles=%0d x26=%h x27=%h succ=%b",
                         chip_sel, cycles, x26, x27, succ);
                failures = failures + 1;
            end else begin
                $display("FPGA_TEST_PASS chip=%b cycles=%0d rom_depth=%0d ram_depth=%0d",
                         chip_sel, cycles, `ROM_DEPTH, `RAM_DEPTH);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        debug_en = 1'b0;
        chip_sel = 2'b00;
        uart_rx = 1'b1;
        failures = 0;
        firmware_path = {1024{1'b0}};
        program_words = 0;

        if (!$value$plusargs("FW=%s", firmware_path)) begin
            $display("FPGA_TEST_FAIL missing +FW=<firmware.data>");
            $finish;
        end
        if (!$value$plusargs("WORDS=%d", program_words) ||
            program_words < 1 || program_words > `ROM_DEPTH) begin
            $display("FPGA_TEST_FAIL invalid +WORDS (ROM_DEPTH=%0d)", `ROM_DEPTH);
            $finish;
        end
        if (!$value$plusargs("CHIP=%d", chip_sel)) begin
            $display("FPGA_TEST_FAIL missing +CHIP=<0..3>");
            $finish;
        end

        for (index = 0; index < `ROM_DEPTH; index = index + 1)
            firmware[index] = `INST_NOP;
        $readmemh(firmware_path, firmware, 0, program_words - 1);

        $display("FPGA_TEST_START chip=%b firmware=%0s words=%0d rom_depth=%0d ram_depth=%0d",
                 chip_sel, firmware_path, program_words, `ROM_DEPTH, `RAM_DEPTH);
        prepare_uart_debug;
        download_firmware;
        start_selected_core;
        wait_for_pass;

        if (failures == 0)
            $display("FPGA_TEST_DONE PASS chip=%b", chip_sel);
        else
            $display("FPGA_TEST_DONE FAIL chip=%b failures=%0d", chip_sel, failures);
        $finish;
    end

    initial begin
        #200000000;
        $display("FPGA_TEST_TIMEOUT chip=%b x26=%h x27=%h", chip_sel, x26, x27);
        $finish;
    end

    G03_fpga_sys_sim #(
        .UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)
    ) dut (
        .clk       (clk),
        .rst_n_i   (rst_n),
        .debug_en_i(debug_en),
        .chip_sel_i(chip_sel),
        .succ      (succ),
        .uart_tx_o (uart_tx),
        .uart_rx_i (uart_rx),
        .pwm_o     (pwm),
        .i2c_scl   (i2c_scl),
        .i2c_sda   (i2c_sda)
    );

endmodule
