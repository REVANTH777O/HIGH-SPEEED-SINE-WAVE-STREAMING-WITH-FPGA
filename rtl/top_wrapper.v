`timescale 1ns / 1ps

module top_wrapper (
    input  wire       clk,
    input  wire       reset,
    output wire       spi_mosi,
    output wire       spi_sclk,
    output wire       spi_cs,
    output wire [3:0] led
);

    wire        fifo_full;
    wire        fifo_empty;
    wire [15:0] fifo_dout;
    wire [15:0] spi_rx_data;
    wire        spi_rx_valid;

    uart_fifo_dds_core u_core (
        .sys_clk      (clk),
        .reset        (reset),
        .fifo_full    (fifo_full),
        .fifo_empty   (fifo_empty),
        .fifo_dout    (fifo_dout),
        .spi_mosi     (spi_mosi),
        .spi_sclk     (spi_sclk),
        .spi_cs       (spi_cs),
        .spi_rx_data  (spi_rx_data),
        .spi_rx_valid (spi_rx_valid)
    );

    assign led[0] = fifo_full;
    assign led[1] = fifo_empty;
    assign led[2] = spi_rx_valid;
    assign led[3] = ~spi_cs;

endmodule
