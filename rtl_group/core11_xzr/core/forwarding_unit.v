/*
 * forwarding_unit_xzr.v
 * 实际没用上
 */
`include "../../top/macros.v"

module forwarding_unit_xzr(
    // EX写回信息
    input wire [`RegAddrBus] ex_waddr_i,     // EX阶段指令的目标寄存器地址
    input wire               ex_we_i,        // EX阶段指令的写使能信号

    // ID读寄存器信息
    input wire [`RegAddrBus] id_rs1_addr_i,  // ID阶段指令的源寄存�?1地址
    input wire [`RegAddrBus] id_rs2_addr_i,  // ID阶段指令的源寄存�?2地址

    output reg [1:0] forward_a_o,           // 操作数A的前推控�?
    output reg [1:0] forward_b_o             // 操作数B的前推控�?
);

    localparam FORWARD_NONE = 2'b00; // 不前推，使用寄存器堆的�??
    localparam FORWARD_EX   = 2'b01; // 从EX阶段的结果前�?

    always @ (*) begin
        // --- 对操作数A (rs1) 的前推判�? ---
        // 如果EX阶段有写操作，且目标寄存器不是x0�?
        // 并且EX阶段的目标寄存器地址(ex_waddr_i)与ID阶段的源寄存�?1地址(id_rs1_addr_i)相同
        if (ex_we_i && (ex_waddr_i != `ZeroReg) && (ex_waddr_i == id_rs1_addr_i)) begin
            forward_a_o = FORWARD_EX;
        end else begin
            forward_a_o = FORWARD_NONE;
        end

        // --- 对操作数B (rs2) 的前推判�? ---
        // 如果EX阶段有写操作(ex_we_i)，且目标寄存器不是x0�?
        // 并且EX阶段的目标寄存器地址(ex_waddr_i)与ID阶段的源寄存�?2地址(id_rs2_addr_i)相同
        if (ex_we_i && (ex_waddr_i != `ZeroReg) && (ex_waddr_i == id_rs2_addr_i)) begin
            forward_b_o = FORWARD_EX;
        end else begin
            forward_b_o = FORWARD_NONE;
        end
    end

endmodule