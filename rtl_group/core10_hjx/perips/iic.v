`include "../macros.v"
module i2c(

    input wire clk,
    input wire rst_n,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output reg[31:0] data_o,

    input wire req_valid_i,
    output wire req_ready_o,
    output wire rsp_valid_o,
    input wire rsp_ready_i,

    inout wire scl,
    inout wire sda

    );

    localparam REG_CTRL       = 8'h00;
    localparam REG_SLAVE_ADDR = 8'h01;
    localparam REG_TX_DATA    = 8'h02;
    localparam REG_RX_DATA    = 8'h03;
    localparam REG_STATUS     = 8'h04;

    localparam STATUS_BUSY     = 0;
    localparam STATUS_DONE     = 1;
    localparam STATUS_ACK_ERR  = 2;
    localparam STATUS_RX_VALID = 3;

    localparam S_IDLE             = 4'd0;
    localparam S_START_A          = 4'd1;
    localparam S_START_B          = 4'd2;
    localparam S_SEND_ADDR        = 4'd3;
    localparam S_ADDR_ACK         = 4'd4;
    localparam S_SEND_DATA        = 4'd5;
    localparam S_DATA_ACK         = 4'd6;
    localparam S_RECV_DATA        = 4'd7;
    localparam S_SEND_MASTER_ACK  = 4'd8;
    localparam S_SEND_MASTER_NACK = 4'd9;
    localparam S_STOP_A           = 4'd10;
    localparam S_STOP_B           = 4'd11;
    localparam S_DONE             = 4'd12;
    localparam integer I2C_PHASE_DIV = ((`I2C_BAUD_100K + 3) / 4);

    reg[31:0] reg_ctrl;
    reg[31:0] reg_slave_addr;
    reg[31:0] reg_tx_data;
    reg[31:0] reg_rx_data;
    reg[31:0] reg_status;

    reg start_req;
    reg rw_latch;

    reg[3:0] state;
    reg[1:0] phase;
    reg[3:0] bit_cnt;
    reg[7:0] phase_div_cnt;
    reg[7:0] shift_reg;
    reg rx_byte_sel;

    reg scl_oe;
    reg sda_oe;
    reg[31:0] read_data;

    wire sda_in;
    wire status_busy_vis;
    wire status_done_vis;
    wire[31:0] status_data_vis;
    wire req_ready_raw;
    wire start_write_req;
    wire start_write_wait;
    wire req_hasked;
    wire i2c_phase_step;
    wire i2c_timed_state;

    assign scl = (scl_oe == 1'b1) ? 1'b0 : 1'bz;
    assign sda = (sda_oe == 1'b1) ? 1'b0 : 1'bz;
    assign sda_in = sda;
    assign status_busy_vis = (state != S_IDLE) && (state != S_DONE);
    assign status_done_vis = reg_status[STATUS_DONE] || (state == S_DONE);
    assign status_data_vis = {
        reg_status[31:4],
        reg_status[STATUS_RX_VALID],
        reg_status[STATUS_ACK_ERR],
        status_done_vis,
        status_busy_vis
    };
    assign start_write_req = req_valid_i & we_i & (addr_i[23:16] == REG_CTRL) & data_i[0];
    assign start_write_wait = start_write_req & (state != S_IDLE) & (state != S_DONE);
    assign req_hasked = req_valid_i & req_ready_o;
    assign i2c_timed_state = (state != S_IDLE) && (state != S_DONE);
    assign i2c_phase_step = (phase_div_cnt == (I2C_PHASE_DIV - 1));

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl <= 32'h0;
            reg_slave_addr <= 32'h0;
            reg_tx_data <= 32'h0;
            start_req <= 1'b0;
        end else begin
            start_req <= 1'b0;
            if (req_hasked && we_i == 1'b1) begin
                case (addr_i[23:16])
                    REG_CTRL: begin
                        reg_ctrl <= data_i;
                        start_req <= data_i[0];
                    end
                    REG_SLAVE_ADDR: begin
                        reg_slave_addr <= data_i;
                    end
                    REG_TX_DATA: begin
                        reg_tx_data <= data_i;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o <= 32'h0;
        end else if (req_hasked && !we_i) begin
            data_o <= read_data;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_rx_data <= 32'h0;
            reg_status <= 32'h0;
            rw_latch <= 1'b0;
            state <= S_IDLE;
            phase <= 2'd0;
            bit_cnt <= 4'd0;
            phase_div_cnt <= 8'd0;
            shift_reg <= 8'h00;
            rx_byte_sel <= 1'b0;
            scl_oe <= 1'b0;
            sda_oe <= 1'b0;
        end else begin
            if (i2c_timed_state) begin
                if (i2c_phase_step) begin
                    phase_div_cnt <= 8'd0;
                    case (state)
                        S_START_A: begin
                            scl_oe <= 1'b0;
                            sda_oe <= 1'b0;
                            state <= S_START_B;
                        end
                        S_START_B: begin
                            scl_oe <= 1'b0;
                            sda_oe <= 1'b1;
                            phase <= 2'd0;
                            state <= S_SEND_ADDR;
                        end
                        S_SEND_ADDR: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd0;
                                    if (bit_cnt == 4'd0) begin
                                        state <= S_ADDR_ACK;
                                    end else begin
                                        shift_reg <= {shift_reg[6:0], 1'b0};
                                        bit_cnt <= bit_cnt - 1'b1;
                                    end
                                end
                            endcase
                        end
                        S_ADDR_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd0;
                                    if (sda_in == 1'b1) begin
                                        reg_status[STATUS_ACK_ERR] <= 1'b1;
                                        state <= S_STOP_A;
                                    end else if (rw_latch == 1'b1) begin
                                        shift_reg <= 8'h00;
                                        bit_cnt <= 4'd7;
                                        rx_byte_sel <= 1'b0;
                                        state <= S_RECV_DATA;
                                    end else begin
                                        shift_reg <= reg_tx_data[7:0];
                                        bit_cnt <= 4'd7;
                                        state <= S_SEND_DATA;
                                    end
                                end
                            endcase
                        end
                        S_SEND_DATA: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= ~shift_reg[7];
                                    phase <= 2'd0;
                                    if (bit_cnt == 4'd0) begin
                                        state <= S_DATA_ACK;
                                    end else begin
                                        shift_reg <= {shift_reg[6:0], 1'b0};
                                        bit_cnt <= bit_cnt - 1'b1;
                                    end
                                end
                            endcase
                        end
                        S_DATA_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd0;
                                    if (sda_in == 1'b1) begin
                                        reg_status[STATUS_ACK_ERR] <= 1'b1;
                                    end
                                    state <= S_STOP_A;
                                end
                            endcase
                        end
                        S_RECV_DATA: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    shift_reg <= {shift_reg[6:0], sda_in};
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd0;
                                    if (bit_cnt == 4'd0) begin
                                        if (rx_byte_sel == 1'b0) begin
                                            reg_rx_data[15:8] <= shift_reg;
                                            rx_byte_sel <= 1'b1;
                                            shift_reg <= 8'h00;
                                            bit_cnt <= 4'd7;
                                            state <= S_SEND_MASTER_ACK;
                                        end else begin
                                            reg_rx_data[7:0] <= shift_reg;
                                            reg_status[STATUS_RX_VALID] <= 1'b1;
                                            state <= S_SEND_MASTER_NACK;
                                        end
                                    end else begin
                                        bit_cnt <= bit_cnt - 1'b1;
                                    end
                                end
                            endcase
                        end
                        S_SEND_MASTER_ACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b1;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b1;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b1;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd0;
                                    state <= S_RECV_DATA;
                                end
                            endcase
                        end
                        S_SEND_MASTER_NACK: begin
                            case (phase)
                                2'd0: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd1;
                                end
                                2'd1: begin
                                    scl_oe <= 1'b1;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd2;
                                end
                                2'd2: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd3;
                                end
                                default: begin
                                    scl_oe <= 1'b0;
                                    sda_oe <= 1'b0;
                                    phase <= 2'd0;
                                    state <= S_STOP_A;
                                end
                            endcase
                        end
                        S_STOP_A: begin
                            scl_oe <= 1'b1;
                            sda_oe <= 1'b1;
                            state <= S_STOP_B;
                        end
                        S_STOP_B: begin
                            scl_oe <= 1'b0;
                            sda_oe <= 1'b0;
                            state <= S_DONE;
                        end
                        default: begin
                            state <= S_IDLE;
                        end
                    endcase
                end else begin
                    phase_div_cnt <= phase_div_cnt + 1'b1;
                end
            end else begin
                phase_div_cnt <= 8'd0;
                case (state)
                    S_IDLE: begin
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b0;
                        phase <= 2'd0;
                        bit_cnt <= 4'd0;
                        rx_byte_sel <= 1'b0;
                        reg_status[STATUS_BUSY] <= 1'b0;
                        if (start_req == 1'b1) begin
                            rw_latch <= reg_ctrl[1];
                            reg_status[STATUS_BUSY] <= 1'b1;
                            reg_status[STATUS_DONE] <= 1'b0;
                            reg_status[STATUS_ACK_ERR] <= 1'b0;
                            reg_status[STATUS_RX_VALID] <= 1'b0;
                            shift_reg <= {reg_slave_addr[6:0], reg_ctrl[1]};
                            bit_cnt <= 4'd7;
                            state <= S_START_A;
                        end
                    end
                    S_DONE: begin
                        scl_oe <= 1'b0;
                        sda_oe <= 1'b0;
                        reg_status[STATUS_BUSY] <= 1'b0;
                        reg_status[STATUS_DONE] <= 1'b1;
                        state <= S_IDLE;
                    end
                    default: begin
                        state <= S_IDLE;
                    end
                endcase
            end
        end
    end

    always @ (*) begin
        case (addr_i[23:16])
            REG_CTRL: begin
                read_data = reg_ctrl;
            end
            REG_SLAVE_ADDR: begin
                read_data = reg_slave_addr;
            end
            REG_TX_DATA: begin
                read_data = reg_tx_data;
            end
            REG_RX_DATA: begin
                read_data = reg_rx_data;
            end
            REG_STATUS: begin
                read_data = status_data_vis;
            end
            default: begin
                read_data = 32'h0;
            end
        endcase
    end

    vld_rdy #(
        .CUT_READY(0)
    ) u_vld_rdy(
        .clk(clk),
        .rst_n(rst_n),
        .vld_i(req_valid_i & ~start_write_wait),
        .rdy_o(req_ready_raw),
        .rdy_i(rsp_ready_i),
        .vld_o(rsp_valid_o)
    );

    assign req_ready_o = req_ready_raw & ~start_write_wait;

endmodule
