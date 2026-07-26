`include "defines.v"
`include "../tiny_macro.v"

// Custom read-temperature instruction using the shared I2C register protocol.
// Sequence: address -> pointer -> write start -> poll -> read start -> poll -> data.
module ext_readtemp(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire        mem_req_ready_i,
    input  wire        mem_rsp_valid_i,
    input  wire [31:0] mem_rdata_i,

    output wire        ready_o,
    output wire        bus_req_o,
    output wire        bus_valid_o,
    output wire        bus_we_o,
    output wire [31:0] bus_addr_o,
    output wire [31:0] bus_wdata_o,
    output wire [3:0]  bus_sel_o,

    output wire [31:0] reg_wdata_o,
    output wire        reg_we_o,
    output wire        stall_o
);

    localparam ST_IDLE          = 3'd0;
    localparam ST_WR_ADDR       = 3'd1;
    localparam ST_WR_PTR        = 3'd2;
    localparam ST_START_WRITE   = 3'd3;
    localparam ST_POLL_WRITE    = 3'd4;
    localparam ST_START_READ    = 3'd5;
    localparam ST_POLL_READ     = 3'd6;
    localparam ST_RD_DATA       = 3'd7;

    localparam STATUS_DONE_BIT     = 1;
    localparam STATUS_RX_VALID_BIT = 3;

    reg [2:0]  state;
    reg        running_r;
    reg        ready_r;
    reg [15:0] temp_data_r;
    reg        req_issued_r;
    reg        done_hold_r;

    wire bus_req_hsked = bus_valid_o & mem_req_ready_i;
    wire bus_rsp_hsked = mem_rsp_valid_i & req_issued_r;
    wire start_fire = start_i & ~running_r & ~done_hold_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            running_r <= 1'b0;
            ready_r <= 1'b0;
            temp_data_r <= 16'h0;
            req_issued_r <= 1'b0;
            done_hold_r <= 1'b0;
        end else begin
            ready_r <= 1'b0;
            if (!start_i) begin
                done_hold_r <= 1'b0;
            end

            if (start_fire) begin
                state <= ST_WR_ADDR;
                running_r <= 1'b1;
                req_issued_r <= 1'b0;
            end else begin
                if (bus_req_hsked) begin
                    req_issued_r <= 1'b1;
                end

                if (bus_rsp_hsked) begin
                    req_issued_r <= 1'b0;
                    case (state)
                        ST_WR_ADDR: begin
                            state <= ST_WR_PTR;
                        end
                        ST_WR_PTR: begin
                            state <= ST_START_WRITE;
                        end
                        ST_START_WRITE: begin
                            state <= ST_POLL_WRITE;
                        end
                        ST_POLL_WRITE: begin
                            if (mem_rdata_i[STATUS_DONE_BIT]) begin
                                state <= ST_START_READ;
                            end
                        end
                        ST_START_READ: begin
                            state <= ST_POLL_READ;
                        end
                        ST_POLL_READ: begin
                            if (mem_rdata_i[STATUS_RX_VALID_BIT]) begin
                                state <= ST_RD_DATA;
                            end
                        end
                        ST_RD_DATA: begin
                            temp_data_r <= mem_rdata_i[15:0];
                            state <= ST_IDLE;
                            running_r <= 1'b0;
                            ready_r <= 1'b1;
                            done_hold_r <= 1'b1;
                        end
                        default: begin
                            state <= ST_IDLE;
                            running_r <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

    assign bus_req_o = running_r;
    assign bus_valid_o = running_r & ~req_issued_r;

    assign bus_addr_o =
        (state == ST_WR_ADDR)     ? `IIC_ADDR_REG :
        (state == ST_WR_PTR)      ? `IIC_TX_REG :
        (state == ST_START_WRITE) ? `IIC_CTRL_REG :
        (state == ST_POLL_WRITE)  ? `IIC_STATUS_REG :
        (state == ST_START_READ)  ? `IIC_CTRL_REG :
        (state == ST_POLL_READ)   ? `IIC_STATUS_REG :
        (state == ST_RD_DATA)     ? `IIC_RX_REG :
                                    32'h0;

    assign bus_wdata_o =
        (state == ST_WR_ADDR)     ? {25'h0, `LM75_I2C_ADDR} :
        (state == ST_WR_PTR)      ? {24'h0, `LM75_TEMP_REG_PTR} :
        (state == ST_START_WRITE) ? 32'h0000_0001 :
        (state == ST_START_READ)  ? 32'h0000_0003 :
                                    32'h0;

    assign bus_we_o = (state == ST_WR_ADDR) |
                      (state == ST_WR_PTR) |
                      (state == ST_START_WRITE) |
                      (state == ST_START_READ);
    assign bus_sel_o = 4'b1111;

    assign ready_o = ready_r;
    assign reg_wdata_o = {24'h0, temp_data_r[14:7]};
    assign reg_we_o = ready_r;
    assign stall_o = running_r | start_fire;

endmodule
