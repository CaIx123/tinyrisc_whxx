`include "../marcos.v"

module mem_rtu(

    input wire clk,
    input wire rst_n,
    input wire start_i,
    input wire accept_i,

    output wire busy_o,
    output wire ready_o,
    output wire[`DATA_WIDTH-1:0] reg_wdata_o,

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

    localparam RT_IDLE             = 4'd0;
    localparam RT_WRITE_SLAVE_ADDR = 4'd1;
    localparam RT_START_READ       = 4'd2;
    localparam RT_WAIT_READ_BUSY   = 4'd3;
    localparam RT_POLL_READ        = 4'd4;
    localparam RT_CHECK_READ       = 4'd5;
    localparam RT_READ_RX_DATA     = 4'd6;
    localparam RT_DONE             = 4'd7;

    localparam LM75_SLAVE_ADDR = 7'h48;
    localparam I2C_CTRL_ADDR       = 32'h7000_0000;
    localparam I2C_SLAVE_ADDR_ADDR = 32'h7001_0000;
    localparam I2C_RX_DATA_ADDR    = 32'h7003_0000;
    localparam I2C_STATUS_ADDR     = 32'h7004_0000;

    localparam I2C_STATUS_BUSY     = 0;
    localparam I2C_STATUS_DONE     = 1;
    localparam I2C_STATUS_ACK_ERR  = 2;
    localparam I2C_STATUS_RX_VALID = 3;

    reg[3:0] state, state_next;
    reg wait_rsp, wait_rsp_next;
    reg[`DATA_WIDTH-1:0] reg_wdata_r, reg_wdata_next;

    wire req_hasked = rib_req_vld_o & rib_req_rdy_i;
    wire rsp_hasked = rib_rsp_vld_i & rib_rsp_rdy_o;

    always @(*) begin
        state_next = state;
        wait_rsp_next = wait_rsp;
        reg_wdata_next = reg_wdata_r;

        if ((state != RT_IDLE) && (state != RT_DONE)) begin
            if (!wait_rsp && req_hasked) begin
                wait_rsp_next = 1'b1;
            end else if (wait_rsp && rsp_hasked) begin
                wait_rsp_next = 1'b0;

                case (state)
                    RT_WRITE_SLAVE_ADDR: begin
                        state_next = RT_START_READ;
                    end

                    RT_START_READ: begin
                        state_next = RT_WAIT_READ_BUSY;
                    end

                    RT_WAIT_READ_BUSY: begin
                        if (rib_data_i[I2C_STATUS_BUSY]) begin
                            state_next = RT_POLL_READ;
                        end
                    end

                    RT_POLL_READ: begin
                        if (!rib_data_i[I2C_STATUS_BUSY] && rib_data_i[I2C_STATUS_DONE]) begin
                            state_next = RT_CHECK_READ;
                        end
                    end

                    RT_CHECK_READ: begin
                        if (rib_data_i[I2C_STATUS_ACK_ERR] || !rib_data_i[I2C_STATUS_RX_VALID]) begin
                            reg_wdata_next = {`DATA_WIDTH{1'b0}};
                            state_next = RT_DONE;
                        end else begin
                            state_next = RT_READ_RX_DATA;
                        end
                    end

                    RT_READ_RX_DATA: begin
                        reg_wdata_next = {{24{rib_data_i[15]}}, rib_data_i[14:7]};
                        state_next = RT_DONE;
                    end

                    default: begin
                        state_next = RT_IDLE;
                    end
                endcase
            end
        end

        case (state)
            RT_IDLE: begin
                wait_rsp_next = 1'b0;
                reg_wdata_next = {`DATA_WIDTH{1'b0}};
                if (start_i) begin
                    state_next = RT_WRITE_SLAVE_ADDR;
                end
            end

            RT_DONE: begin
                wait_rsp_next = 1'b0;
                if (accept_i) begin
                    state_next = RT_IDLE;
                end
            end

            default: begin
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= RT_IDLE;
            wait_rsp <= 1'b0;
            reg_wdata_r <= {`DATA_WIDTH{1'b0}};
        end else begin
            state <= state_next;
            wait_rsp <= wait_rsp_next;
            reg_wdata_r <= reg_wdata_next;
        end
    end

    assign busy_o = (state != RT_IDLE) & (state != RT_DONE);
    assign ready_o = (state == RT_DONE);
    assign reg_wdata_o = reg_wdata_r;

    assign rib_addr_o =
        (state == RT_WRITE_SLAVE_ADDR) ? I2C_SLAVE_ADDR_ADDR :
        (state == RT_START_READ)       ? I2C_CTRL_ADDR :
        (state == RT_READ_RX_DATA)     ? I2C_RX_DATA_ADDR :
                                        I2C_STATUS_ADDR;

    assign rib_data_o =
        (state == RT_WRITE_SLAVE_ADDR) ? {25'b0, LM75_SLAVE_ADDR} :
        (state == RT_START_READ)       ? 32'h0000_0003 :
                                        {`DATA_WIDTH{1'b0}};

    assign rib_sel_o = 4'b1111;
    assign rib_req_vld_o = (state != RT_IDLE) & (state != RT_DONE) & !wait_rsp;
    assign rib_rsp_rdy_o = (state != RT_IDLE) & (state != RT_DONE) & wait_rsp;
    assign rib_we_o = (state == RT_WRITE_SLAVE_ADDR) |
                      (state == RT_START_READ);

endmodule
