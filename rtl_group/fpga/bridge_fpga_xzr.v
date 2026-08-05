`timescale 1ns / 1ps

`include "../top/macros.v"

module bridge_fpga_xzr(
    input wire clk,
    input wire rst,
    input wire[7:0] rx_8bit,
    output reg[7:0] tx_8bit,
    output wire [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output wire rom_we,
    output wire ram_we,
    input wire [31:0] rom_data,
    input wire [31:0] ram_data
);

    reg [2:0] state;
    reg [31:0] mem_addr_r;
    reg cmd_we, cmd_target;
    reg mem_we;
    assign rom_we = (!cmd_target) & mem_we;
    assign ram_we = cmd_target & mem_we;

    //wire [31:0] base_addr = cmd_target ? 32'h1000_0000 : 32'h0000_0000;
    wire [31:0] current_data = cmd_target ? ram_data : rom_data;
    // gen_ram has a synchronous read address.  During the address phase the
    // incoming address must already be visible at its port before the edge;
    // using only the registered value would make every read return the
    // preceding word.
    assign mem_addr = (state == 3'd1) ? {22'b0, rx_8bit, 2'b0} : mem_addr_r;


    always @(*) begin
        if (!cmd_we && state >= 2 && state <= 5) begin
            case(state)
                2: tx_8bit = current_data[7:0];
                3: tx_8bit = current_data[15:8];
                4: tx_8bit = current_data[23:16];
                5: tx_8bit = current_data[31:24];
                default: tx_8bit = 8'h0;
            endcase
        end else begin
            tx_8bit = 8'h0;
        end
    end

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            state <= 0; mem_we <= 0;
            mem_addr_r <= 0; mem_wdata <= 0;
        end else begin
            case (state)
                0: begin
                    mem_we <= 0;
                    if (rx_8bit[7]) begin 
                        cmd_we <= rx_8bit[6];
                        cmd_target <= rx_8bit[5];
                        state <= 1;
                    end
                end
                1: begin 
                    mem_addr_r <= {22'b0, rx_8bit, 2'b0};
                    state <= 2;
                end
                2, 3, 4, 5: begin
                    if (cmd_we) begin
                        case(state)
                            2: mem_wdata[7:0]   <= rx_8bit;
                            3: mem_wdata[15:8]  <= rx_8bit;
                            4: mem_wdata[23:16] <= rx_8bit;
                            5: begin mem_wdata[31:24] <= rx_8bit; mem_we <= 1'b1; end
                        endcase
                    end 
                    
                    if (state == 5) begin 
                        state <= 0; 
                        
                    end
                    else begin
                        state <= state + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
