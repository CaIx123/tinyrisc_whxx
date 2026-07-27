//当访问地址为0x9999时，发送字符串"2025310836"到串口
//其它情况下，直接访问串口模块
module uart_top(

	input wire clk,
	input wire rst,

    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,

    output wire[31:0] data_o,
	output wire tx_pin,
    input wire rx_pin
    );

    wire tx_data_ready;
    reg send_id; 

    wire we_o;
    wire [31:0] data;
    wire [31:0] addr;
    wire inst;
    wire start;

    reg we_reg; 

    reg [1:0] state;
    reg [3:0] char_index;
    reg [7:0] char_data;
    wire [7:0] char;
    assign char = char_data;

    assign we_o = send_id ? we_reg : we_i;
    assign data = send_id ? {24'b0, char} : data_i;
    assign addr = send_id ? 32'hc : addr_i;

    assign inst = (addr_i[27:0] == 28'h00009999);
    assign start = (we_i && inst);


    always @ (*) begin
        case (char_index)
            4'd0: char_data = 8'h32;
            4'd1: char_data = 8'h30;
            4'd2: char_data = 8'h32;
            4'd3: char_data = 8'h35; 
            4'd4: char_data = 8'h33;
            4'd5: char_data = 8'h31;
            4'd6: char_data = 8'h30; 
            4'd7: char_data = 8'h38;
            4'd8: char_data = 8'h33;
            4'd9: char_data = 8'h36;
            default: char_data = 8'h00;
        endcase
    end

    localparam STATE_IDLE = 2'b00;
    localparam STATE_SEND = 2'b10;
    localparam STATE_END = 2'b11;
    
    reg tx_data_ready_d;
    always @ (posedge clk) begin
        tx_data_ready_d <= tx_data_ready;
    end

    wire tx_data_ready_posedge = tx_data_ready && !tx_data_ready_d;

    always @ (posedge clk) begin
        if (!rst) begin
            state <= STATE_IDLE;
            char_index <= 4'd0;
            we_reg <= 1'b0;
            send_id <= 1'b0;
        end 
        else begin
            case (state)
                STATE_IDLE: begin
                    if (start) begin
                        state <= STATE_SEND;
                        we_reg <= 1'b1;
                        send_id <= 1'b1;
                    end
                    else begin 
                        we_reg <= 1'b0;
                        send_id <= 1'b0;
                        char_index <= 4'd0;
                    end
                end
                STATE_SEND: begin
                    if (char_index < 4'd9) begin
                        if (tx_data_ready_posedge) begin
                            char_index <= char_index + 1'b1;
                            we_reg <= 1'b1;
                        end
                        else begin
                            we_reg <= 1'b0;
                        end
                    end 
                    else begin
                        state <= STATE_END;
                        we_reg <= 1'b0;
                    end
                end
                STATE_END: begin
                    state <= STATE_IDLE;
                    char_index <= 4'd0;
                end
            endcase
        end
    end
    
    



uart uart_0(
    .clk(clk),
    .rst(rst),
    .we_i(we_o),
    .addr_i(addr),
    .data_i(data),
    .data_o(data_o),
    .tx_pin(tx_pin),
    .rx_pin(rx_pin),
    .tx_data_ready(tx_data_ready)
);

endmodule