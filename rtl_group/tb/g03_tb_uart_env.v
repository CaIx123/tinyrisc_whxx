`timescale 1ns / 1ps

`include "../top/macros.v"

`ifndef G03_USE_STD_CELL_LIBRARY
`ifndef G03_TB_STD_CELL_MODELS
`define G03_TB_STD_CELL_MODELS
module TLATNX1 (
    input wire D,
    input wire GN,
    output reg Q,
    output wire QN
);
    initial Q = 1'b0;

    always @(D or GN) begin
        if (!GN)
            Q = D;
    end

    assign QN = ~Q;
endmodule

module AND2X1 (
    input wire A,
    input wire B,
    output wire Y
);
    assign Y = A & B;
endmodule
`endif
`endif

module g03_tb_uart_env #(
    parameter integer UART_DEBUG_BAUD_DIV = 16,
    parameter [15:0] LM75_TEMP_RAW = 16'h1eff
)(
    output reg clk_o,
    output reg rst_n_o,
    output reg debug_en_o,
    output reg [1:0] chip_sel_o,
    output reg uart_rx_o,
    output wire uart_tx_o,
    output wire succ_o,
    output wire [`BRIDGE_WIDTH-1:0] bridge_tx_o,
    output wire [`BRIDGE_WIDTH-1:0] bridge_rx_o,
    output wire [3:0] pwm_o,
    output wire [1:0] i2c_io_ctrl_o,
    output wire [31:0] x26_o,
    output wire [31:0] x27_o
);

    localparam integer UART_BIT_CYCLES = UART_DEBUG_BAUD_DIV + 1;
    localparam integer UART_PACKET_BYTES = `UART_PACKET_LEN;
    localparam integer UART_PAYLOAD_BYTES = UART_PACKET_BYTES - 3;

    reg [7:0] packet [0:UART_PACKET_BYTES-1];
    reg [`INST_WIDTH-1:0] firmware [0:`ROM_DEPTH-1];
    integer pc;
    integer program_words;
    integer download_failures;
    integer route_failures;
    integer selected_bridge_active_cycles;
    integer inactive_bridge_active_cycles;
    reg route_check_en;

    always #10 clk_o = ~clk_o;

    // Count non-idle states only while a UART download is in progress.
    always @(posedge clk_o) begin
        if (route_check_en && rst_n_o) begin
            case (chip_sel_o)
                2'b00: begin
                    if (u_fpga.u_bridge_fpga_wzc.tr_state != 2'd1)
                        selected_bridge_active_cycles = selected_bridge_active_cycles + 1;
                    if (u_fpga.u_bridge_fpga_xyh.tr_state != 2'd0 ||
                        u_fpga.u_bridge_fpga_hjx.state != 2'd0 ||
                        u_fpga.u_bridge_fpga_xzr.state != 3'd0)
                        inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
                end
                2'b01: begin
                    if (u_fpga.u_bridge_fpga_xyh.tr_state != 2'd0)
                        selected_bridge_active_cycles = selected_bridge_active_cycles + 1;
                    if (u_fpga.u_bridge_fpga_wzc.tr_state != 2'd1 ||
                        u_fpga.u_bridge_fpga_hjx.state != 2'd0 ||
                        u_fpga.u_bridge_fpga_xzr.state != 3'd0)
                        inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
                end
                2'b10: begin
                    if (u_fpga.u_bridge_fpga_hjx.state != 2'd0)
                        selected_bridge_active_cycles = selected_bridge_active_cycles + 1;
                    if (u_fpga.u_bridge_fpga_wzc.tr_state != 2'd1 ||
                        u_fpga.u_bridge_fpga_xyh.tr_state != 2'd0 ||
                        u_fpga.u_bridge_fpga_xzr.state != 3'd0)
                        inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
                end
                default: begin
                    if (u_fpga.u_bridge_fpga_xzr.state != 3'd0)
                        selected_bridge_active_cycles = selected_bridge_active_cycles + 1;
                    if (u_fpga.u_bridge_fpga_wzc.tr_state != 2'd1 ||
                        u_fpga.u_bridge_fpga_xyh.tr_state != 2'd0 ||
                        u_fpga.u_bridge_fpga_hjx.state != 2'd0)
                        inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
                end
            endcase
        end
    end

    initial begin
        clk_o = 1'b0;
        rst_n_o = 1'b0;
        debug_en_o = 1'b0;
        chip_sel_o = 2'b00;
        uart_rx_o = 1'b1;
        pc = 0;
        program_words = 0;
        download_failures = 0;
        route_failures = 0;
        selected_bridge_active_cycles = 0;
        inactive_bridge_active_cycles = 0;
        route_check_en = 1'b0;
    end

    function [15:0] crc16_step;
        input [15:0] crc_i;
        input [7:0] data_i;
        integer bit_index;
        reg [15:0] crc;
        begin
            crc = crc_i ^ {8'h00, data_i};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (crc[0])
                    crc = (crc >> 1) ^ 16'ha001;
                else
                    crc = crc >> 1;
            end
            crc16_step = crc;
        end
    endfunction

    task clear_program;
        integer word_index;
        begin
            for (word_index = 0; word_index < `ROM_DEPTH; word_index = word_index + 1)
                firmware[word_index] = `INST_NOP;
            pc = 0;
            program_words = 0;
            download_failures = 0;
            route_failures = 0;
        end
    endtask

    task emit;
        input [`INST_WIDTH-1:0] instruction;
        begin
            if (pc < `ROM_DEPTH) begin
                firmware[pc] = instruction;
                pc = pc + 1;
                program_words = pc;
            end else begin
                $display("G03_UART_ENV_FAIL program exceeds ROM depth=%0d", `ROM_DEPTH);
                download_failures = download_failures + 1;
            end
        end
    endtask

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
            packet[UART_PACKET_BYTES-2] = crc[7:0];
            packet[UART_PACKET_BYTES-1] = crc[15:8];
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
            packet[25] = firmware_size[31:24];
            packet[26] = firmware_size[23:16];
            packet[27] = firmware_size[15:8];
            packet[28] = firmware_size[7:0];
            append_crc;
        end
    endtask

    task build_data_packet;
        input integer data_packet_index;
        integer payload_index;
        integer word_index;
        reg [`INST_WIDTH-1:0] word_data;
        begin
            clear_packet;
            packet[0] = 8'h01;
            for (payload_index = 0; payload_index < UART_PAYLOAD_BYTES;
                 payload_index = payload_index + 1) begin
                word_index = data_packet_index * 8 + (payload_index / 4);
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
            uart_rx_o = 1'b0;
            repeat (UART_BIT_CYCLES) @(posedge clk_o);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx_o = data[bit_index];
                repeat (UART_BIT_CYCLES) @(posedge clk_o);
            end
            uart_rx_o = 1'b1;
            repeat (UART_BIT_CYCLES) @(posedge clk_o);
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
            @(negedge uart_tx_o);
            repeat (UART_BIT_CYCLES + (UART_BIT_CYCLES / 2)) @(posedge clk_o);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                data[bit_index] = uart_tx_o;
                repeat (UART_BIT_CYCLES) @(posedge clk_o);
            end
            // Do not wait through the stop bit here.  The UART accepts the
            // next TX write at the end of that bit, so returning immediately
            // keeps the following receive task armed before its start edge.
        end
    endtask

    task recv_uart_byte_timeout;
        input integer max_cycles;
        output [7:0] data;
        output timed_out;
        integer wait_cycles;
        integer bit_index;
        begin
            data = 8'h00;
            timed_out = 1'b0;
            wait_cycles = 0;
            // Callers arm this task while the line is in its stop/idle state.
            // Sampling on clk_o avoids a SystemVerilog-only join_any timeout.
            while (uart_tx_o !== 1'b0 && wait_cycles < max_cycles) begin
                @(posedge clk_o);
                wait_cycles = wait_cycles + 1;
            end
            if (uart_tx_o !== 1'b0) begin
                timed_out = 1'b1;
            end else begin
                repeat (UART_BIT_CYCLES + (UART_BIT_CYCLES / 2)) @(posedge clk_o);
                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    data[bit_index] = uart_tx_o;
                    repeat (UART_BIT_CYCLES) @(posedge clk_o);
                end
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
                $display("G03_UART_DOWNLOAD_FAIL response=%h packet_header=%h", response, packet[0]);
                download_failures = download_failures + 1;
            end
        end
    endtask

    task download_program;
        integer data_packet_index;
        integer data_packet_count;
        begin
            build_first_packet(program_words * 4);
            send_packet_expect_ack;

            data_packet_count = (program_words + 7) / 8;
            for (data_packet_index = 0; data_packet_index < data_packet_count;
                 data_packet_index = data_packet_index + 1) begin
                build_data_packet(data_packet_index);
                send_packet_expect_ack;
            end
        end
    endtask

    task prepare_uart_download;
        begin
            rst_n_o = 1'b0;
            debug_en_o = 1'b0;
            chip_sel_o = 2'b00;
            uart_rx_o = 1'b1;
            repeat (8) @(posedge clk_o);
            rst_n_o = 1'b1;
            debug_en_o = 1'b1;
            // The debugger has completed its UART setup well before this;
            // keep a modest guard interval so every test starts consistently.
            repeat (512) @(posedge clk_o);
        end
    endtask

    task download_program_to_path;
        input [1:0] target_chip;
        begin
            chip_sel_o = target_chip;
            repeat (16) @(posedge clk_o);

            selected_bridge_active_cycles = 0;
            inactive_bridge_active_cycles = 0;
            route_check_en = 1'b1;
            download_program;
            repeat (16) @(posedge clk_o);
            route_check_en = 1'b0;

            if (selected_bridge_active_cycles == 0 ||
                inactive_bridge_active_cycles != 0) begin
                $display("G03_FPGA_ROUTE_FAIL chip=%b active=%0d inactive=%0d",
                         target_chip, selected_bridge_active_cycles,
                         inactive_bridge_active_cycles);
                route_failures = route_failures + 1;
            end else begin
                $display("G03_FPGA_ROUTE_PASS chip=%b active=%0d",
                         target_chip, selected_bridge_active_cycles);
            end
        end
    endtask

    task start_core;
        input [1:0] target_chip;
        begin
            debug_en_o = 1'b0;
            rst_n_o = 1'b0;
            chip_sel_o = target_chip;
            repeat (8) @(posedge clk_o);
            rst_n_o = 1'b1;
            // global_rst_ctrl synchronizes reset before it reaches the cores
            // and shared GPR.  Do not return while the previous core's pass
            // markers can still be visible to the next test.
            repeat (8) @(posedge clk_o);
        end
    endtask

    tri1 i2c_scl;
    tri1 i2c_sda;

    // g03_soc exposes open-drain controls rather than physical I/O pads.
    // Model those two pads here so the rT test uses the actual I2C peripheral
    // and an LM75 responder without depending on the foundry pad model.
    assign i2c_scl = i2c_io_ctrl_o[1] ? 1'bz : 1'b0;
    assign i2c_sda = i2c_io_ctrl_o[0] ? 1'bz : 1'b0;

    lm75_model #(
        .TEMP_RAW(LM75_TEMP_RAW)
    ) u_lm75_model (
        .clk(clk_o),
        .rst_n(rst_n_o),
        .scl(i2c_scl),
        .sda(i2c_sda)
    );

    g03_soc #(
        .UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)
    ) u_soc (
        .clk(clk_o),
        .rst_n_i(rst_n_o),
        .debug_en_i(debug_en_o),
        .chip_sel_i(chip_sel_o),
        .succ(succ_o),
        .bridge_tx_data_o(bridge_tx_o),
        .bridge_rx_data_i(bridge_rx_o),
        .uart_tx_o(uart_tx_o),
        .uart_rx_i(uart_rx_o),
        .pwm_o(pwm_o),
        .i2c_io_ctrl_o(i2c_io_ctrl_o),
        .i2c_scl_i(i2c_scl),
        .i2c_sda_i(i2c_sda)
    );

    fpga_top u_fpga (
        .clk(clk_o),
        .rst_n(rst_n_o),
        .chip_sel_i(chip_sel_o),
        .bridge_rx_data_i(bridge_tx_o),
        .bridge_tx_data_o(bridge_rx_o),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    assign x26_o = u_soc.u_gpr_top.u_gpr.regs[26];
    assign x27_o = u_soc.u_gpr_top.x27_o;

endmodule
