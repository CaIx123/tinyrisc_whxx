`include "macros.v"

module g03_top_IO(

    input wire clk,
    input wire rst_n_i,
    input wire debug_en_i,
    input wire[1:0] chip_sel_i,

    output wire succ,

    output wire[`BRIDGE_WIDTH-1:0] bridge_tx_data_o,
    input wire[`BRIDGE_WIDTH-1:0] bridge_rx_data_i,

    output wire uart_tx_o,
    input wire uart_rx_i,

    output wire[3:0] pwm_o,

    inout wire i2c_scl,
    inout wire i2c_sda

    );

    wire clk_core;
    wire rst_n_core;
    wire debug_en_core;
    wire[1:0] chip_sel_core;

    wire succ_core;

    wire[`BRIDGE_WIDTH-1:0] bridge_tx_data_core;
    wire[`BRIDGE_WIDTH-1:0] bridge_rx_data_core;

    wire uart_tx_core;
    wire uart_rx_core;

    wire[3:0] pwm_core;

    wire[1:0] i2c_io_ctrl_core;
    wire i2c_scl_core;
    wire i2c_sda_core;

    // Input Ports
    PDDW0204CDG mclk        (.OEN(1'b1), .I(1'b0), .PAD(clk),                 .C(clk_core),                 .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mrst        (.OEN(1'b1), .I(1'b0), .PAD(rst_n_i),             .C(rst_n_core),               .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG muart_d     (.OEN(1'b1), .I(1'b0), .PAD(debug_en_i),          .C(debug_en_core),            .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG msel0       (.OEN(1'b1), .I(1'b0), .PAD(chip_sel_i[0]),       .C(chip_sel_core[0]),         .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG msel1       (.OEN(1'b1), .I(1'b0), .PAD(chip_sel_i[1]),       .C(chip_sel_core[1]),         .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG muart_rx    (.OEN(1'b1), .I(1'b0), .PAD(uart_rx_i),           .C(uart_rx_core),             .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in0 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[0]), .C(bridge_rx_data_core[0]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in1 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[1]), .C(bridge_rx_data_core[1]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in2 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[2]), .C(bridge_rx_data_core[2]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in3 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[3]), .C(bridge_rx_data_core[3]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in4 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[4]), .C(bridge_rx_data_core[4]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in5 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[5]), .C(bridge_rx_data_core[5]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in6 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[6]), .C(bridge_rx_data_core[6]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mfpga_mem_in7 (.OEN(1'b1), .I(1'b0), .PAD(bridge_rx_data_i[7]), .C(bridge_rx_data_core[7]), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // Output Ports
    PDDW0204CDG msucc       (.OEN(1'b0), .I(succ_core),                      .PAD(succ),                    .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG muart_tx    (.OEN(1'b0), .I(uart_tx_core),                   .PAD(uart_tx_o),               .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out0 (.OEN(1'b0), .I(bridge_tx_data_core[0]), .PAD(bridge_tx_data_o[0]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out1 (.OEN(1'b0), .I(bridge_tx_data_core[1]), .PAD(bridge_tx_data_o[1]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out2 (.OEN(1'b0), .I(bridge_tx_data_core[2]), .PAD(bridge_tx_data_o[2]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out3 (.OEN(1'b0), .I(bridge_tx_data_core[3]), .PAD(bridge_tx_data_o[3]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out4 (.OEN(1'b0), .I(bridge_tx_data_core[4]), .PAD(bridge_tx_data_o[4]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out5 (.OEN(1'b0), .I(bridge_tx_data_core[5]), .PAD(bridge_tx_data_o[5]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out6 (.OEN(1'b0), .I(bridge_tx_data_core[6]), .PAD(bridge_tx_data_o[6]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mfpga_mem_out7 (.OEN(1'b0), .I(bridge_tx_data_core[7]), .PAD(bridge_tx_data_o[7]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mpwm0       (.OEN(1'b0), .I(pwm_core[0]),                    .PAD(pwm_o[0]),                .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mpwm1       (.OEN(1'b0), .I(pwm_core[1]),                    .PAD(pwm_o[1]),                .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mpwm2       (.OEN(1'b0), .I(pwm_core[2]),                    .PAD(pwm_o[2]),                .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mpwm3       (.OEN(1'b0), .I(pwm_core[3]),                    .PAD(pwm_o[3]),                .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));

    // I2C Open-drain Ports: OEN=1 releases the line, OEN=0 drives low.
    PDDW0204CDG mscl        (.OEN(i2c_io_ctrl_core[1]), .I(1'b0), .PAD(i2c_scl), .C(i2c_scl_core), .DS(1'b1), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG msda        (.OEN(i2c_io_ctrl_core[0]), .I(1'b0), .PAD(i2c_sda), .C(i2c_sda_core), .DS(1'b1), .PE(1'b0), .IE(1'b1));

    g03_soc u_g03_soc (
        .clk(clk_core),
        .rst_n_i(rst_n_core),
        .debug_en_i(debug_en_core),
        .chip_sel_i(chip_sel_core),
        .succ(succ_core),
        .bridge_tx_data_o(bridge_tx_data_core),
        .bridge_rx_data_i(bridge_rx_data_core),
        .uart_tx_o(uart_tx_core),
        .uart_rx_i(uart_rx_core),
        .pwm_o(pwm_core),
        .i2c_io_ctrl_o(i2c_io_ctrl_core),
        .i2c_scl_i(i2c_scl_core),
        .i2c_sda_i(i2c_sda_core)
    );

endmodule
