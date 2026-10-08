`timescale 1ns / 1ps

module tb_uart_fifo_dds_loopback;

    reg clk;
    reg reset;

    wire fifo_full;
    wire fifo_empty;
    wire [15:0] fifo_dout;
    wire spi_mosi, spi_sclk, spi_cs;
    wire [15:0] spi_rx_data;
    wire spi_rx_valid;

    uart_fifo_dds_core dut (
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

    initial begin clk = 0; forever #10 clk = ~clk; end

    initial begin
        reset = 1'b1;
        #200;
        reset = 1'b0;

        // Allow the complete chain to run.
        #200000;

        $display("Loopback simulation finished.");
        $finish;
    end

endmodule
