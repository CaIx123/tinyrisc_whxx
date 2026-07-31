`timescale 1ns / 1ps

`include "../top/macros.v"

// IF conformance test.  It checks the no-fire result, the UART fire path, and
// the immediate-add path on every core after UART-downloading the same image.
module tb_g03_if;

    localparam integer MAX_CORE_CYCLES = 100000;
    localparam integer MAX_UART_WAIT_CYCLES = 100000;
    localparam integer UART_DEBUG_BAUD_DIV = 16;
    localparam [31:0] INST_JAL_ZERO = 32'h0000006f;

    wire clk;
    wire rst_n;
    wire succ;
    wire uart_tx;
    wire [3:0] pwm;
    wire [1:0] i2c_ctrl;
    wire [31:0] x26;
    wire [31:0] x27;
    integer failures;
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

    function [31:0] inst_custom;
        input [11:0] imm;
        input [4:0] rs1;
        input [2:0] funct3;
        input [4:0] rd;
        begin
            inst_custom = {imm, rs1, funct3, rd, 7'b0101111};
        end
    endfunction

    task emit_nop;
        begin
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
        end
    endtask

    task emit_expect;
        input [4:0] value_reg;
        input [11:0] expected;
        begin
            u_env.emit(inst_i(expected, 5'd0, 3'b000, 5'd30));
            emit_nop;
            emit_nop;
            u_env.emit(inst_b(3'b000, value_reg, 5'd30, 8));
            u_env.emit(INST_JAL_ZERO);
        end
    endtask

    task build_program;
        begin
            // Restore a short UART divisor after leaving uart_debug mode.
            u_env.emit(inst_u(20'h30000, 5'd15, 7'b0110111));
            u_env.emit(inst_i(12'd16, 5'd0, 3'b000, 5'd14));
            u_env.emit(inst_s(12'd8, 5'd14, 5'd15, 3'b010));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd26));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd27));

            // x1 < x31: IF returns x1 without transmitting.
            u_env.emit(inst_i(12'd63, 5'd0, 3'b000, 5'd1));
            u_env.emit(inst_i(12'd64, 5'd0, 3'b000, 5'd31));
            emit_nop;
            emit_nop;
            u_env.emit(inst_custom(12'd0, 5'd1, 3'b010, 5'd5));
            emit_nop;
            emit_nop;

            // x6 >= x31: IF emits 'A' and returns zero in x7.
            u_env.emit(inst_i(12'd65, 5'd0, 3'b000, 5'd6));
            emit_nop;
            emit_nop;
            u_env.emit(inst_custom(12'd0, 5'd6, 3'b010, 5'd7));
            emit_nop;
            emit_nop;

            // A non-zero immediate follows the local add path: 65 + 7 = 72.
            u_env.emit(inst_custom(12'd7, 5'd6, 3'b010, 5'd8));
            emit_nop;
            emit_nop;

            emit_expect(5'd5, 12'd63);
            emit_expect(5'd7, 12'd0);
            emit_expect(5'd8, 12'd72);
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd26));
            emit_nop;
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd27));
            emit_nop;
            u_env.emit(INST_JAL_ZERO);
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*3-1:0] core_name;
        integer cycles;
        integer startup_cycles;
        reg [7:0] received;
        reg timed_out;
        begin
            startup_cycles = 0;
            while (startup_cycles < 1000 &&
                   !(x26 === 32'd0 && x27 === 32'd0)) begin
                @(posedge clk);
                #1;
                startup_cycles = startup_cycles + 1;
            end
            if (x26 !== 32'd0 || x27 !== 32'd0) begin
                $display("G03_IF_%0s_FAIL startup markers x26=%h x27=%h", core_name, x26, x27);
                failures = failures + 1;
            end

            u_env.recv_uart_byte_timeout(MAX_UART_WAIT_CYCLES, received, timed_out);
            if (timed_out || received !== "A") begin
                $display("G03_IF_%0s_FAIL UART data=%h timeout=%b", core_name, received, timed_out);
                failures = failures + 1;
            end

            cycles = 0;
            while (cycles < MAX_CORE_CYCLES &&
                   !(x26 === 32'd1 && x27 === 32'd1)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (x26 !== 32'd1 || x27 !== 32'd1 || succ !== 1'b0) begin
                $display("G03_IF_%0s_FAIL x26=%h x27=%h x5=%h x7=%h x8=%h succ=%b cycles=%0d", core_name, x26, x27,
                         u_env.u_soc.u_gpr_top.u_gpr.regs[5], u_env.u_soc.u_gpr_top.u_gpr.regs[7],
                         u_env.u_soc.u_gpr_top.u_gpr.regs[8], succ, cycles);
                failures = failures + 1;
            end else begin
                $display("G03_IF_%0s_PASS cycles=%0d", core_name, cycles);
            end
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
            $display("G03_IF_ALL_CORES_PASS");
        else
            $display("G03_IF_ALL_CORES_FAIL failures=%0d", failures);
        test_done = 1'b1;
        $finish;
    end

    initial begin
        #30000000;
        if (!test_done) begin
            $display("G03_IF_TIMEOUT chip=%b x26=%h x27=%h tx=%b", u_env.chip_sel_o, x26, x27, uart_tx);
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
        $dumpfile("tb/g03_if.vcd");
        $dumpvars(0, tb_g03_if);
    end
`endif

`ifdef G03_DUMP_FSDB
    initial begin
        $fsdbDumpfile("build/g03_if/g03_if.fsdb");
        $fsdbDumpvars(0, tb_g03_if);
        $fsdbDumpon;
    end
`endif

endmodule
