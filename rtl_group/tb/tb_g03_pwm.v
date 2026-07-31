`timescale 1ns / 1ps

`include "../top/macros.v"

// PWM peripheral test.  The common program configures all four channels with
// distinct periods and high times, then verifies their register map and
// waveforms at the external PWM pins after the UART-loaded image has run.
module tb_g03_pwm;

    localparam integer MAX_CORE_CYCLES = 30000;
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

    task emit_nop;
        begin
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
        end
    endtask

    task write_pwm_register;
        input [19:0] address_upper;
        input [4:0] value_reg;
        begin
            u_env.emit(inst_u(address_upper, 5'd1, 7'b0110111));
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            u_env.emit(inst_s(12'd0, value_reg, 5'd1, 3'b010));
        end
    endtask

    task build_program;
        begin
            // Configure every PWM channel with a distinct duty cycle:
            // channel 0: period 8, high 3; channel 1: period 7, high 2;
            // channel 2: period 5, high 4; channel 3: period 4, high 1.
            // Keep the values in separate registers because the four core
            // pipelines have different forwarding schedules around stores.
            u_env.emit(inst_i(12'd8, 5'd0, 3'b000, 5'd2));
            u_env.emit(inst_i(12'd3, 5'd0, 3'b000, 5'd3));
            u_env.emit(inst_i(12'd7, 5'd0, 3'b000, 5'd4));
            u_env.emit(inst_i(12'd2, 5'd0, 3'b000, 5'd5));
            u_env.emit(inst_i(12'd5, 5'd0, 3'b000, 5'd6));
            u_env.emit(inst_i(12'd4, 5'd0, 3'b000, 5'd7));
            u_env.emit(inst_i(12'd4, 5'd0, 3'b000, 5'd8));
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd9));
            u_env.emit(inst_i(12'd15, 5'd0, 3'b000, 5'd10));
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;

            write_pwm_register(20'h60000, 5'd2);
            write_pwm_register(20'h60010, 5'd4);
            write_pwm_register(20'h60020, 5'd6);
            write_pwm_register(20'h60030, 5'd8);
            write_pwm_register(20'h60100, 5'd3);
            write_pwm_register(20'h60110, 5'd5);
            write_pwm_register(20'h60120, 5'd7);
            write_pwm_register(20'h60130, 5'd9);
            write_pwm_register(20'h60040, 5'd10);
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;

            // The shared GPR array is not reset in hardware; initialize test
            // state only after the startup stores have reached the peripheral.
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd27));
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            emit_nop;
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd27));
            emit_nop;
            u_env.emit(INST_JAL_ZERO);
        end
    endtask

    task check_pwm_registers;
        input [8*3-1:0] core_name;
        begin
            if (u_env.u_soc.u_perips_top.u_pwm.reg_a0 !== 32'd8 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_a1 !== 32'd7 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_a2 !== 32'd5 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_a3 !== 32'd4 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_b0 !== 32'd3 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_b1 !== 32'd2 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_b2 !== 32'd4 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_b3 !== 32'd1 ||
                u_env.u_soc.u_perips_top.u_pwm.reg_c  !== 32'h0000000f) begin
                $display("G03_PWM_%0s_FAIL registers a=%h/%h/%h/%h b=%h/%h/%h/%h c=%h", core_name,
                         u_env.u_soc.u_perips_top.u_pwm.reg_a0, u_env.u_soc.u_perips_top.u_pwm.reg_a1,
                         u_env.u_soc.u_perips_top.u_pwm.reg_a2, u_env.u_soc.u_perips_top.u_pwm.reg_a3,
                         u_env.u_soc.u_perips_top.u_pwm.reg_b0, u_env.u_soc.u_perips_top.u_pwm.reg_b1,
                         u_env.u_soc.u_perips_top.u_pwm.reg_b2, u_env.u_soc.u_perips_top.u_pwm.reg_b3,
                         u_env.u_soc.u_perips_top.u_pwm.reg_c);
                failures = failures + 1;
            end else begin
                $display("G03_PWM_%0s_REGISTERS_PASS", core_name);
            end
        end
    endtask

    task check_pwm_channel;
        input [8*3-1:0] core_name;
        input [1:0] channel;
        input integer expected_period;
        input integer expected_high;
        integer wait_cycles;
        integer sample_index;
        integer expected_level;
        begin
            wait_cycles = 0;
            while (wait_cycles < (expected_period * 2) && pwm[channel] !== 1'b0) begin
                @(posedge clk);
                #1;
                wait_cycles = wait_cycles + 1;
            end
            if (pwm[channel] !== 1'b0) begin
                $display("G03_PWM_%0s_FAIL channel%0d never deasserted pwm=%b", core_name, channel, pwm);
                failures = failures + 1;
            end else begin
                wait_cycles = 0;
                while (wait_cycles < (expected_period * 2) && pwm[channel] !== 1'b1) begin
                    @(posedge clk);
                    #1;
                    wait_cycles = wait_cycles + 1;
                end
                if (pwm[channel] !== 1'b1) begin
                    $display("G03_PWM_%0s_FAIL channel%0d never asserted pwm=%b", core_name, channel, pwm);
                    failures = failures + 1;
                end else begin
                    for (sample_index = 0; sample_index < expected_period; sample_index = sample_index + 1) begin
                        expected_level = sample_index < expected_high;
                        if (pwm[channel] !== expected_level[0]) begin
                            $display("G03_PWM_%0s_FAIL channel%0d sample=%0d value=%b expected=%b pwm=%b", core_name,
                                     channel, sample_index, pwm[channel], expected_level[0], pwm);
                            failures = failures + 1;
                        end
                        if (sample_index != expected_period - 1) begin
                            @(posedge clk);
                            #1;
                        end
                    end
                    $display("G03_PWM_%0s_CHANNEL%0d_WAVEFORM_PASS period=%0d high=%0d", core_name,
                             channel, expected_period, expected_high);
                end
            end
        end
    endtask

    task check_pwm_waveforms;
        input [8*3-1:0] core_name;
        begin
            check_pwm_channel(core_name, 2'd0, 8, 3);
            check_pwm_channel(core_name, 2'd1, 7, 2);
            check_pwm_channel(core_name, 2'd2, 5, 4);
            check_pwm_channel(core_name, 2'd3, 4, 1);
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*3-1:0] core_name;
        integer cycles;
        integer startup_cycles;
        begin
            startup_cycles = 0;
            while (startup_cycles < 1000 && x27 !== 32'd0) begin
                @(posedge clk);
                #1;
                startup_cycles = startup_cycles + 1;
            end
            if (x27 !== 32'd0) begin
                $display("G03_PWM_%0s_FAIL startup status x27=%h", core_name, x27);
                failures = failures + 1;
            end

            cycles = 0;
            while (cycles < MAX_CORE_CYCLES && x27 !== 32'd1) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (x27 !== 32'd1 || succ !== 1'b0) begin
                $display("G03_PWM_%0s_FAIL x27=%h succ=%b cycles=%0d pwm=%b a0=%h b0=%h c=%h", core_name, x27,
                         succ, cycles, pwm, u_env.u_soc.u_perips_top.u_pwm.reg_a0,
                         u_env.u_soc.u_perips_top.u_pwm.reg_b0, u_env.u_soc.u_perips_top.u_pwm.reg_c);
                failures = failures + 1;
            end else begin
                check_pwm_registers(core_name);
                check_pwm_waveforms(core_name);
                $display("G03_PWM_%0s_PASS", core_name);
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
            $display("G03_PWM_ALL_CORES_PASS");
        else
            $display("G03_PWM_ALL_CORES_FAIL failures=%0d", failures);
        test_done = 1'b1;
        $finish;
    end

    initial begin
        #30000000;
        if (!test_done) begin
            $display("G03_PWM_TIMEOUT chip=%b x26=%h x27=%h pwm=%b", u_env.chip_sel_o, x26, x27, pwm);
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
        $dumpfile("tb/g03_pwm.vcd");
        $dumpvars(0, tb_g03_pwm);
    end
`endif

`ifdef G03_DUMP_FSDB
    initial begin
        $fsdbDumpfile("build/g03_pwm/g03_pwm.fsdb");
        $fsdbDumpvars(0, tb_g03_pwm);
        $fsdbDumpon;
    end
`endif

endmodule
