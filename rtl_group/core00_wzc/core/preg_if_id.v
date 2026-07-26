`include "../marcos_wzc.v"

module if_id(

    input wire clk,
    input wire rst_n,
    // from if stage    
    input wire[`INST_WIDTH-1:0] inst_i,                
    input wire[`PC_WIDTH-1:0] pc_i,                  

    // from pipeline control
    input wire stall_if_id_i,                         
    input wire flush_if_id_i,                     // 流水线冲�?
    output wire[`INST_WIDTH-1:0] inst_o,               // 指令内�??
    output wire[`PC_WIDTH-1:0] pc_o           // 指令地址

    );

    reg [`INST_WIDTH-1:0] inst;
    reg [`PC_WIDTH-1:0] pc;

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inst <= `INST_NOP;
            pc <= `CPU_RESET_ADDR;
        end else if (flush_if_id_i) begin
            inst <= `INST_NOP;
            pc <= `CPU_RESET_ADDR;
        end else if (~stall_if_id_i) begin
            inst <= inst_i;
            pc <= pc_i;
        end
    end

    assign inst_o = inst;
    assign pc_o = pc;

endmodule
