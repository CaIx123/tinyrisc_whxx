`timescale 1ns / 1ps

`include "../top/macros.v"

module tb_g03_postsyn_smoke;

    localparam integer MAX_CORE_CYCLES = 200000;
    localparam integer UART_DEBUG_BAUD_DIV = `UART_BAUD_115200;
    localparam integer UART_BIT_CYCLES = UART_DEBUG_BAUD_DIV + 1;
    localparam integer UART_PACKET_BYTES = `UART_PACKET_LEN;
    localparam integer UART_PAYLOAD_BYTES = UART_PACKET_BYTES - 3;
    localparam integer UART_ACK_TIMEOUT_CYCLES =
        (UART_PACKET_BYTES * 10 + 64) * UART_BIT_CYCLES;
    localparam [31:0] INST_JAL_ZERO = 32'h0000006f;

    reg clk;
    reg rst_n;
    reg debug_en;
    reg [1:0] chip_sel;
    reg uart_rx;
    reg [7:0] packet [0:UART_PACKET_BYTES-1];
    reg [`INST_WIDTH-1:0] firmware [0:`ROM_DEPTH-1];
    integer pc;
    integer program_words;
    integer failures;
`ifdef G03_BACKUP_DIAG
    integer wzc_edges;
    integer wzc_trace_edges;
`endif

    wire succ;
    wire uart_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_rx;
    wire [3:0] pwm;
    tri1 i2c_scl;
    tri1 i2c_sda;

    always #10 clk = ~clk;

