module Encoder(
    input wire [3:0] number,
    output reg [6:0] digital);

    always_comb begin
        if (number == 4'd0) begin
            digital = 7'b0111111;
        end else if (number == 4'd1) begin
            digital = 7'b0000110;
        end else if (number == 4'd2) begin
            digital = 7'b1011011;
        end else if (number == 4'd3) begin
            digital = 7'b1001111;
        end else if (number == 4'd4) begin
            digital = 7'b1100110;
        end else if (number == 4'd5) begin
            digital = 7'b1101101;
        end else if (number == 4'd6) begin
            digital = 7'b1111101;
        end else if (number == 4'd7) begin
            digital = 7'b0000111;
        end else if (number == 4'd8) begin
            digital = 7'b1111111;
        end else if (number == 4'd9) begin
            digital = 7'b1101111;
        end else begin
            digital = 7'b0000000;
        end
    end

endmodule // Encoder