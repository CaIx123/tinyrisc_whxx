`timescale 1ns / 1ps

`include "../top/macros.v"

// sID conformance test.  The instruction image is loaded through uart_debug
// before each selected core is allowed to execute it.
module tb_g03_sid;

    localparam integer MAX_CORE_CYCLES = 200000;
    localparam integer MAX_UART_WAIT_CYCLES = 100000;
    localparam integer UART_DEBUG_BAUD_DIV = 16;
    localparam [31:0] INST_JAL_ZERO = 32'h0000006f;

    wire clk;
    wire rst_n;
    wire uart_tx;
    wire succ;
    wire [3:0] pwm;
    wire [1:0] i2c_ctrl;
    wire [31:0] x26;
    wire [31:0] x27;
    integer failures;
    integer index;
    reg test_done;

    function [31:0] inst_i;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_i = {imm, rs1, funct3, rd, 7'b0010011};
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

    function [31:0] inst_s;
        input [11:0] imm;
        input [4:0] rs2;
        input [4:0] rs1;
        input [2:0] funct3;
        begin
            inst_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
        end
    endfunction

    function [31:0] inst_custom;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_custom = {imm, rs1, funct3, rd, 7'b0101111};
        end
    endfunction

    function [7:0] expected_sid_char;
        input [1:0] core_sel;
        input [3:0] char_index;
        begin
            case (core_sel)
                2'b00: begin
                    case (char_index)
                        0: expected_sid_char = "2";
                        1: expected_sid_char = "0";
                        2: expected_sid_char = "2";
                        3: expected_sid_char = "5";
                        4: expected_sid_char = "2";
                        5: expected_sid_char = "1";
                        6: expected_sid_char = "0";
                        7: expected_sid_char = "9";
                        8: expected_sid_char = "1";
                        default: expected_sid_char = "3";
                    endcase
                end
                2'b01: begin
                    case (char_index)
                        0: expected_sid_char = "2";
                        1: expected_sid_char = "0";
                        2: expected_sid_char = "2";
                        3: expected_sid_char = "5";
                        4: expected_sid_char = "2";
                        5: expected_sid_char = "1";
                        6: expected_sid_char = "0";
                        7: expected_sid_char = "8";
                        8: expected_sid_char = "7";
                        default: expected_sid_char = "9";
                    endcase
                end
                2'b11: begin
                    case (char_index)
                        0: expected_sid_char = "2";
                        1: expected_sid_char = "0";
                        2: expected_sid_char = "2";
                        3: expected_sid_char = "5";
                        4: expected_sid_char = "3";
                        5: expected_sid_char = "1";
                        6: expected_sid_char = "0";
                        7: expected_sid_char = "8";
                        8: expected_sid_char = "3";
                        default: expected_sid_char = "6";
                    endcase
                end
                default: begin
                    case (char_index)
                        0: expected_sid_char = "2";
                        1: expected_sid_char = "0";
                        2: expected_sid_char = "2";
                        3: expected_sid_char = "2";
                        4: expected_sid_char = "0";
                        5: expected_sid_char = "1";
                        6: expected_sid_char = "2";
                        7: expected_sid_char = "6";
                        8: expected_sid_char = "6";
                        default: expected_sid_char = "5";
                    endcase
                end
            endcase
        end
    endfunction

    task build_program;
        begin
            // Restore the short UART divisor after the reset used to leave
            // uart_debug mode, then invoke sID (funct3=000).
            u_env.emit(inst_u(20'h30000, 5'd15, 7'b0110111));
            u_env.emit(inst_i(12'd16, 5'd0, 3'b000, 5'd14));
            u_env.emit(inst_s(12'd8, 5'd14, 5'd15, 3'b010));
            // The physical GPR has no reset.  Clear the software markers
            // after the pipeline's startup instructions, before sID begins.
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd26));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd27));
            u_env.emit(inst_custom(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd26));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd27));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(INST_JAL_ZERO);
        end
    endtask

    task wait_for_pass_markers;
        input [1:0] core_sel;
        input [8*3-1:0] core_name;
        integer cycles;
        begin
            cycles = 0;
            while (cycles < MAX_CORE_CYCLES &&
                   !(x26 === 32'd1 && x27 === 32'd1)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (x26 !== 32'd1 || x27 !== 32'd1 || succ !== 1'b0) begin
                $display("G03_SID_%0s_FAIL markers x26=%h x27=%h succ=%b cycles=%0d", core_name, x26, x27, succ, cycles);
                failures = failures + 1;
            end else begin
                $display("G03_SID_%0s_MARKERS_PASS cycles=%0d", core_name, cycles);
            end
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*3-1:0] core_name;
        reg [7:0] received;
        reg timed_out;
        reg serial_ok;
        integer reset_cycles;
        begin
            serial_ok = 1'b1;
            reset_cycles = 0;
            while (reset_cycles < 1000 &&
                   !(x26 === 32'd0 && x27 === 32'd0)) begin
                @(posedge clk);
                #1;
                reset_cycles = reset_cycles + 1;
            end
            if (x26 !== 32'd0 || x27 !== 32'd0) begin
                $display("G03_SID_%0s_FAIL startup markers x26=%h x27=%h", core_name, x26, x27);
                failures = failures + 1;
                serial_ok = 1'b0;
            end
            for (index = 0; index < 10; index = index + 1) begin
                u_env.recv_uart_byte_timeout(MAX_UART_WAIT_CYCLES, received, timed_out);
                if (timed_out) begin
                    $display("G03_SID_%0s_FAIL UART timeout at char=%0d", core_name, index);
                    failures = failures + 1;
                    serial_ok = 1'b0;
                    index = 10;
                end else if (received !== expected_sid_char(core_sel, index[3:0])) begin
                    $display("G03_SID_%0s_FAIL char[%0d]=%h expected=%h", core_name, index, received, expected_sid_char(core_sel, index[3:0]));
                    failures = failures + 1;
                    serial_ok = 1'b0;
                end
            end
            wait_for_pass_markers(core_sel, core_name);
            if (serial_ok)
                $display("G03_SID_%0s_SERIAL_PASS", core_name);
        end
    endtask

    initial begin
        failures = 0;
        test_done = 1'b0;

        @(posedge clk);
        u_env.clear_program;
        build_program;
        u_env.prepare_uart_download;
        u_env.download_program_to_path(2'b00);
        u_env.start_core(2'b00);
        run_core(2'b00, "WZC");

        u_env.prepare_uart_download;
        u_env.download_program_to_path(2'b01);
        u_env.start_core(2'b01);
        run_core(2'b01, "XYH");

        u_env.prepare_uart_download;
        u_env.download_program_to_path(2'b10);
        u_env.start_core(2'b10);
        run_core(2'b10, "HJX");

        u_env.prepare_uart_download;
        u_env.download_program_to_path(2'b11);
        u_env.start_core(2'b11);
        run_core(2'b11, "XZR");

        if (u_env.download_failures != 0 || u_env.route_failures != 0)
            failures = failures + 1;

        if (failures == 0)
            $display("G03_SID_ALL_CORES_PASS");
        else
            $display("G03_SID_ALL_CORES_FAIL failures=%0d", failures);
        test_done = 1'b1;
        $finish;
    end

    initial begin
        #5000000;
        if (!test_done) begin
            $display("G03_SID_TIMEOUT chip=%b x26=%h x27=%h tx=%b", u_env.chip_sel_o, x26, x27, uart_tx);
            $finish;
        end
    end

    g03_tb_uart_env #(
        .UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)
    ) u_env (
        .clk_o(clk),
        .rst_n_o(rst_n),
        .debug_en_o(),
        .chip_sel_o(),
        .uart_rx_o(),
        .uart_tx_o(uart_tx),
        .succ_o(succ),
        .bridge_tx_o(),
        .bridge_rx_o(),
        .pwm_o(pwm),
        .i2c_io_ctrl_o(i2c_ctrl),
        .x26_o(x26),
        .x27_o(x27)
    );

`ifdef G03_DUMP_VCD
    initial begin
        $dumpfile("tb/g03_sid.vcd");
        $dumpvars(0, tb_g03_sid);
    end
`endif

`ifdef G03_DUMP_FSDB
    initial begin
        $fsdbDumpfile("build/g03_sid/g03_sid.fsdb");
        $fsdbDumpvars(0, tb_g03_sid);
        $fsdbDumpon;
    end
`endif

endmodule
