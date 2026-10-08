`timescale 1ns / 1ps

module dds_capture #(
    parameter DATA_WIDTH = 16
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  sine_valid,
    input  wire [DATA_WIDTH-1:0] sine,
    output reg                   fifo_wr_en,
    output reg  [DATA_WIDTH-1:0] fifo_din
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fifo_wr_en <= 1'b0;
            fifo_din   <= 'd0;
        end else begin
            fifo_wr_en <= sine_valid;
            if (sine_valid)
                fifo_din <= sine;
        end
    end
endmodule
