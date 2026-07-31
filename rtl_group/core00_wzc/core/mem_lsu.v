`timescale 1ns / 1ps

`include "../../top/macros.v"

module mem_lsu(

    input wire clk,
    input wire rst_n,

    input wire start_i,
    input wire accept_i,
    input wire mem_read_i,
    input wire mem_write_i,
    input wire[`DATA_WIDTH-1:0] addr_i,
    input wire[`DATA_WIDTH-1:0] wdata_i,
    input wire[`MEM_CTRL_WIDTH-1:0] mem_ctrl_i,

    output wire busy_o,
    output wire ready_o,
    output wire[`DATA_WIDTH-1:0] rdata_o,

    // to RIB master
    output wire[`DATA_WIDTH-1:0] rib_addr_o,
    output wire[`DATA_WIDTH-1:0] rib_data_o,
    output wire[3:0] rib_sel_o,
    output wire rib_req_vld_o,
    input wire rib_req_rdy_i,
    output wire rib_rsp_rdy_o,
    input wire rib_rsp_vld_i,
    input wire[`DATA_WIDTH-1:0] rib_data_i,
    output wire rib_we_o

    );

    localparam LSU_IDLE = 2'd0;
    localparam LSU_REQ  = 2'd1;
    localparam LSU_RSP  = 2'd2;
    localparam LSU_DONE = 2'd3;

    reg[1:0] state, state_next;
    reg mem_read_r, mem_read_next;
    reg mem_write_r, mem_write_next;
    reg[`DATA_WIDTH-1:0] addr_r, addr_next;
    reg[`DATA_WIDTH-1:0] wdata_r, wdata_next;
    reg[`MEM_CTRL_WIDTH-1:0] mem_ctrl_r, mem_ctrl_next;
    reg[`DATA_WIDTH-1:0] rdata_r, rdata_next;

    wire req_hasked = rib_req_vld_o & rib_req_rdy_i;
    wire rsp_hasked = rib_rsp_vld_i & rib_rsp_rdy_o;

    reg[3:0] sel;
    reg[`DATA_WIDTH-1:0] store_data;
    reg[`DATA_WIDTH-1:0] load_data;

    always @(*) begin
        sel = 4'b1111;
        store_data = wdata_r;

        case (mem_ctrl_r[1:0])
            `MEM_SIZE_BYTE: begin
                case (addr_r[1:0])
                    2'b00: begin sel = 4'b0001; store_data = {24'b0, wdata_r[7:0]}; end
                    2'b01: begin sel = 4'b0010; store_data = {16'b0, wdata_r[7:0], 8'b0}; end
                    2'b10: begin sel = 4'b0100; store_data = {8'b0, wdata_r[7:0], 16'b0}; end
                    default: begin sel = 4'b1000; store_data = {wdata_r[7:0], 24'b0}; end
                endcase
            end

            `MEM_SIZE_HALF: begin
                if (addr_r[1]) begin
                    sel = 4'b1100;
                    store_data = {wdata_r[15:0], 16'b0};
                end else begin
                    sel = 4'b0011;
                    store_data = {16'b0, wdata_r[15:0]};
                end
            end

            default: begin
                sel = 4'b1111;
                store_data = wdata_r;
            end
        endcase
    end

    always @(*) begin
        case (mem_ctrl_r[1:0])
            `MEM_SIZE_BYTE: begin
                case (addr_r[1:0])
                    2'b00: load_data = mem_ctrl_r[2] ? {24'b0, rib_data_i[7:0]} : {{24{rib_data_i[7]}}, rib_data_i[7:0]};
                    2'b01: load_data = mem_ctrl_r[2] ? {24'b0, rib_data_i[15:8]} : {{24{rib_data_i[15]}}, rib_data_i[15:8]};
                    2'b10: load_data = mem_ctrl_r[2] ? {24'b0, rib_data_i[23:16]} : {{24{rib_data_i[23]}}, rib_data_i[23:16]};
                    default: load_data = mem_ctrl_r[2] ? {24'b0, rib_data_i[31:24]} : {{24{rib_data_i[31]}}, rib_data_i[31:24]};
                endcase
            end

            `MEM_SIZE_HALF: begin
                if (addr_r[1]) begin
                    load_data = mem_ctrl_r[2] ? {16'b0, rib_data_i[31:16]} : {{16{rib_data_i[31]}}, rib_data_i[31:16]};
                end else begin
                    load_data = mem_ctrl_r[2] ? {16'b0, rib_data_i[15:0]} : {{16{rib_data_i[15]}}, rib_data_i[15:0]};
                end
            end

            default: begin
                load_data = rib_data_i;
            end
        endcase
    end

    always @(*) begin
        state_next = state;
        mem_read_next = mem_read_r;
        mem_write_next = mem_write_r;
        addr_next = addr_r;
        wdata_next = wdata_r;
        mem_ctrl_next = mem_ctrl_r;
        rdata_next = rdata_r;

        case (state)
            LSU_IDLE: begin
                if (start_i) begin
                    mem_read_next = mem_read_i;
                    mem_write_next = mem_write_i;
                    addr_next = addr_i;
                    wdata_next = wdata_i;
                    mem_ctrl_next = mem_ctrl_i;
                    rdata_next = {`DATA_WIDTH{1'b0}};
                    state_next = LSU_REQ;
                end
            end

            LSU_REQ: begin
                if (req_hasked) begin
                    state_next = LSU_RSP;
                end
            end

            LSU_RSP: begin
                if (rsp_hasked) begin
                    rdata_next = mem_read_r ? load_data : {`DATA_WIDTH{1'b0}};
                    state_next = LSU_DONE;
                end
            end

            LSU_DONE: begin
                if (accept_i) begin
                    state_next = LSU_IDLE;
                end
            end

            default: begin
                state_next = LSU_IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= LSU_IDLE;
            mem_read_r <= 1'b0;
            mem_write_r <= 1'b0;
            addr_r <= {`DATA_WIDTH{1'b0}};
            wdata_r <= {`DATA_WIDTH{1'b0}};
            mem_ctrl_r <= `MEM_CTRL_SW;
            rdata_r <= {`DATA_WIDTH{1'b0}};
        end else begin
            state <= state_next;
            mem_read_r <= mem_read_next;
            mem_write_r <= mem_write_next;
            addr_r <= addr_next;
            wdata_r <= wdata_next;
            mem_ctrl_r <= mem_ctrl_next;
            rdata_r <= rdata_next;
        end
    end

    assign busy_o = (state != LSU_IDLE) & (state != LSU_DONE);
    assign ready_o = (state == LSU_DONE);
    assign rdata_o = rdata_r;

    assign rib_addr_o = addr_r;
    assign rib_data_o = store_data;
    assign rib_sel_o = sel;
    assign rib_req_vld_o = (state == LSU_REQ);
    assign rib_rsp_rdy_o = (state == LSU_RSP);
    assign rib_we_o = mem_write_r;

endmodule
