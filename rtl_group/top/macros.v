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

// Core XYH constants
`ifdef sim
`define IIC_CLK_DIV             16'd10
`else
`define IIC_CLK_DIV             16'd250
`endif
`define IIC_MAX_FREQ            32'd100000
`define LM75_I2C_ADDR           7'h48
`define LM75_TEMP_REG_PTR       8'h00
`define LM75_TEMP_MSB           8'h14
`define LM75_TEMP_LSB           8'h80

// Core XZR constants
`define CpuResetAddr `CPU_RESET_ADDR
`define RstEnable 1'b0
`define RstDisable 1'b1
`define ZeroWord 32'h0
`define ZeroReg 5'h0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define DivResultNotReady 1'b0
`define DivResultReady 1'b1
`define DivStart 1'b1
`define DivStop 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0
`define Stop 1'b1
`define NoStop 1'b0
`define RIB_ACK 1'b1
`define RIB_NACK 1'b0
`define RIB_REQ 1'b1
`define RIB_NREQ 1'b0
`define INT_ASSERT 1'b1
`define INT_DEASSERT 1'b0
`define INT_BUS 7:0
`define INT_NONE 8'h0
`define INT_RET 8'hff
`define INT_TIMER0 8'b00000001
`define INT_TIMER0_ENTRY_ADDR 32'h4
`define Hold_Flag_Bus 2:0
`define Hold_None 3'b000
`define Hold_Pc 3'b001
`define Hold_If 3'b010
`define Hold_Id 3'b011
`define INST_TYPE_I 7'b0010011
`define INST_ADDI 3'b000
`define INST_SLTI 3'b010
`define INST_SLTIU 3'b011
`define INST_XORI 3'b100
`define INST_ORI 3'b110
`define INST_ANDI 3'b111
`define INST_SLLI 3'b001
`define INST_SRI 3'b101
`define INST_TYPE_L 7'b0000011
`define INST_LB 3'b000
`define INST_LH 3'b001
`define INST_LW 3'b010
`define INST_LBU 3'b100
`define INST_LHU 3'b101
`define INST_TYPE_S 7'b0100011
`define INST_SB 3'b000
`define INST_SH 3'b001
`define INST_SW 3'b010
`define INST_TYPE_R_M 7'b0110011
`define INST_ADD_SUB 3'b000
`define INST_SLL 3'b001
`define INST_SLT 3'b010
`define INST_SLTU 3'b011
`define INST_XOR 3'b100
`define INST_SR 3'b101
`define INST_OR 3'b110
`define INST_AND 3'b111
`define INST_MUL 3'b000
`define INST_MULH 3'b001
`define INST_MULHSU 3'b010
`define INST_MULHU 3'b011
`define INST_DIV 3'b100
`define INST_DIVU 3'b101
`define INST_REM 3'b110
`define INST_REMU 3'b111
`define INST_JAL 7'b1101111
`define INST_JALR 7'b1100111
`define INST_LUI 7'b0110111
`define INST_AUIPC 7'b0010111
`define XZR_INST_NOP_OP 7'b0000001
`define XZR_INST_FENCE 7'b0001111
`define INST_MRET 32'h30200073
`define INST_RET 32'h00008067
`define INST_ECALL 32'h73
`define INST_EBREAK 32'h00100073
`define INST_TYPE_B 7'b1100011
`define INST_BEQ 3'b000
`define INST_BNE 3'b001
`define INST_BLT 3'b100
`define INST_BGE 3'b101
`define INST_BLTU 3'b110
`define INST_BGEU 3'b111
`define INST_TYPE_D 7'b0101111
`define INST_ID 3'b000
`define INST_TEM 3'b001
`define INST_INTF 3'b010
`define INST_CSR 7'b1110011
`define INST_CSRRW 3'b001
`define INST_CSRRS 3'b010
`define INST_CSRRC 3'b011
`define INST_CSRRWI 3'b101
`define INST_CSRRSI 3'b110
`define INST_CSRRCI 3'b111
`define CSR_CYCLE 12'hc00
`define CSR_CYCLEH 12'hc80
`define CSR_MTVEC 12'h305
`define CSR_MCAUSE 12'h342
`define CSR_MEPC 12'h341
`define CSR_MIE 12'h304
`define CSR_MSTATUS 12'h300
`define CSR_MSCRATCH 12'h340
`define RomNum `ROM_DEPTH
`define MemNum `RAM_DEPTH
`define MemBus 31:0
`define MemAddrBus 31:0
`define InstBus 31:0
`define InstAddrBus 31:0
`define RegAddrBus 4:0
`define RegBus 31:0
`define DoubleRegBus 63:0
`define RegWidth 32
`define RegNum 32
`define RegNumLog2 5

// HJX/XYH pipeline decode metadata (formerly defines_hjx.v/defines_xyh.v)
`define HJX_STALL_WIDTH 4
`define HJX_STALL_PC 2'd0
`define HJX_STALL_IF 2'd1
`define HJX_STALL_ID 2'd2
`define HJX_STALL_EX 2'd3
`define HJX_DECINFO_GRP_BUS 2:0
`define HJX_DECINFO_GRP_WIDTH 3
`define HJX_DECINFO_GRP_ALU 3'd1
`define HJX_DECINFO_GRP_BJP 3'd2
`define HJX_DECINFO_GRP_MEM 3'd5
`define HJX_DECINFO_GRP_SYS 3'd6
`define HJX_DECINFO_GRP_EXT 3'd7
`define HJX_DECINFO_ALU_BUS_WIDTH 17
`define HJX_DECINFO_BJP_BUS_WIDTH 11
`define HJX_DECINFO_MEM_BUS_WIDTH 11
`define HJX_DECINFO_SYS_BUS_WIDTH 5
`define HJX_DECINFO_EXT_BUS_WIDTH 6
`define HJX_DECINFO_WIDTH 17
`define HJX_DECINFO_ALU_LUI 3
`define HJX_DECINFO_ALU_AUIPC 4
`define HJX_DECINFO_ALU_ADD 5
`define HJX_DECINFO_ALU_SUB 6
`define HJX_DECINFO_ALU_SLL 7
`define HJX_DECINFO_ALU_SLT 8
`define HJX_DECINFO_ALU_SLTU 9
`define HJX_DECINFO_ALU_XOR 10
`define HJX_DECINFO_ALU_SRL 11
`define HJX_DECINFO_ALU_SRA 12
`define HJX_DECINFO_ALU_OR 13
`define HJX_DECINFO_ALU_AND 14
`define HJX_DECINFO_ALU_OP2IMM 15
`define HJX_DECINFO_ALU_OP1PC 16
`define HJX_DECINFO_BJP_JUMP 3
`define HJX_DECINFO_BJP_BEQ 4
`define HJX_DECINFO_BJP_BNE 5
`define HJX_DECINFO_BJP_BLT 6
`define HJX_DECINFO_BJP_BGE 7
`define HJX_DECINFO_BJP_BLTU 8
`define HJX_DECINFO_BJP_BGEU 9
`define HJX_DECINFO_BJP_OP1RS1 10
`define HJX_DECINFO_MEM_LB 3
`define HJX_DECINFO_MEM_LH 4
`define HJX_DECINFO_MEM_LW 5
`define HJX_DECINFO_MEM_LBU 6
`define HJX_DECINFO_MEM_LHU 7
`define HJX_DECINFO_MEM_SB 8
`define HJX_DECINFO_MEM_SH 9
`define HJX_DECINFO_MEM_SW 10
`define HJX_DECINFO_SYS_NOP 3
`define HJX_DECINFO_SYS_FENCE 4
`define HJX_DECINFO_EXT_SID 3
`define HJX_DECINFO_EXT_RT 4
`define HJX_DECINFO_EXT_IF 5

