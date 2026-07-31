`include "../core/defines.v"

module pwm(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[`MemAddrBus] addr_i,
    input wire[`MemBus] data_i,
    output reg[`MemBus] data_o,
    output reg[3:0] PWM_o
    );

    // ĺŻĺ­ĺ¨ĺŽäš?
    reg[31:0] A[3:0]; // ç¨äşĺ­ĺ¨ćŻä¸ŞPWMčžĺşçĺ¨ć?
    reg[31:0] B[3:0]; // ç¨äşĺ­ĺ¨ćŻä¸ŞPWMčžĺşçĺ çŠşćŻ
    reg[3:0] C;       // ç¨äşä˝żč˝ćŻä¸ŞPWMčžĺşĺźč

    reg[31:0] counter[3:0]; // ç¨äşčŽĄć°ćŻä¸ŞPWMčžĺşçĺ¨ć?

    // ĺĺŻĺ­ĺ¨éťčž
    always @(posedge clk or negedge rst) begin
        if (rst == 1'b0) begin
//            integer i;
//            for (i = 0; i < 4; i = i + 1) begin
//                A[i] <= 32'b0;
//                B[i] <= 32'b0;
//                counter[i] <= 32'b0;
//            end
            A[0] <= 32'b0;
            A[1] <= 32'b0;
            A[2] <= 32'b0;
            A[3] <= 32'b0;
            B[0] <= 32'b0;
            B[1] <= 32'b0;
            B[2] <= 32'b0;
            B[3] <= 32'b0;
            counter[0] <= 32'b0;
            counter[1] <= 32'b0;
            counter[2] <= 32'b0;
            counter[3] <= 32'b0;
            C <= 4'b0;
            PWM_o <= 4'b0;
        end else begin
            if (we_i) begin
                case (addr_i[27:0])
                    28'h0000000: A[0] <= data_i;
                    28'h0010000: A[1] <= data_i;
                    28'h0020000: A[2] <= data_i;
                    28'h0030000: A[3] <= data_i;
                    28'h0100000: B[0] <= data_i;
                    28'h0110000: B[1] <= data_i;
                    28'h0120000: B[2] <= data_i;
                    28'h0130000: B[3] <= data_i;
                    28'h0040000: C <= data_i[3:0];
                    default: ;
                endcase
            end

            // PWM čŽĄć°ĺ¨é?ťčžĺčžĺşé?ťčž
//            integer i;
//            for (i = 0; i < 4; i = i + 1) begin
//                if (C[i]) begin
//                    if (counter[i] >= A[i] - 1) begin
//                        counter[i] <= 0;
//                    end else begin
//                        counter[i] <= counter[i] + 1;
//                    end
//                    PWM_o[i] <= (counter[i] < B[i]) ? 1'b1 : 1'b0;
//                end else begin
//                    counter[i] <= 0;
//                    PWM_o[i] <= 1'b0;
//                end
//            end
            if (C[0]) begin
                counter[0] <= counter[0] + 1;
                if (counter[0] >= A[0]) begin
                    counter[0] <= 0;
                end
                PWM_o[0] <= (counter[0] < B[0]) ? 1'b1 : 1'b0;
            end else begin
                PWM_o[0] <= 1'b0;
            end
            
            if (C[1]) begin
                counter[1] <= counter[1] + 1;
                if (counter[1] >= A[1]) begin
                    counter[1] <= 0;
                end
                PWM_o[1] <= (counter[1] < B[1]) ? 1'b1 : 1'b0;
            end else begin
                PWM_o[1] <= 1'b0;
            end

            if (C[2]) begin
                counter[2] <= counter[2] + 1;
                if (counter[2] >= A[2]) begin
                    counter[2] <= 0;
                end
                PWM_o[2] <= (counter[2] < B[2]) ? 1'b1 : 1'b0;
            end else begin
                PWM_o[2] <= 1'b0;
            end

            if (C[3]) begin
                counter[3] <= counter[3] + 1;
                if (counter[3] >= A[3]) begin
                    counter[3] <= 0;
                end
                PWM_o[3] <= (counter[3] < B[3]) ? 1'b1 : 1'b0;
            end else begin
                PWM_o[3] <= 1'b0;
            end
        end
    end

    // čŻťĺŻĺ­ĺ¨éťčž
    always @(*) begin
        case (addr_i[27:0])
            28'h0000000: data_o = A[0];
            28'h0010000: data_o = A[1];
            28'h0020000: data_o = A[2];
            28'h0030000: data_o = A[3];
            28'h0100000: data_o = B[0];
            28'h0110000: data_o = B[1];
            28'h0120000: data_o = B[2];
            28'h0130000: data_o = B[3];
            28'h0040000: data_o = {28'b0, C};
            default: data_o = 32'b0;
        endcase
    end
endmodule