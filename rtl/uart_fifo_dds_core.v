`timescale 1ns / 1ps

// Clean integration shell.
// DDS IP is intentionally instantiated in dds_top.v because its exact
// generated interface depends on the Vivado DDS Compiler configuration.

module uart_fifo_dds_core (
    input  wire        sys_clk,
    input  wire        reset,

    output wire        fifo_full,
    output wire        fifo_empty,
    output wire [15:0] fifo_dout,

    output wire        spi_mosi,
    output wire        spi_sclk,
    output wire        spi_cs,

    output wire [15:0] spi_rx_data,
    output wire        spi_rx_valid
);
    wire rd_clk;

    wire        sine_valid;
    wire [15:0] sine;
    wire        fifo_wr_en;
    wire [15:0] fifo_din;

    wire        fifo_rd_en;
    wire        spi_start;
    wire [15:0] spi_data;
    wire        spi_busy;
    wire        spi_done;

    // 50 MHz / (2*6) = 4.1667 MHz.
    // This is an integer-divider engineering choice for the current
    // 50 MHz board clock. Exact 4 MHz requires a fractional/PLL/MMCM clock.
    clock_divider #(.HALF_PERIOD(6)) u_rdclk (
        .clk_in  (sys_clk),
        .reset   (reset),
        .clk_out (rd_clk)
    );

    dds_top u_dds (
        .clk   (sys_clk),
        .reset (reset),
        .sine  (sine),
        .valid (sine_valid)
    );

    dds_capture u_capture (
        .clk        (sys_clk),
        .reset      (reset),
        .sine_valid (sine_valid),
        .sine       (sine),
        .fifo_wr_en (fifo_wr_en),
        .fifo_din   (fifo_din)
    );

    asynch_fifo u_fifo (
        .reset     (reset),
        .wr_clk    (sys_clk),
        .rd_clk    (rd_clk),
        .wr_enb    (fifo_wr_en),
        .rd_enb    (fifo_rd_en),
        .fifo_din  (fifo_din),
        .fifo_dout (fifo_dout),
        .full      (fifo_full),
        .empty     (fifo_empty)
    );

    spi_controller u_ctrl (
        .rd_clk     (rd_clk),
        .reset      (reset),
        .fifo_dout  (fifo_dout),
        .fifo_empty (fifo_empty),
        .fifo_rd_en (fifo_rd_en),
        .spi_start  (spi_start),
        .spi_data   (spi_data),
        .spi_busy   (spi_busy),
        .spi_done   (spi_done)
    );

    spi_master #(.CLK_DIV(2)) u_master (
        .clk      (rd_clk),
        .reset    (reset),
        .start    (spi_start),
        .data_in  (spi_data),
        .busy     (spi_busy),
        .done     (spi_done),
        .mosi     (spi_mosi),
        .sclk     (spi_sclk),
        .cs       (spi_cs)
    );

    spi_slave u_slave (
        .reset   (reset),
        .sclk    (spi_sclk),
        .cs      (spi_cs),
        .mosi    (spi_mosi),
        .rx_data (spi_rx_data),
        .rx_valid(spi_rx_valid)
    );

endmodule