// XYH uses the same layout, with additional CSR and extension selectors.
`define XYH_STALL_WIDTH `HJX_STALL_WIDTH
`define XYH_STALL_PC `HJX_STALL_PC
`define XYH_STALL_IF `HJX_STALL_IF
`define XYH_STALL_ID `HJX_STALL_ID
`define XYH_STALL_EX `HJX_STALL_EX
`define XYH_DECINFO_GRP_BUS `HJX_DECINFO_GRP_BUS
`define XYH_DECINFO_GRP_WIDTH `HJX_DECINFO_GRP_WIDTH
`define XYH_DECINFO_GRP_ALU `HJX_DECINFO_GRP_ALU
`define XYH_DECINFO_GRP_BJP `HJX_DECINFO_GRP_BJP
`define XYH_DECINFO_GRP_MEM `HJX_DECINFO_GRP_MEM
`define XYH_DECINFO_GRP_SYS `HJX_DECINFO_GRP_SYS
`define XYH_DECINFO_GRP_EXT `HJX_DECINFO_GRP_EXT
`define XYH_DECINFO_ALU_BUS_WIDTH `HJX_DECINFO_ALU_BUS_WIDTH
`define XYH_DECINFO_BJP_BUS_WIDTH `HJX_DECINFO_BJP_BUS_WIDTH
`define XYH_DECINFO_MEM_BUS_WIDTH `HJX_DECINFO_MEM_BUS_WIDTH
`define XYH_DECINFO_EXT_BUS_WIDTH `HJX_DECINFO_EXT_BUS_WIDTH
`define XYH_DECINFO_WIDTH `HJX_DECINFO_WIDTH
`define XYH_DECINFO_ALU_LUI `HJX_DECINFO_ALU_LUI
`define XYH_DECINFO_ALU_AUIPC `HJX_DECINFO_ALU_AUIPC
`define XYH_DECINFO_ALU_ADD `HJX_DECINFO_ALU_ADD
`define XYH_DECINFO_ALU_SUB `HJX_DECINFO_ALU_SUB
`define XYH_DECINFO_ALU_SLL `HJX_DECINFO_ALU_SLL
`define XYH_DECINFO_ALU_SLT `HJX_DECINFO_ALU_SLT
`define XYH_DECINFO_ALU_SLTU `HJX_DECINFO_ALU_SLTU
`define XYH_DECINFO_ALU_XOR `HJX_DECINFO_ALU_XOR
`define XYH_DECINFO_ALU_SRL `HJX_DECINFO_ALU_SRL
`define XYH_DECINFO_ALU_SRA `HJX_DECINFO_ALU_SRA
`define XYH_DECINFO_ALU_OR `HJX_DECINFO_ALU_OR
`define XYH_DECINFO_ALU_AND `HJX_DECINFO_ALU_AND
`define XYH_DECINFO_ALU_OP2IMM `HJX_DECINFO_ALU_OP2IMM
`define XYH_DECINFO_ALU_OP1PC `HJX_DECINFO_ALU_OP1PC
`define XYH_DECINFO_BJP_JUMP `HJX_DECINFO_BJP_JUMP
`define XYH_DECINFO_BJP_BEQ `HJX_DECINFO_BJP_BEQ
`define XYH_DECINFO_BJP_BNE `HJX_DECINFO_BJP_BNE
`define XYH_DECINFO_BJP_BLT `HJX_DECINFO_BJP_BLT
`define XYH_DECINFO_BJP_BGE `HJX_DECINFO_BJP_BGE
`define XYH_DECINFO_BJP_BLTU `HJX_DECINFO_BJP_BLTU
`define XYH_DECINFO_BJP_BGEU `HJX_DECINFO_BJP_BGEU
`define XYH_DECINFO_BJP_OP1RS1 `HJX_DECINFO_BJP_OP1RS1
`define XYH_DECINFO_MEM_LB `HJX_DECINFO_MEM_LB
`define XYH_DECINFO_MEM_LH `HJX_DECINFO_MEM_LH
`define XYH_DECINFO_MEM_LW `HJX_DECINFO_MEM_LW
`define XYH_DECINFO_MEM_LBU `HJX_DECINFO_MEM_LBU
`define XYH_DECINFO_MEM_LHU `HJX_DECINFO_MEM_LHU
`define XYH_DECINFO_MEM_SB `HJX_DECINFO_MEM_SB
`define XYH_DECINFO_MEM_SH `HJX_DECINFO_MEM_SH
`define XYH_DECINFO_MEM_SW `HJX_DECINFO_MEM_SW
`define XYH_DECINFO_EXT_SENDID 3
`define XYH_DECINFO_EXT_READTEMP 4
`define XYH_DECINFO_EXT_INTFIRE 5
`define XYH_DECINFO_CSR_BUS_WIDTH 8
`define XYH_DECINFO_CSR_RS1IMM 3
`define XYH_DECINFO_CSR_CSRADDR 4
`define XYH_DECINFO_CSR_CSRRW 5
`define XYH_DECINFO_CSR_CSRRS 6
`define XYH_DECINFO_CSR_CSRRC 7
`define XYH_DECINFO_GRP_CSR 3'd3
`define XYH_DECINFO_SYS_BUS_WIDTH 5
`define XYH_DECINFO_SYS_NOP 3
`define XYH_DECINFO_SYS_FENCE 4
`define XYH_DECINFO_SYS_ECALL 3
`define XYH_DECINFO_SYS_EBREAK 4
`define XYH_DECINFO_SYS_MRET 3

`endif
