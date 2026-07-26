// Shared project constants and peripheral interface widths.
`ifndef HJX_MACROS_V
`define HJX_MACROS_V

`ifndef CPU_CLOCK_HZ
`define CPU_CLOCK_HZ            50000000
`endif
`define I2C_BAUD_100K           (`CPU_CLOCK_HZ / 100000)
`define UART_BAUD_115200        32'h1B2
`define UART_CTRL_REG           32'h30000000
`define UART_STATUS_REG         32'h30000004
`define UART_BAUD_REG           32'h30000008
`define UART_TX_REG             32'h3000000c
`define UART_RX_REG             32'h30000010

`define UART_TX_BUSY_FLAG       32'h1
`define UART_RX_OVER_FLAG       32'h2
`define UART_PACKET_LEN         8'd35
`define UART_RESP_ACK           32'h6
`define UART_RESP_NAK           32'h15
`define ROM_START_ADDR          32'h0

`define ROM_DEPTH               256
`define RAM_DEPTH               16
`define ROM_AWIDTH              8
`define RAM_AWIDTH              4
`define EX_AWIDTH               8

`define PWIDTH_O                8
`define PWIDTH_I                8

`define EXCTRL_WIDTH            8
`define EXDATA_WIDTH            8

`endif
