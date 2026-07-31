// ============================================================
// TinyRISCV 系统参数与常量宏定义
// 包含：片外存储深度/位宽、串行协议参数、UART/IIC时钟分频、
//       LM75温度传感器常量
// ============================================================

`define EXCTRL_WIDTH 8
`define EXDATA_WIDTH 8

`ifdef sim
`define ROM_DEPTH 4096                  
`define RAM_DEPTH 4096
`define EX_AWIDTH 16
`define PWIDTH_O 16
`define PWIDTH_I 8

// UART counter runs from 0 through UART_BAUD_115200, so 5 means 6 clocks/bit.
`define UART_SIM_BIT_CYCLES 6
`define UART_BAUD_115200 (`UART_SIM_BIT_CYCLES - 1)
`define IIC_CLK_DIV 16'd10
`else
`define ROM_DEPTH 256                  
`define RAM_DEPTH 16  
`define EX_AWIDTH 8
`define PWIDTH_O 8
`define PWIDTH_I 8

`define UART_BAUD_115200 (`CPU_CLOCK_HZ / 115200)
`define IIC_CLK_DIV 16'd250
`endif

`define IIC_MAX_FREQ 32'd100000

`define LM75_I2C_ADDR 7'h48
`define LM75_TEMP_REG_PTR 8'h00
`define LM75_TEMP_MSB 8'h14
`define LM75_TEMP_LSB 8'h80

`define ROM_AWIDTH $clog2(`ROM_DEPTH)
`define RAM_AWIDTH $clog2(`RAM_DEPTH)
