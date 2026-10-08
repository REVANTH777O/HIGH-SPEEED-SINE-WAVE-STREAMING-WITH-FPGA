`timescale 1ns / 1ps

module spi_slave (
    input  wire        reset,
    input  wire        sclk,
    input  wire        cs,
    input  wire        mosi,
    output reg [15:0]  rx_data,
    output reg         rx_valid
);
    reg [15:0] shift_reg;
    reg [4:0]  count;

    always @(posedge sclk or posedge reset) begin
        if (reset) begin
            shift_reg <= 16'd0;
            rx_data   <= 16'd0;
            rx_valid  <= 1'b0;
            count     <= 5'd0;
        end else if (cs) begin
            count    <= 5'd0;
            rx_valid <= 1'b0;
        end else begin
            shift_reg <= {shift_reg[14:0], mosi};

            if (count == 5'd15) begin
                rx_data  <= {shift_reg[14:0], mosi};
                rx_valid <= 1'b1;
                count    <= 5'd0;
            end else begin
                count    <= count + 1'b1;
                rx_valid <= 1'b0;
            end
        end
    end
endmodule
