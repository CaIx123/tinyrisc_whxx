`timescale 1ns / 1ps
`include "macros.v"

// Sequential FPGA stress regression: program -> run -> reset, repeated for
// every retained RV32I basic image and each chip-select value.
module tb_g03_fpga_stress;
    localparam integer MAX_CYCLES = 100000;
    localparam integer UART_DEBUG_BAUD_DIV = 5;
    wire clk, rst_n, succ, uart_tx;
    wire [3:0] pwm;
    wire [1:0] i2c_ctrl;
    tri1 i2c_scl, i2c_sda;
    wire [31:0] x26, x27;
    integer failures, test_index, chip_index;
    reg done;

    task load_image;
        input integer id;
        begin
            u_env.clear_program;
            case (id)
                0: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_add.data", u_env.firmware, 0, 222); u_env.program_words = 223; end
                1: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_andi.data", u_env.firmware, 0, 161); u_env.program_words = 162; end
                2: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_auipc.data", u_env.firmware, 0, 49); u_env.program_words = 50; end
                3: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_beq.data", u_env.firmware, 0, 225); u_env.program_words = 226; end
                4: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_bge.data", u_env.firmware, 0, 241); u_env.program_words = 242; end
                5: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_bgeu.data", u_env.firmware, 0, 221); u_env.program_words = 222; end
                6: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_blt.data", u_env.firmware, 0, 225); u_env.program_words = 226; end
                7: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_bltu.data", u_env.firmware, 0, 241); u_env.program_words = 242; end
                8: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_bne.data", u_env.firmware, 0, 225); u_env.program_words = 226; end
                9: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_jal.data", u_env.firmware, 0, 65); u_env.program_words = 66; end
                10: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_jalr.data", u_env.firmware, 0, 97); u_env.program_words = 98; end
                11: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_lui.data", u_env.firmware, 0, 65); u_env.program_words = 66; end
                12: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_ori.data", u_env.firmware, 0, 161); u_env.program_words = 162; end
                13: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_simple.data", u_env.firmware, 0, 49); u_env.program_words = 50; end
                14: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_slli.data", u_env.firmware, 0, 209); u_env.program_words = 210; end
                15: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_slti.data", u_env.firmware, 0, 209); u_env.program_words = 210; end
                16: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_sltiu.data", u_env.firmware, 0, 209); u_env.program_words = 210; end
                17: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_srai.data", u_env.firmware, 0, 225); u_env.program_words = 226; end
                18: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_srli.data", u_env.firmware, 0, 209); u_env.program_words = 210; end
                default: begin $readmemh("../../fpga/test/example/Baisc_Inst_Example/inst_xori.data", u_env.firmware, 0, 161); u_env.program_words = 162; end
            endcase
        end
    endtask

    task run_one;
        input integer id;
        input [1:0] chip;
        integer cycles;
        reg seen_clear;
        begin
            load_image(id);
            u_env.prepare_uart_download;
            u_env.download_program_to_path(chip);
            u_env.start_core(chip);
            cycles = 0; seen_clear = 1'b0;
            while (cycles < MAX_CYCLES && !(seen_clear && x26 === 32'd1)) begin
                @(posedge clk); #1; cycles = cycles + 1;
                if (x26 === 32'd0 && x27 === 32'd0) seen_clear = 1'b1;
            end
            // Match the single-image FPGA TB: x27 is the final completion
            // writeback and is observable a few clocks after x26.
            if (seen_clear && x26 === 32'd1) repeat (20) @(posedge clk);
            if (!seen_clear || x26 !== 32'd1 || x27 !== 32'd1 || succ !== 1'b0) begin
                $display("G03_STRESS_FAIL image=%0d chip=%b x26=%h x27=%h cycles=%0d", id, chip, x26, x27, cycles);
                failures = failures + 1;
            end else
                $display("G03_STRESS_PASS image=%0d chip=%b cycles=%0d", id, chip, cycles);
            // Mandatory reset between two program/test tasks.
            u_env.rst_n_o = 1'b0; u_env.debug_en_o = 1'b0;
            repeat (8) @(posedge clk);
            u_env.rst_n_o = 1'b1;
            repeat (8) @(posedge clk);
        end
    endtask

    initial begin
        failures = 0; done = 1'b0;
        @(posedge clk);
        for (chip_index = 0; chip_index < 4; chip_index = chip_index + 1)
            for (test_index = 0; test_index < 20; test_index = test_index + 1)
                run_one(test_index, chip_index[1:0]);
        if (u_env.download_failures != 0 || u_env.route_failures != 0) failures = failures + 1;
        if (failures == 0) $display("G03_STRESS_ALL_PASS tests=80");
        else $display("G03_STRESS_ALL_FAIL failures=%0d", failures);
        done = 1'b1; $finish;
    end

    initial begin
        #1000000000;
        if (!done) begin $display("G03_STRESS_TIMEOUT"); $finish; end
    end

    g03_tb_uart_env #(.UART_DEBUG_BAUD_DIV(UART_DEBUG_BAUD_DIV)) u_env (
        .clk_o(clk), .rst_n_o(rst_n), .debug_en_o(), .chip_sel_o(), .uart_rx_o(),
        .uart_tx_o(uart_tx), .succ_o(succ), .bridge_tx_o(), .bridge_rx_o(), .pwm_o(pwm),
        .i2c_io_ctrl_o(i2c_ctrl), .i2c_scl_io(i2c_scl), .i2c_sda_io(i2c_sda), .x26_o(x26), .x27_o(x27)
    );
endmodule
