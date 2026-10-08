`timescale 1ns / 1ps

module spi_master #(
    parameter CLK_DIV = 2
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       start,
    input  wire [15:0] data_in,
    output reg        busy,
    output reg        done,
    output reg        mosi,
    output reg        sclk,
    output reg        cs
);
    reg [15:0] shift_reg;
    reg [4:0]  bit_count;
    reg [15:0] div_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            busy      <= 1'b0;
            done      <= 1'b0;
            mosi      <= 1'b0;
            sclk      <= 1'b0;
            cs        <= 1'b1;
            shift_reg <= 16'd0;
            bit_count <= 5'd0;
            div_count <= 16'd0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sclk <= 1'b0;
                cs   <= 1'b1;

                if (start) begin
                    busy      <= 1'b1;
                    cs        <= 1'b0;
                    shift_reg <= data_in;
                    bit_count <= 5'd0;
                    div_count <= 16'd0;
                    mosi      <= data_in[15];
                end
            end else begin
                if (div_count == CLK_DIV-1) begin
                    div_count <= 16'd0;

                    if (!sclk) begin
                        // Rising SCLK edge: slave samples MOSI.
                        sclk <= 1'b1;
                    end else begin
                        // Falling SCLK edge: advance to next bit.
                        sclk <= 1'b0;

                        if (bit_count == 5'd15) begin
                            busy      <= 1'b0;
                            cs        <= 1'b1;
                            done      <= 1'b1;
                            mosi      <= 1'b0;
                            bit_count <= 5'd0;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                            shift_reg <= {shift_reg[14:0],1'b0};
                            mosi      <= shift_reg[14];
                        end
                    end
                end else begin
                    div_count <= div_count + 1'b1;
                end
            end
        end
    end
endmodule
