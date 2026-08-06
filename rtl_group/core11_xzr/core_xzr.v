`include "../top/macros.v"

// tinyriscv处理器核顶层模块
module core_xzr(
    input wire clk,
    input wire rst_n,
    input wire debug_halt_i,

    output wire gpr_we_o,
    output wire[`RegAddrBus] gpr_waddr_o,
    output wire[`RegBus] gpr_wdata_o,
    output wire[`RegAddrBus] gpr_raddr1_o,
    input wire[`RegBus] gpr_rdata1_i,
    output wire[`RegAddrBus] gpr_raddr2_o,
    input wire[`RegBus] gpr_rdata2_i,

    output wire[31:0] if_addr_o,
    output wire[31:0] if_data_o,
    output wire[3:0] if_sel_o,
    output wire if_req_vld_o,
    input wire if_req_rdy_i,
    output wire if_rsp_rdy_o,
    input wire if_rsp_vld_i,
    input wire[31:0] if_data_i,
    output wire if_we_o,

    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_data_o,
    output wire[3:0] mem_sel_o,
    output wire mem_req_vld_o,
    input wire mem_req_rdy_i,
    output wire mem_rsp_rdy_o,
    input wire mem_rsp_vld_i,
    input wire[31:0] mem_data_i,
    output wire mem_we_o
);

    wire rst = rst_n;

    // pc_reg模块输出信号
    wire[`InstAddrBus] pc_pc_o;

    // if_id模块输出信号
    wire[`InstBus] if_inst_o;
    wire[`InstAddrBus] if_inst_addr_o;

    // id模块输出信号
    wire[`RegAddrBus] id_reg1_raddr_o;
    wire[`RegAddrBus] id_reg2_raddr_o;
    wire[`InstBus] id_inst_o;
    wire[`InstAddrBus] id_inst_addr_o;
    wire[`RegBus] id_reg1_rdata_o;
    wire[`RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`RegAddrBus] id_reg_waddr_o;
    
    wire[`MemAddrBus] id_op1_o;
    wire[`MemAddrBus] id_op2_o;
    wire[`MemAddrBus] id_op1_jump_o;
    wire[`MemAddrBus] id_op2_jump_o;

    // id_ex模块输出信号
    wire[`InstBus] ie_inst_o;
    wire[`InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`RegAddrBus] ie_reg_waddr_o;
    wire[`RegBus] ie_reg1_rdata_o;
    wire[`RegBus] ie_reg2_rdata_o;
    
    wire[`MemAddrBus] ie_op1_o;
    wire[`MemAddrBus] ie_op2_o;
    wire[`MemAddrBus] ie_op1_jump_o;
    wire[`MemAddrBus] ie_op2_jump_o;

    // ex模块输出信号
    wire[`MemBus] ex_mem_wdata_o;
    wire[`MemAddrBus] ex_mem_raddr_o;
    wire[`MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire ex_mem_ack_i;
    wire[`RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`InstAddrBus] ex_jump_addr_o;

    // regs模块输出信号

    // ctrl模块输出信号
    wire[`Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`InstAddrBus] ctrl_jump_addr_o;


    // A load's combinational result is not valid until the response beat.
    wire ex_gpr_we_valid = ex_reg_we_o & (~ex_mem_req_o | ex_mem_ack_i);
    assign gpr_we_o = ex_gpr_we_valid;
    assign gpr_waddr_o = ex_reg_waddr_o;
    assign gpr_wdata_o = ex_reg_wdata_o;
    assign gpr_raddr1_o = id_reg1_raddr_o;
    assign gpr_raddr2_o = id_reg2_raddr_o;

    // The shared GPR is written on the clock edge.  While an instruction is
    // in EX, the following instruction in ID still sees the old array value,
    // so bypass the current EX result directly to both ID read ports.
    wire [31:0] id_gpr_rdata1 =
        (ex_gpr_we_valid && (ex_reg_waddr_o != `ZeroReg) &&
         (ex_reg_waddr_o == id_reg1_raddr_o)) ? ex_reg_wdata_o : gpr_rdata1_i;
    wire [31:0] id_gpr_rdata2 =
        (ex_gpr_we_valid && (ex_reg_waddr_o != `ZeroReg) &&
         (ex_reg_waddr_o == id_reg2_raddr_o)) ? ex_reg_wdata_o : gpr_rdata2_i;

    localparam IF_REQ = 2'd0;
    localparam IF_RSP = 2'd1;
    localparam IF_DELIVER = 2'd2;
    reg [1:0] if_state;
    reg [31:0] if_inst_r;
    reg [31:0] if_addr_r;

    assign if_addr_o = pc_pc_o;
    assign if_data_o = 32'b0;
    assign if_sel_o = 4'b1111;
    assign if_we_o = 1'b0;
    assign if_req_vld_o = (if_state == IF_REQ) & ~debug_halt_i;
    assign if_rsp_rdy_o = (if_state == IF_RSP);
    wire if_bus_hold = (if_state != IF_DELIVER) | debug_halt_i;

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            if_state <= IF_REQ;
            if_inst_r <= `INST_NOP;
            if_addr_r <= `CpuResetAddr;
        end else begin
            case (if_state)
                IF_REQ: begin
                    if (if_req_vld_o & if_req_rdy_i) begin
                        if_addr_r <= pc_pc_o;
                        if_state <= IF_RSP;
                    end
                end
                IF_RSP: begin
                    if (if_rsp_vld_i & if_rsp_rdy_o) begin
                        if_inst_r <= if_data_i;
                        if_state <= IF_DELIVER;
                    end
                end
                IF_DELIVER: if_state <= IF_REQ;
                default: if_state <= IF_REQ;
            endcase
        end
    end

    localparam MEM_IDLE = 1'b0;
    localparam MEM_RSP = 1'b1;
    reg mem_state;
    reg [31:0] mem_addr_r;
    reg [31:0] mem_data_r;
    reg mem_we_r;

    assign mem_addr_o = (mem_state == MEM_IDLE) ?
                        ((ex_mem_we_o == `WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o) :
                        mem_addr_r;
    assign mem_data_o = (mem_state == MEM_IDLE) ? ex_mem_wdata_o : mem_data_r;
    assign mem_we_o = (mem_state == MEM_IDLE) ? ex_mem_we_o : mem_we_r;
    assign mem_sel_o = 4'b1111;
    // Do not launch the data-side request while an instruction response is
    // outstanding.  The shared RIB has a single response route; overlapping
    // the UART/data access with a ROM fetch can strand the bridge in ST_RSP.
    assign mem_req_vld_o = (mem_state == MEM_IDLE) & ex_mem_req_o &
                           (if_state != IF_RSP);
    assign mem_rsp_rdy_o = (mem_state == MEM_RSP);
    assign ex_mem_ack_i = mem_rsp_vld_i & mem_rsp_rdy_o;

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            mem_state <= MEM_IDLE;
            mem_addr_r <= 32'b0;
            mem_data_r <= 32'b0;
            mem_we_r <= 1'b0;
        end else begin
            if ((mem_state == MEM_IDLE) & mem_req_vld_o & mem_req_rdy_i) begin
                mem_state <= MEM_RSP;
                mem_addr_r <= mem_addr_o;
                mem_data_r <= mem_data_o;
                mem_we_r <= mem_we_o;
            end else if ((mem_state == MEM_RSP) & mem_rsp_vld_i & mem_rsp_rdy_o) begin
                mem_state <= MEM_IDLE;
            end
        end
    end

    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire id_stall_req_o;
    wire ie_mem_read_o;
    wire id_mem_read_o;

    forwarding_unit_xzr u_forwarding_unit(
    .ex_waddr_i      (ex_reg_waddr_o),
    .ex_we_i         (ex_reg_we_o),
    .id_rs1_addr_i   (id_reg1_raddr_o),
    .id_rs2_addr_i   (id_reg2_raddr_o),
    .forward_a_o     (forward_a),
    .forward_b_o     (forward_b)
    );

    wire hold_flag_if_o;
    wire reset_if_cnt_i;
    // pc_reg模块例化
    pc_reg_xzr u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o),
        .hold_flag_if_o(hold_flag_if_o),
        .if_busy_i(if_bus_hold),
        .reset_if_cnt_i(reset_if_cnt_i)
    );
    wire flush;
    // ctrl模块例化
    ctrl_xzr u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_rib_i(if_bus_hold),
        .hold_flag_o(ctrl_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o),
        .hold_flag_if_i(hold_flag_if_o),
        .reset_if_cnt_o(reset_if_cnt_i),
        .flush_o(flush)
    );

    // regs模块例化
    
    // if_id模块例化
    if_id_xzr u_if_id(
        .clk(clk),
        .rst(rst),
        // Only inject the fetched instruction for one cycle.  Replaying
        // if_inst_r throughout the multi-cycle bridge wait would execute the
        // same instruction repeatedly while PC is held.
        .inst_i((if_state == IF_DELIVER) ? if_inst_r : `INST_NOP),
        .inst_addr_i(if_addr_r),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o),
        .flush_i(flush)
    );

    // id模块例化
    id_xzr u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(id_gpr_rdata1),
        .reg2_rdata_i(id_gpr_rdata2),
        .ex_jump_flag_i(ex_jump_flag_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o)
    );

    // id_ex模块例化
    id_ex_xzr u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o),
        .flush_i(flush)
    );

    // ex模块例化
    ex_xzr u_ex(
        .rst(rst),
        .clk(clk),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .mem_rdata_i(mem_data_i),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .mem_ack_i(ex_mem_ack_i),
        .forward_a_i     (forward_a),
        .forward_b_i     (forward_b)
    );
endmodule
