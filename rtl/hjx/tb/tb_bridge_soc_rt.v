`timescale 1 ns / 1 ps

`include "../core/defines.v"
`include "../macros.v"

module tb_bridge_soc_rt;

    localparam integer UART_BIT_CYCLES = 434;
    localparam [6:0] LM75_ADDR = 7'h48;
    localparam [7:0] EXPECT_TEMP = 8'h1a;
    localparam [15:0] LM75_TEMP_RAW = {1'b0, EXPECT_TEMP, 7'h00};
    localparam [7:0] LM75_TEMP_MSB = LM75_TEMP_RAW[15:8];
    localparam [7:0] LM75_TEMP_LSB = LM75_TEMP_RAW[7:0];

    reg clk;
    reg rst_n;

    wire uart_tx_pin;
    wire[`PWIDTH_O-1:0] bridge_tx;
    wire[`PWIDTH_I-1:0] bridge_rx;
    tri1 iic_sda_pin;
    tri1 iic_scl_pin;

    reg lm75_sda_drive_low;
    reg[7:0] got_uart;
    reg phase_iic_addr_pass;
    reg phase_iic_data_pass;

    wire[31:0] x10 = u_soc.u_tinyriscv_core.u_gpr_reg.regs[10];

    assign iic_sda_pin = lm75_sda_drive_low ? 1'b0 : 1'bz;

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        lm75_sda_drive_low = 1'b0;
        got_uart = 8'h0;
        phase_iic_addr_pass = 1'b0;
        phase_iic_data_pass = 1'b0;

        // lui  a5, 0x30000       // UART base
        // addi a4, x0, 1
        // sw   a4, 0(a5)         // UART_CTRL = 1
        // rT   a0                // .insn i 0x2f, 1, a0, x0, 0
        // lui  a5, 0x30000
        // addi a5, a5, 12
        // sw   a0, 0(a5)         // UART_TXDATA = temperature low byte
        // jal  x0, 0
        u_fpga.u_exrom._ram[0] = 32'h300007b7;
        u_fpga.u_exrom._ram[1] = 32'h00100713;
        u_fpga.u_exrom._ram[2] = 32'h00e7a023;
        u_fpga.u_exrom._ram[3] = 32'h0000152f;
        u_fpga.u_exrom._ram[4] = 32'h300007b7;
        u_fpga.u_exrom._ram[5] = 32'h00c78793;
        u_fpga.u_exrom._ram[6] = 32'h00a7a023;
        u_fpga.u_exrom._ram[7] = 32'h0000006f;

        #100;
        rst_n = 1'b1;

        wait (u_soc.u_tinyriscv_core.u_exu.u_exu_ext_rt.state == 4'd1);
        $display("BRIDGE_SOC_RT_PHASE0_PASS rt_started");

        recv_uart_byte(got_uart);

        if (got_uart == EXPECT_TEMP && x10 == {24'h0, EXPECT_TEMP} &&
            phase_iic_addr_pass && phase_iic_data_pass) begin
            $display("BRIDGE_SOC_RT_PHASE3_PASS got=%h x10=%h", got_uart, x10);
            $display("BRIDGE_SOC_RT_PASS");
        end else begin
            $display("BRIDGE_SOC_RT_FAIL got=%h exp=%h x10=%h addr_phase=%b data_phase=%b",
                     got_uart, EXPECT_TEMP, x10, phase_iic_addr_pass, phase_iic_data_pass);
            $finish;
        end

        $finish;
    end

    initial begin
        #20000000;
        $display("BRIDGE_SOC_RT_TIMEOUT got=%h x10=%h scl=%b sda=%b rt_state=%0d iic_state=%0d addr_phase=%b data_phase=%b",
                 got_uart, x10, iic_scl_pin, iic_sda_pin,
                 u_soc.u_tinyriscv_core.u_exu.u_exu_ext_rt.state,
                 u_soc.u_iic.state, phase_iic_addr_pass, phase_iic_data_pass);
        $finish;
    end

    task recv_uart_byte;
        output[7:0] data;
        integer b;
        begin
            data = 8'h00;
            @(negedge uart_tx_pin);
            repeat (UART_BIT_CYCLES / 2) @(posedge clk);
            #1;
            if (uart_tx_pin != 1'b0) begin
                $display("BRIDGE_SOC_RT_FAIL bad_start_bit uart_tx=%b", uart_tx_pin);
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

    initial begin
        forever begin
            lm75_wait_start;
            lm75_handle_read_transaction;
        end
    end

    task lm75_wait_start;
        begin
            lm75_sda_drive_low = 1'b0;
            @(negedge iic_sda_pin);
            while (iic_scl_pin !== 1'b1) begin
                @(negedge iic_sda_pin);
            end
        end
    endtask

    task lm75_read_master_byte;
        output[7:0] data;
        integer b;
        begin
            data = 8'h00;
            for (b = 7; b >= 0; b = b - 1) begin
                @(posedge iic_scl_pin);
                #1;
                data[b] = iic_sda_pin;
                @(negedge iic_scl_pin);
            end
        end
    endtask

    task lm75_ack;
        begin
            lm75_sda_drive_low = 1'b1;
            @(posedge iic_scl_pin);
            @(negedge iic_scl_pin);
            lm75_sda_drive_low = 1'b0;
        end
    endtask

    task lm75_send_byte;
        input[7:0] data;
        output master_ack;
        integer b;
        begin
            for (b = 7; b >= 0; b = b - 1) begin
                lm75_sda_drive_low = ~data[b];
                @(posedge iic_scl_pin);
                @(negedge iic_scl_pin);
            end
            lm75_sda_drive_low = 1'b0;
            @(posedge iic_scl_pin);
            #1;
            master_ack = (iic_sda_pin == 1'b0);
            @(negedge iic_scl_pin);
        end
    endtask

    task lm75_handle_read_transaction;
        reg[7:0] addr_byte;
        reg master_ack;
        begin
            lm75_read_master_byte(addr_byte);
            if (addr_byte == {LM75_ADDR, 1'b1}) begin
                phase_iic_addr_pass = 1'b1;
                $display("BRIDGE_SOC_RT_PHASE1_PASS lm75_addr=%h", addr_byte);
                lm75_ack;
                lm75_send_byte(LM75_TEMP_MSB, master_ack);
                if (!master_ack) begin
                    $display("BRIDGE_SOC_RT_FAIL lm75_first_byte_not_acked");
                    $finish;
                end
                lm75_send_byte(LM75_TEMP_LSB, master_ack);
                if (master_ack) begin
                    $display("BRIDGE_SOC_RT_FAIL lm75_second_byte_acked");
                    $finish;
                end
                phase_iic_data_pass = 1'b1;
                $display("BRIDGE_SOC_RT_PHASE2_PASS raw=%h temp=%h", LM75_TEMP_RAW, EXPECT_TEMP);
            end else begin
                $display("BRIDGE_SOC_RT_FAIL lm75_addr=%h expected=%h", addr_byte, {LM75_ADDR, 1'b1});
                $finish;
            end
        end
    endtask

    tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst_ext_i(rst_n),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(1'b1),
        .uart_debug_pin(1'b0),
        .PWM_out_pin(),
        .IIC_SDA_pin(iic_sda_pin),
        .IIC_SCL_pin(iic_scl_pin),
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