`ifdef G03_BACKUP_DIAG
    always @(posedge u_dut.n30741) begin
        wzc_edges = wzc_edges + 1;
        if (wzc_trace_edges > 0) begin
            #1;
            $display("G03_BACKUP_TRACE edge=%0d rst_pad=%b rst_core=%b pc=%h if_state=%b if_inst=%h bridge_state=%b bridge_addr=%h bridge_data=%h soc_tx=%h fpga_tx=%h rx_core=%h rom_data=%h x27=%b",
                     wzc_edges, rst_n, u_dut.\u_g03_soc/rst_n ,
                     u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc ,
                     u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/u_ifu/u_ifu_ifetch/state ,
                     u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_id_inst ,
                     u_dut.\u_g03_soc/u_perips_top/u_bridge_wzc/tr_state ,
                     u_dut.\u_g03_soc/u_perips_top/u_bridge_wzc/tr_addr ,
                     u_dut.\u_g03_soc/u_perips_top/u_bridge_wzc/data_r ,
                     bridge_tx, bridge_rx, u_dut.bridge_rx_data_core,
                     u_fpga.rom_data_i,
                     u_dut.\u_g03_soc/gpr_x27[0] );
            wzc_trace_edges = wzc_trace_edges - 1;
        end
    end
`endif

    function [31:0] inst_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_i = {imm, rs1, funct3, rd, 7'b0010011};
        end
    endfunction

    function [31:0] inst_j;
        input [4:0] rd;
        input integer byte_offset;
        reg [20:0] imm;
        begin
            imm = byte_offset[20:0];
            inst_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
        end
    endfunction

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
        reg [31:0] word_data;
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
            @(negedge clk);
            #1;
            uart_rx = 1'b0;
            repeat (UART_BIT_CYCLES) @(negedge clk);
            #1;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = data[bit_index];
                repeat (UART_BIT_CYCLES) @(negedge clk);
                #1;
            end
            uart_rx = 1'b1;
            repeat (UART_BIT_CYCLES) @(negedge clk);
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
            while (uart_tx !== 1'b0 && wait_cycles < max_cycles) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (uart_tx !== 1'b0) begin
                timed_out = 1'b1;
            end else begin
                repeat (UART_BIT_CYCLES + (UART_BIT_CYCLES / 2)) @(posedge clk);
                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    data[bit_index] = uart_tx;
                    repeat (UART_BIT_CYCLES) @(posedge clk);
                end
            end
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

    task send_packet_expect_ack;
        reg [7:0] response;
        reg timed_out;
        begin
            fork
                send_packet;
                recv_uart_byte_timeout(UART_ACK_TIMEOUT_CYCLES, response, timed_out);
            join
            if (timed_out || response != `UART_RESP_ACK) begin
                $display("G03_POSTSYN_UART_DOWNLOAD_FAIL timeout=%b response=%h header=%h",
                         timed_out, response, packet[0]);
                failures = failures + 1;
            end
        end
    endtask

    task download_program;
        integer data_packet_index;
        integer data_packet_count;
        begin
            $display("G03_POSTSYN_DOWNLOAD_BEGIN chip=%b", chip_sel);
            build_first_packet(program_words * 4);
            send_packet_expect_ack;
            if (failures == 0) begin
                data_packet_count = (program_words + 7) / 8;
                for (data_packet_index = 0;
                     data_packet_index < data_packet_count && failures == 0;
                     data_packet_index = data_packet_index + 1) begin
                    build_data_packet(data_packet_index);
                    send_packet_expect_ack;
                end
            end
        end
    endtask

    task build_program;
        integer word_index;
        integer nop_index;
        begin
            for (word_index = 0; word_index < `ROM_DEPTH; word_index = word_index + 1)
                firmware[word_index] = `INST_NOP;
            pc = 0;
            firmware[pc] = inst_i(12'd0, 5'd0, 3'b000, 5'd27);
            pc = pc + 1;
            for (nop_index = 0; nop_index < 32; nop_index = nop_index + 1) begin
                firmware[pc] = `INST_NOP;
                pc = pc + 1;
            end
            firmware[pc] = inst_i(12'd1, 5'd0, 3'b000, 5'd27);
            pc = pc + 1;
            firmware[pc] = inst_j(5'd0, 0);
            pc = pc + 1;
            program_words = pc;
        end
    endtask

    task prepare_uart_download;
        input [1:0] target_chip;
        begin
            @(negedge clk);
            #1;
            rst_n = 1'b0;
            debug_en = 1'b0;
            chip_sel = target_chip;
            uart_rx = 1'b1;
            repeat (8) @(negedge clk);
            #1;
            rst_n = 1'b1;
            debug_en = 1'b1;
            repeat (16) @(negedge clk);
            repeat (512) @(negedge clk);
            if (uart_tx !== 1'b1) begin
                $display("G03_POSTSYN_STARTUP_FAIL chip=%b rst_n=%b debug_en=%b uart_tx=%b",
                         target_chip, rst_n, debug_en, uart_tx);
                failures = failures + 1;
            end
        end
    endtask

    task start_core;
        input [1:0] target_chip;
        begin
            @(negedge clk);
            #1;
            debug_en = 1'b0;
            rst_n = 1'b0;
            chip_sel = target_chip;
            repeat (8) @(negedge clk);
`ifdef G03_BACKUP_DIAG
            if (target_chip == 2'b00)
                $display("G03_BACKUP_STATE phase=RESET_ASSERTED rst_pad=%b rst_n_core=%b rst0=%b rst1=%b rst_core=%b pc=%h if_state=%b x27=%b",
                         rst_n, u_dut.rst_n_core, u_dut.n30463, u_dut.n30464,
                         u_dut.\u_g03_soc/rst_n ,
                         u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc ,
                         u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/u_ifu/u_ifu_ifetch/state ,
                         u_dut.\u_g03_soc/gpr_x27[0] );
`endif
            #1;
            rst_n = 1'b1;
`ifdef G03_BACKUP_DIAG
            if (target_chip == 2'b00)
                wzc_trace_edges = 40;
`endif
            repeat (16) @(negedge clk);
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*4-1:0] core_name;
        integer cycles;
        reg saw_pending;
        reg passed;
        begin
            saw_pending = 1'b0;
            passed = 1'b0;
            cycles = 0;
`ifdef G03_BACKUP_DIAG
            if (core_sel == 2'b00)
                $display("G03_BACKUP_STATE phase=CORE_START edges=%0d clk_core=%b wzc_clk=%b en=%b rst0=%b rst1=%b rst_core=%b pc=%h if_state=%b x27=%b",
                         wzc_edges, u_dut.clk_core, u_dut.n30741,
                         u_dut.\u_g03_soc/u_global_clk_sel/u_icg_wzc/en_latched ,
                         u_dut.n30463, u_dut.n30464,
                         u_dut.\u_g03_soc/rst_n ,
                         u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc ,
                         u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/u_ifu/u_ifu_ifetch/state ,
                         u_dut.\u_g03_soc/gpr_x27[0] );
`endif
            while (cycles < MAX_CORE_CYCLES && !passed) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (succ === 1'b1) begin
                    saw_pending = 1'b1;
                end else if (succ === 1'b0) begin
                    if (saw_pending)
                        passed = 1'b1;
                end
            end
            if (!passed) begin
`ifdef G03_BACKUP_DIAG
                if (core_sel == 2'b00)
                    $display("G03_BACKUP_STATE phase=CORE_TIMEOUT edges=%0d clk_core=%b wzc_clk=%b en=%b rst0=%b rst1=%b rst_core=%b pc=%h if_state=%b x27=%b",
                             wzc_edges, u_dut.clk_core, u_dut.n30741,
                             u_dut.\u_g03_soc/u_global_clk_sel/u_icg_wzc/en_latched ,
                             u_dut.n30463, u_dut.n30464,
                             u_dut.\u_g03_soc/rst_n ,
                             u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc ,
                             u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/u_ifu/u_ifu_ifetch/state ,
                             u_dut.\u_g03_soc/gpr_x27[0] );
`endif
                $display("G03_POSTSYN_%0s_FAIL succ=%b cycles=%0d", core_name, succ, cycles);
                failures = failures + 1;
            end else begin
                $display("G03_POSTSYN_%0s_PASS cycles=%0d", core_name, cycles);
            end
        end
    endtask

`ifdef G03_POSTSYN_SDF
    initial begin
        $sdf_annotate("../backend/post_syn_125MHz/g03_top_IO.syn.sdf", u_dut);
    end
`endif

`ifdef G03_BACKUP_DIAG
    initial begin
        force u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc [0] = 1'b0;
        force u_dut.\u_g03_soc/u_core_wzc/u_kalsit_core/if_pc [1] = 1'b0;
    end
`endif

    initial begin
        clk = 1'b0;
        rst_n = 1'b1;
        debug_en = 1'b0;
        chip_sel = 2'b00;
        uart_rx = 1'b1;
        failures = 0;
`ifdef G03_BACKUP_DIAG
        wzc_edges = 0;
        wzc_trace_edges = 0;
`endif
        build_program;

        prepare_uart_download(2'b00);
        download_program;
        if (failures == 0) begin
            start_core(2'b00);
            run_core(2'b00, "WZC");
        end

        if (failures == 0) begin
            prepare_uart_download(2'b01);
            download_program;
            if (failures == 0) begin
                start_core(2'b01);
                run_core(2'b01, "XYH");
            end
        end

        if (failures == 0) begin
            prepare_uart_download(2'b10);
            download_program;
            if (failures == 0) begin
                start_core(2'b10);
                run_core(2'b10, "HJX");
            end
        end

        if (failures == 0) begin
            prepare_uart_download(2'b11);
            download_program;
            if (failures == 0) begin
                start_core(2'b11);
                run_core(2'b11, "XZR");
            end
        end

        if (failures == 0)
            $display("G03_POSTSYN_ALL_CORES_PASS");
        else
            $display("G03_POSTSYN_ALL_CORES_FAIL failures=%0d", failures);
        $finish;
    end

    initial begin
        #200000000;
        $display("G03_POSTSYN_TIMEOUT chip=%b succ=%b", chip_sel, succ);
        $finish;
    end

    g03_top_IO u_dut (
        .clk(clk),
        .rst_n_i(rst_n),
        .debug_en_i(debug_en),
        .chip_sel_i(chip_sel),
        .succ(succ),
        .bridge_tx_data_o(bridge_tx),
        .bridge_rx_data_i(bridge_rx),
        .uart_tx_o(uart_tx),
        .uart_rx_i(uart_rx),
        .pwm_o(pwm),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    fpga_top u_fpga (
        .clk(clk),
        .rst_n(rst_n),
        .chip_sel_i(chip_sel),
        .bridge_rx_data_i(bridge_tx),
        .bridge_tx_data_o(bridge_rx),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

endmodule
