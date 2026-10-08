`timescale 1ns / 1ps

module clock_divider #(
    parameter HALF_PERIOD = 6
)(
    input  wire clk_in,
    input  wire reset,
    output reg  clk_out
);
    localparam COUNT_WIDTH = (HALF_PERIOD <= 1) ? 1 : $clog2(HALF_PERIOD);
    reg [COUNT_WIDTH-1:0] count;

    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            count   <= 'd0;
            clk_out <= 1'b0;
        end else if (count == HALF_PERIOD-1) begin
            count   <= 'd0;
            clk_out <= ~clk_out;
        end else begin
            count <= count + 1'b1;
        end
    end
endmodule
