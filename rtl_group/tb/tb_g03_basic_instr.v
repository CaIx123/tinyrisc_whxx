`timescale 1ns / 1ps

`include "../core00_wzc/marcos_wzc.v"

// Behavioral models used only when the ASIC standard-cell library is absent.
`ifndef G03_USE_STD_CELL_LIBRARY
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

module tb_g03_basic_instr;

    localparam integer MAX_CYCLES = 100000;
    localparam integer UART_DEBUG_BAUD_DIV = 16;
    localparam integer UART_BIT_CYCLES = UART_DEBUG_BAUD_DIV + 1;
    localparam integer UART_PACKET_BYTES = `UART_PACKET_LEN;
    localparam integer UART_PAYLOAD_BYTES = UART_PACKET_BYTES - 3;

    reg clk;
    reg rst_n;
    reg debug_en;
    reg [1:0] chip_sel;
    reg uart_rx;
    reg [7:0] packet [0:UART_PACKET_BYTES-1];
    reg [`INST_WIDTH-1:0] firmware [0:`ROM_DEPTH-1];
    integer pc;
    integer i;
    integer failures;
    integer program_words;
    integer shared_bridge_active_cycles;
    integer hjx_bridge_active_cycles;
    integer inactive_bridge_active_cycles;
    reg route_check_en;

    wire succ;
    wire uart_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_tx;
    wire [`BRIDGE_WIDTH-1:0] bridge_rx;
    wire [`DATA_WIDTH-1:0] x26;
    wire [`DATA_WIDTH-1:0] x27;

    assign x26 = u_soc.u_gpr_top.u_gpr.regs[26];
    assign x27 = u_soc.u_gpr_top.x27_o;

    always #10 clk = ~clk;

    // The idle encodings are TR_CTRL=1 for bridge_fpga and STATE_CTRL=0 for
    // bridge_fpga_hjx.  Count activity only while a download route is checked.
    always @(posedge clk) begin
        if (route_check_en && rst_n) begin
            if (u_fpga.bridge_shared_selected) begin
                if (u_fpga.u_bridge_fpga.tr_state != 2'd1)
                    shared_bridge_active_cycles = shared_bridge_active_cycles + 1;
                if (u_fpga.u_bridge_fpga_hjx.state != 2'd0)
                    inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
            end else begin
                if (u_fpga.u_bridge_fpga_hjx.state != 2'd0)
                    hjx_bridge_active_cycles = hjx_bridge_active_cycles + 1;
                if (u_fpga.u_bridge_fpga.tr_state != 2'd1)
                    inactive_bridge_active_cycles = inactive_bridge_active_cycles + 1;
            end
        end
    end

    function [31:0] inst_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_i = {imm, rs1, funct3, rd, 7'b0010011};
        end
    endfunction

    function [31:0] inst_r;
        input [6:0] funct7;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
        end
    endfunction

    function [31:0] inst_u;
        input [19:0] imm;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            inst_u = {imm, rd, opcode};
        end
    endfunction

    function [31:0] inst_b;
        input [2:0] funct3;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer byte_offset;
        reg [12:0] imm;
        begin
            imm = byte_offset[12:0];
            inst_b = {imm[12], imm[10:5], rs2, rs1, funct3,
                      imm[4:1], imm[11], 7'b1100011};
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

    function [31:0] inst_load;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_load = {imm, rs1, funct3, rd, 7'b0000011};
        end
    endfunction

    function [31:0] inst_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            inst_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
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
            repeat (UART_BIT_CYCLES) @(posedge clk);
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
                failures = failures + 1;
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

    task download_program_to_path;
        input [1:0] target_chip;
        begin
            chip_sel = target_chip;
            repeat (16) @(posedge clk);

            shared_bridge_active_cycles = 0;
            hjx_bridge_active_cycles = 0;
            inactive_bridge_active_cycles = 0;
            route_check_en = 1'b1;
            download_program;
            repeat (16) @(posedge clk);
            route_check_en = 1'b0;

            if (target_chip == 2'b10) begin
                if (hjx_bridge_active_cycles == 0 ||
                    shared_bridge_active_cycles != 0 ||
                    inactive_bridge_active_cycles != 0) begin
                    $display("G03_FPGA_ROUTE_HJX_FAIL shared=%0d hjx=%0d inactive=%0d",
                             shared_bridge_active_cycles, hjx_bridge_active_cycles,
                             inactive_bridge_active_cycles);
                    failures = failures + 1;
                end else begin
                    $display("G03_FPGA_ROUTE_HJX_PASS active=%0d", hjx_bridge_active_cycles);
                end
            end else begin
                if (shared_bridge_active_cycles == 0 ||
                    hjx_bridge_active_cycles != 0 ||
                    inactive_bridge_active_cycles != 0) begin
                    $display("G03_FPGA_ROUTE_SHARED_FAIL shared=%0d hjx=%0d inactive=%0d",
                             shared_bridge_active_cycles, hjx_bridge_active_cycles,
                             inactive_bridge_active_cycles);
                    failures = failures + 1;
                end else begin
                    $display("G03_FPGA_ROUTE_SHARED_PASS active=%0d", shared_bridge_active_cycles);
                end
            end
        end
    endtask

    task emit;
        input [31:0] instruction;
        begin
            firmware[pc] = instruction;
            pc = pc + 1;
        end
    endtask

    // On a mismatch, the following JAL x0, 0 is reached and the core loops.
    task expect_imm;
        input [4:0] reg_addr;
        input integer expected;
        begin
            emit(inst_i(expected[11:0], 5'd0, 3'b000, 5'd31));
            emit(inst_b(3'b000, reg_addr, 5'd31, 8));
            emit(inst_j(5'd0, 0));
        end
    endtask

    task expect_same_as_x31;
        input [4:0] reg_addr;
        begin
            emit(inst_b(3'b000, reg_addr, 5'd31, 8));
            emit(inst_j(5'd0, 0));
        end
    endtask

    task build_basic_program;
        integer auipc_pc;
        integer jal_pc;
        begin
            for (i = 0; i < `ROM_DEPTH; i = i + 1)
                firmware[i] = `INST_NOP;

            pc = 0;

            // x26/x27 are the shared-GPR completion and pass status.
            emit(inst_i(12'd0, 5'd0, 3'b000, 5'd26));
            emit(inst_i(12'd0, 5'd0, 3'b000, 5'd27));

            emit(inst_i(12'd5, 5'd0, 3'b000, 5'd1));
            emit(inst_i(12'd3, 5'd0, 3'b000, 5'd2));
            emit(inst_i(-12'sd8, 5'd0, 3'b000, 5'd7));

            // RV32I register-register ALU operations.
            emit(inst_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3));
            emit(inst_r(7'b0100000, 5'd2, 5'd3, 3'b000, 5'd4));
            emit(inst_r(7'b0000000, 5'd2, 5'd2, 3'b001, 5'd5));
            emit(inst_r(7'b0000000, 5'd2, 5'd5, 3'b101, 5'd6));
            emit(inst_r(7'b0100000, 5'd2, 5'd7, 3'b101, 5'd8));
            emit(inst_r(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd9));
            emit(inst_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd10));
            emit(inst_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd11));
            emit(inst_r(7'b0000000, 5'd0, 5'd7, 3'b010, 5'd12));
            emit(inst_r(7'b0000000, 5'd0, 5'd7, 3'b011, 5'd13));

            // RV32I immediate ALU operations.
            emit(inst_i(-12'sd2, 5'd1, 3'b000, 5'd14));
            emit(inst_i(12'd0, 5'd7, 3'b010, 5'd15));
            emit(inst_i(12'd0, 5'd7, 3'b011, 5'd16));
            emit(inst_i(12'd3, 5'd1, 3'b100, 5'd17));
            emit(inst_i(12'd2, 5'd1, 3'b110, 5'd18));
            emit(inst_i(12'd3, 5'd1, 3'b111, 5'd19));
            emit(inst_i(12'd2, 5'd2, 3'b001, 5'd20));
            emit(inst_i(12'd2, 5'd20, 3'b101, 5'd21));
            emit(inst_i({7'b0100000, 5'd2}, 5'd7, 3'b101, 5'd22));

            expect_imm(5'd3, 8);
            expect_imm(5'd4, 5);
            expect_imm(5'd5, 24);
            expect_imm(5'd6, 3);
            expect_imm(5'd8, -1);
            expect_imm(5'd9, 6);
            expect_imm(5'd10, 7);
            expect_imm(5'd11, 1);
            expect_imm(5'd12, 1);
            expect_imm(5'd13, 0);
            expect_imm(5'd14, 3);
            expect_imm(5'd15, 1);
            expect_imm(5'd16, 0);
            expect_imm(5'd17, 6);
            expect_imm(5'd18, 7);
            expect_imm(5'd19, 1);
            expect_imm(5'd20, 12);
            expect_imm(5'd21, 3);
            expect_imm(5'd22, -2);

            // LUI and AUIPC use x31 as the expected value.
            emit(inst_u(20'h12345, 5'd23, 7'b0110111));
            emit(inst_u(20'h12345, 5'd31, 7'b0110111));
            expect_same_as_x31(5'd23);

            auipc_pc = pc * 4;
            emit(inst_u(20'h00001, 5'd24, 7'b0010111));
            emit(inst_u(20'h00001, 5'd31, 7'b0110111));
            emit(inst_i(auipc_pc[11:0], 5'd31, 3'b000, 5'd31));
            expect_same_as_x31(5'd24);

            // Taken branch must skip the failure loop.
            emit(inst_b(3'b000, 5'd1, 5'd1, 8));
            emit(inst_j(5'd0, 0));
            emit(inst_i(12'd1, 5'd0, 3'b000, 5'd25));
            expect_imm(5'd25, 1);

            // JAL validates both the target and the saved return address.
            jal_pc = pc * 4;
            emit(inst_j(5'd28, 8));
            emit(inst_j(5'd0, 0));
            emit(inst_i(12'd1, 5'd0, 3'b000, 5'd29));
            expect_imm(5'd28, jal_pc + 4);
            expect_imm(5'd29, 1);

            // Exercise the selected FPGA RAM: write x1 then read it back.
            emit(inst_u(20'h10000, 5'd30, 7'b0110111));
            emit(inst_s(12'd0, 5'd1, 5'd30, 3'b010));
            emit(inst_load(12'd0, 5'd30, 3'b010, 5'd2));
            expect_imm(5'd2, 5);

            emit(inst_i(12'd1, 5'd0, 3'b000, 5'd26));
            emit(inst_i(12'd1, 5'd0, 3'b000, 5'd27));
            emit(inst_j(5'd0, 0));

            program_words = pc;
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*4-1:0] core_name;
        integer cycles;
        reg seen_clear;
        begin
            rst_n = 1'b0;
            chip_sel = core_sel;
            repeat (8) @(posedge clk);
            rst_n = 1'b1;

            seen_clear = 1'b0;
            cycles = 0;
            while (cycles < MAX_CYCLES && !(seen_clear && x26 === 32'd1)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (x26 === 32'd0 && x27 === 32'd0)
                    seen_clear = 1'b1;
            end

            // x26 is written one instruction before x27 in the pass sequence.
            if (seen_clear && x26 === 32'd1) begin
                repeat (20) @(posedge clk);
                #1;
            end

            if (!seen_clear) begin
                $display("G03_BASIC_%0s_FAIL status was not cleared x26=%h x27=%h x1=%h x2=%h if_addr=%h if_req=%b if_rdy=%b if_rsp=%b bridge_tx=%h bridge_rx=%h",
                         core_name, x26, x27,
                         u_soc.u_gpr_top.u_gpr.regs[1], u_soc.u_gpr_top.u_gpr.regs[2],
                         u_soc.core_if_addr[core_sel], u_soc.core_if_req_vld[core_sel],
                         u_soc.core_if_req_rdy[core_sel], u_soc.core_if_rsp_vld[core_sel],
                         bridge_tx, bridge_rx);
                failures = failures + 1;
            end else if (x26 !== 32'd1 || x27 !== 32'd1 || succ !== 1'b0) begin
                $display("G03_BASIC_%0s_FAIL x26=%h x27=%h succ=%b cycles=%0d x1=%h x2=%h x3=%h x7=%h x8=%h x31=%h if_addr=%h if_req=%b if_rdy=%b if_rsp=%b",
                         core_name, x26, x27, succ, cycles,
                         u_soc.u_gpr_top.u_gpr.regs[1], u_soc.u_gpr_top.u_gpr.regs[2],
                         u_soc.u_gpr_top.u_gpr.regs[3], u_soc.u_gpr_top.u_gpr.regs[7],
                         u_soc.u_gpr_top.u_gpr.regs[8], u_soc.u_gpr_top.u_gpr.regs[31],
                         u_soc.core_if_addr[core_sel], u_soc.core_if_req_vld[core_sel],
                         u_soc.core_if_req_rdy[core_sel], u_soc.core_if_rsp_vld[core_sel]);
                failures = failures + 1;
            end else begin
                $display("G03_BASIC_%0s_PASS cycles=%0d succ=%b", core_name, cycles, succ);
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
        route_check_en = 1'b0;
        build_basic_program;

        // Download the same image to the WZC/XYH/XZR shared path and the
        // separate HJX FPGA path.
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        debug_en = 1'b1;
        repeat (10000) @(posedge clk);
        download_program_to_path(2'b00);
        download_program_to_path(2'b10);
        repeat (1000) @(posedge clk);

        // Start every core from the same UART-downloaded image.
        debug_en = 1'b0;
        rst_n = 1'b0;
        repeat (8) @(posedge clk);
        rst_n = 1'b1;

        run_core(2'b00, "WZC");
        run_core(2'b01, "XYH");
        run_core(2'b10, "HJX");
        run_core(2'b11, "XZR");

        if (failures == 0)
            $display("G03_BASIC_ALL_CORES_PASS");
        else
            $display("G03_BASIC_ALL_CORES_FAIL failures=%0d", failures);
        $finish;
    end

    initial begin
        #100000000;
        $display("G03_BASIC_TIMEOUT chip=%b x26=%h x27=%h succ=%b", chip_sel, x26, x27, succ);
        $finish;
    end

    g03_soc #(
        .UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)
    ) u_soc (
        .clk(clk),
        .rst_n_i(rst_n),
        .debug_en_i(debug_en),
        .chip_sel_i(chip_sel),
        .succ(succ),
        .bridge_tx_data_o(bridge_tx),
        .bridge_rx_data_i(bridge_rx),
        .uart_tx_o(uart_tx),
        .uart_rx_i(uart_rx),
        .pwm_o(),
        .i2c_io_ctrl_o(),
        .i2c_scl_i(1'b1),
        .i2c_sda_i(1'b1)
    );

    fpga_top u_fpga (
        .clk(clk),
        .rst_n(rst_n),
        .chip_sel_i(chip_sel),
        .bridge_rx_data_i(bridge_tx),
        .bridge_tx_data_o(bridge_rx),
        .i2c_scl(),
        .i2c_sda()
    );

`ifdef G03_DUMP_VCD
    initial begin
        $dumpfile("tb/g03_basic_instr.vcd");
        $dumpvars(1, tb_g03_basic_instr);
        $dumpvars(1, tb_g03_basic_instr.u_fpga);
        $dumpvars(1, tb_g03_basic_instr.u_fpga.u_bridge_fpga);
        $dumpvars(1, tb_g03_basic_instr.u_fpga.u_bridge_fpga_hjx);
    end
`endif

`ifdef G03_DUMP_FSDB
    initial begin
        $fsdbDumpfile("build/g03_basic_instr/g03_basic_instr.fsdb");
        $fsdbDumpvars(0, tb_g03_basic_instr);
        $fsdbDumpon;
    end
`endif

endmodule
