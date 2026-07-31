`ifndef G03_MACROS_V
`define G03_MACROS_V

`define CPU_RESET            1'b0            // CPU复位信号有效电平
`define CPU_RESET_ADDR       32'h0           // CPU复位地址
`define CPU_CLOCK_HZ         50000000        // CPU时钟(50MHZ)
`define INST_MEM_START_ADDR  32'h0           // 指令存储器起始地址
`define INST_MEM_END_ADDR    32'h0fffffff    // 指令存储器结束地址
`define KALSIT_ENABLE_ILA    1

// 基本标识
`define TRUE            1'b1
`define FALSE           1'b0
`define ROM_READ_BURST  `TRUE

// 数据宽度
`define PC_WIDTH          32
`define INST_WIDTH        32
`define DATA_WIDTH        32
`define BRIDGE_WIDTH      8
`define GPR_ADDR_WIDTH    5
`define ALU_CTRL_WIDTH    6
`define MEM_CTRL_WIDTH    3
`define CUSTOM_CTRL_WIDTH 2
`define RAM_ADDR_WIDTH    4                       // 数据存储器地址宽度，单位为bit
`define ROM_ADDR_WIDTH    8                       // 指令存储器地址宽度，单位为bit
`define ICACHE_ADDR_WIDTH 2                       // 指令缓存地址宽度，单位为bit

// Shared external-memory bridge protocol widths.
`define EXCTRL_WIDTH      8
`define EXDATA_WIDTH      8
`define EX_AWIDTH         8
`define PWIDTH_O          8
`define PWIDTH_I          8
`define ROM_AWIDTH        `ROM_ADDR_WIDTH
`define RAM_AWIDTH        `RAM_ADDR_WIDTH

// 存储单元深度
`define ROM_DEPTH         256                     // 指令存储器深度，单位为word(4字节)
`define RAM_DEPTH         16                      // 数据存储器深度，单位为word(4字节)
`define GPR_DEPTH         32                      // 寄存器深度，单位为word(4字节)
`define ICACHE_DEPTH      4                       // 指令缓存深度，单位为word(4字节)

// NOP指令
`define INST_NOP        32'h00000013

// -----------------指令译码信息-----------------//
// 指令类型
`define OPCODE_TYPE_R           7'b0110011
`define OPCODE_TYPE_I_JALR      7'b1100111
`define OPCODE_TYPE_I_LOAD      7'b0000011
`define OPCODE_TYPE_I_COMP      7'b0010011
`define OPCODE_TYPE_I_CUSTOM    7'b0101111

`define OPCODE_TYPE_S           7'b0100011
`define OPCODE_TYPE_B           7'b1100011
`define OPCODE_TYPE_J           7'b1101111
`define OPCODE_TYPE_U_LUI       7'b0110111
`define OPCODE_TYPE_U_AUIPC     7'b0010111
`define OPCODE_TYPE_NOP         7'b0010011    

// R型指令功能码
`define FUNC3_ADD       3'b000
`define FUNC3_SUB       3'b000
`define FUNC3_SLL       3'b001
`define FUNC3_SLT       3'b010
`define FUNC3_SLTU      3'b011
`define FUNC3_XOR       3'b100
`define FUNC3_SRL       3'b101
`define FUNC3_SRA       3'b101
`define FUNC3_OR        3'b110
`define FUNC3_AND       3'b111
`define FUNC7_ADD       7'b0000000
`define FUNC7_SUB       7'b0100000
`define FUNC7_SLL       7'b0000000
`define FUNC7_SLT       7'b0000000
`define FUNC7_SLTU      7'b0000000
`define FUNC7_XOR       7'b0000000
`define FUNC7_SRL       7'b0000000
`define FUNC7_SRA       7'b0100000
`define FUNC7_OR        7'b0000000
`define FUNC7_AND       7'b0000000

// I型指令-访存指令功能码
`define FUNC3_LB        3'b000
`define FUNC3_LH        3'b001
`define FUNC3_LW        3'b010
`define FUNC3_LBU       3'b100
`define FUNC3_LHU       3'b101

// I型指令-立即数运算指令功能码
`define FUNC3_ADDI      3'b000
`define FUNC3_SLTI      3'b010
`define FUNC3_SLTIU     3'b011
`define FUNC3_XORI      3'b100
`define FUNC3_ORI       3'b110
`define FUNC3_ANDI      3'b111
`define FUNC3_SLLI      3'b001
`define FUNC3_SRLI      3'b101
`define FUNC3_SRAI      3'b101
`define FUNC7_SLLI      7'b0000000
`define FUNC7_SRLI      7'b0000000
`define FUNC7_SRAI      7'b0100000

// I型指令-自定义指令功能码
`define FUNC3_SID        3'b000
`define FUNC3_RT         3'b001
`define FUNC3_IF         3'b010

