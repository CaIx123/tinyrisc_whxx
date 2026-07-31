`timescale 1ns / 1ps

`include "../../top/macros.v"

module ifu_ifetch(
    input wire clk,
    input wire rst_n,

    // from ifu_pc
    input wire [`PC_WIDTH-1:0] pc_i,
    input wire if_id_ready_i,

    // to if_id
    output reg [`INST_WIDTH-1:0] inst_o,
    output reg [`PC_WIDTH-1:0] inst_pc_o,
    output reg inst_valid_o,
    output wire inst_fire_o,

    output wire [31:0] ibus_addr_o,
    input wire [31:0] ibus_data_i,
    output wire [31:0] ibus_data_o,
    output wire [3:0] ibus_sel_o,
    output wire ibus_we_o,
    output wire ibus_req_valid_o,
    input wire ibus_req_ready_i,
    input wire ibus_rsp_valid_i,
    output wire ibus_rsp_ready_o
    );

    localparam [1:0] LOOKUP = 2'd0;
    localparam [1:0] REQ    = 2'd1;
    localparam [1:0] FILL   = 2'd2;

    reg [1:0] state;
    reg [1:0] state_next;

    reg icache_valid [0:`ICACHE_DEPTH-1];
    reg icache_valid_next [0:`ICACHE_DEPTH-1];
    reg [`PC_WIDTH-3:0] icache_base_word;
    reg [`PC_WIDTH-3:0] icache_base_word_next;
    reg [`PC_WIDTH-3:0] request_base_word;
    reg [`PC_WIDTH-3:0] request_base_word_next;
    reg [`ICACHE_ADDR_WIDTH-1:0] icache_wr_addr;
    reg [`ICACHE_ADDR_WIDTH-1:0] icache_wr_addr_next;

    reg [`INST_WIDTH-1:0] icache_data [0:`ICACHE_DEPTH-1];
    reg [`INST_WIDTH-1:0] icache_data_next [0:`ICACHE_DEPTH-1];
    integer i;

    wire [`PC_WIDTH-3:0] pc_word = pc_i[`PC_WIDTH-1:2];
    wire [`PC_WIDTH-3:0] icache_delta = pc_word - icache_base_word;
    wire [`ICACHE_ADDR_WIDTH-1:0] icache_rd_addr = icache_delta[`ICACHE_ADDR_WIDTH-1:0];
    wire icache_hit = (icache_delta < `ICACHE_DEPTH) & icache_valid[icache_rd_addr];
    wire rsp_hasked = ibus_rsp_valid_i & ibus_rsp_ready_o;
    wire fill_done = rsp_hasked & (icache_wr_addr == (`ICACHE_DEPTH-1));

    assign inst_fire_o = inst_valid_o & if_id_ready_i;

    assign ibus_addr_o = {{(32-`PC_WIDTH){1'b0}}, request_base_word, 2'b00};
    assign ibus_data_o = 32'b0;
    assign ibus_sel_o = 4'b1111;
    assign ibus_we_o = 1'b0;
    assign ibus_req_valid_o = (state == REQ) | (state == FILL);
    assign ibus_rsp_ready_o = (state == FILL);

    // 状态转移表
    always @(*) begin
        state_next = state;

        case (state)
            LOOKUP: begin
                if (!icache_hit) begin
                    state_next = REQ;
                end
            end
            REQ: begin
                if (ibus_req_ready_i) begin
                    state_next = FILL;
                end
            end
            FILL: begin
                if (fill_done) begin
                    state_next = LOOKUP;
                end
            end
            default: begin
                state_next = LOOKUP;
            end
        endcase
    end

    // 数据寄存器下一拍逻辑
    always @(*) begin
        icache_base_word_next = icache_base_word;
        request_base_word_next = request_base_word;
        icache_wr_addr_next = icache_wr_addr;

        for (i = 0; i < `ICACHE_DEPTH; i = i + 1) begin
            icache_valid_next[i] = icache_valid[i];
            icache_data_next[i] = icache_data[i];
        end

        if (state == LOOKUP && !icache_hit) begin
            request_base_word_next = pc_word;
            icache_base_word_next = pc_word;
            icache_wr_addr_next = {`ICACHE_ADDR_WIDTH{1'b0}};
            for (i = 0; i < `ICACHE_DEPTH; i = i + 1) begin
                icache_valid_next[i] = 1'b0;
            end
        end

        if (state == FILL && rsp_hasked) begin
            icache_data_next[icache_wr_addr] = ibus_data_i;
            icache_valid_next[icache_wr_addr] = 1'b1;

            if (icache_wr_addr == (`ICACHE_DEPTH-1)) begin
                icache_wr_addr_next = {`ICACHE_ADDR_WIDTH{1'b0}};
            end else begin
                icache_wr_addr_next = icache_wr_addr + 1'b1;
            end
        end
    end

    // 命中后读取逻辑
    always @(*) begin
        inst_o = `INST_NOP;
        inst_pc_o = pc_i;
        inst_valid_o = 1'b0;

        if (((state == LOOKUP) || ((state == FILL) && if_id_ready_i)) && icache_hit) begin
            inst_valid_o = 1'b1;
            inst_o = icache_data[icache_rd_addr];
        end
    end

    // 状态寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= LOOKUP;
        end else begin
            state <= state_next;
        end
    end

    // 数据寄存器更新逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icache_base_word <= {(`PC_WIDTH-2){1'b0}};
            request_base_word <= {(`PC_WIDTH-2){1'b0}};
            icache_wr_addr <= {`ICACHE_ADDR_WIDTH{1'b0}};
            for (i = 0; i < `ICACHE_DEPTH; i = i + 1) begin
                icache_valid[i] <= 1'b0;
                icache_data[i] <= `INST_NOP;
            end
        end else begin
            icache_base_word <= icache_base_word_next;
            request_base_word <= request_base_word_next;
            icache_wr_addr <= icache_wr_addr_next;
            for (i = 0; i < `ICACHE_DEPTH; i = i + 1) begin
                icache_valid[i] <= icache_valid_next[i];
                icache_data[i] <= icache_data_next[i];
            end
        end
    end

endmodule
