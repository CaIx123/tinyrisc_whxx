`timescale 1ns / 1ps

`include "../top/macros.v"

// rT conformance test.  All cores read the same LM75 behavioral model through
// the shared I2C peripheral after the program is delivered over uart_debug.
module tb_g03_rt;

    localparam integer MAX_CORE_CYCLES = 40000;
    localparam integer UART_DEBUG_BAUD_DIV = 16;
    localparam [31:0] EXPECTED_TEMP = 32'd61;
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

    task build_program;
        begin
            // The GPR array is intentionally not reset in the silicon RTL.
            // Let the fetch pipeline settle before software clears markers.
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd26));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd27));
            // rT is custom opcode funct3=001 and writes the temperature to x5.
            u_env.emit(inst_custom(12'd0, 5'd0, 3'b001, 5'd5));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(EXPECTED_TEMP[11:0], 5'd0, 3'b000, 5'd31));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_b(3'b000, 5'd5, 5'd31, 8));
            u_env.emit(INST_JAL_ZERO);
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd26));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(inst_i(12'd1, 5'd0, 3'b000, 5'd27));
            u_env.emit(inst_i(12'd0, 5'd0, 3'b000, 5'd0));
            u_env.emit(INST_JAL_ZERO);
        end
    endtask

    task run_core;
        input [1:0] core_sel;
        input [8*3-1:0] core_name;
        integer cycles;
        integer reset_cycles;
        begin
            reset_cycles = 0;
            while (reset_cycles < 1000 &&
                   !(x26 === 32'd0 && x27 === 32'd0)) begin
                @(posedge clk);
                #1;
                reset_cycles = reset_cycles + 1;
            end
            if (x26 !== 32'd0 || x27 !== 32'd0) begin
                $display("G03_RT_%0s_FAIL startup markers x26=%h x27=%h", core_name, x26, x27);
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
                $display("G03_RT_%0s_FAIL x26=%h x27=%h x5=%h x31=%h succ=%b cycles=%0d", core_name, x26, x27,
                         u_env.u_soc.u_gpr_top.u_gpr.regs[5], u_env.u_soc.u_gpr_top.u_gpr.regs[31], succ, cycles);
                failures = failures + 1;
            end else begin
                $display("G03_RT_%0s_PASS temp=%0d cycles=%0d", core_name, EXPECTED_TEMP, cycles);
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
            $display("G03_RT_ALL_CORES_PASS");
        else
            $display("G03_RT_ALL_CORES_FAIL failures=%0d", failures);
        test_done = 1'b1;
        $finish;
    end

    initial begin
        #30000000;
        if (!test_done) begin
            $display("G03_RT_TIMEOUT chip=%b x26=%h x27=%h i2c_ctrl=%b", u_env.chip_sel_o, x26, x27, i2c_ctrl);
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
        $dumpfile("tb/g03_rt.vcd");
        $dumpvars(0, tb_g03_rt);
    end
`endif

`ifdef G03_DUMP_FSDB
    initial begin
        $fsdbDumpfile("build/g03_rt/g03_rt.fsdb");
        $fsdbDumpvars(0, tb_g03_rt);
        $fsdbDumpon;
    end
`endif

endmodule