// S型指令功能码
`define FUNC3_SB        3'b000
`define FUNC3_SH        3'b001
`define FUNC3_SW        3'b010

// B型指令功能码
`define FUNC3_BEQ        3'b000
`define FUNC3_BNE        3'b001
`define FUNC3_BLT        3'b100
`define FUNC3_BGE        3'b101
`define FUNC3_BLTU       3'b110
`define FUNC3_BGEU       3'b111

// J型指令功能码
`define FUNC3_JAL        3'b000

// -----------------EXU ALU控制-----------------//
`define ALU_UNIT_ALU     2'b00
`define ALU_UNIT_BYPASS  2'b01

`define ALU_OP_ADD       4'b0000
`define ALU_OP_SUB       4'b0001
`define ALU_OP_AND       4'b0010
`define ALU_OP_OR        4'b0011
`define ALU_OP_XOR       4'b0100
`define ALU_OP_SLL       4'b0101
`define ALU_OP_SRL       4'b0110
`define ALU_OP_SRA       4'b0111
`define ALU_OP_SLT       4'b1000
`define ALU_OP_SLTU      4'b1001

`define ALU_CTRL_ADD     {`ALU_UNIT_ALU, `ALU_OP_ADD}
`define ALU_CTRL_BYPASS  {`ALU_UNIT_BYPASS, `ALU_OP_ADD}

// -----------------MEM 访存控制-----------------//
`define MEM_SIZE_WORD     2'b00
`define MEM_SIZE_HALF     2'b10
`define MEM_SIZE_BYTE     2'b11
`define MEM_CTRL_LB       {1'b0, `MEM_SIZE_BYTE}
`define MEM_CTRL_LH       {1'b0, `MEM_SIZE_HALF}
`define MEM_CTRL_LW       {1'b0, `MEM_SIZE_WORD}
`define MEM_CTRL_LBU      {1'b1, `MEM_SIZE_BYTE}
`define MEM_CTRL_LHU      {1'b1, `MEM_SIZE_HALF}
`define MEM_CTRL_SB       {1'b0, `MEM_SIZE_BYTE}
`define MEM_CTRL_SH       {1'b0, `MEM_SIZE_HALF}
`define MEM_CTRL_SW       {1'b0, `MEM_SIZE_WORD}

// -----------------MEM 单元选择-----------------//
`define CUSTOM_NONE       2'b00
`define CUSTOM_SID        2'b01
`define CUSTOM_RT         2'b10
`define CUSTOM_IF         2'b11

// -----------------UART_DEBUG------------------//
`define UART_BAUD_115200        ((`CPU_CLOCK_HZ / 115200) - 1)

// 串口寄存器地址
`define UART_CTRL_REG           32'h30000000
`define UART_STATUS_REG         32'h30000004
`define UART_BAUD_REG           32'h30000008
`define UART_TX_REG             32'h3000000c
`define UART_RX_REG             32'h30000010

`define UART_TX_BUSY_FLAG       32'h1
`define UART_RX_OVER_FLAG       32'h2

// 包的大小
`define UART_PACKET_LEN         8'd35

`define UART_RESP_ACK           32'h6
`define UART_RESP_NAK           32'h15

// 烧写起始地址
`define ROM_START_ADDR          32'h0

// Shared peripheral address map.  All integrated cores use these ports.
`define PWM_BASE_ADDR           32'h60000000
`define IIC_BASE_ADDR           32'h70000000
`define IIC_CTRL_REG            (`IIC_BASE_ADDR + 32'h00000000)
`define IIC_ADDR_REG            (`IIC_BASE_ADDR + 32'h00010000)
`define IIC_TX_REG              (`IIC_BASE_ADDR + 32'h00020000)
`define IIC_RX_REG              (`IIC_BASE_ADDR + 32'h00030000)
`define IIC_STATUS_REG          (`IIC_BASE_ADDR + 32'h00040000)

// --------------------I2C---------------------//
// clk = 50MHz时对应的I2C分频系数
`define I2C_BAUD_400K           32'h7D
`define I2C_BAUD_100K           32'h1F4

`endif
