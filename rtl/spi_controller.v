`timescale 1ns / 1ps

module spi_controller (
    input  wire        rd_clk,
    input  wire        reset,

    input  wire [15:0] fifo_dout,
    input  wire        fifo_empty,
    output reg         fifo_rd_en,

    output reg         spi_start,
    output reg [15:0]  spi_data,
    input  wire        spi_busy,
    input  wire        spi_done
);
    localparam IDLE      = 3'd0;
    localparam FIFO_READ = 3'd1;
    localparam WAIT_DATA = 3'd2;
    localparam START_SPI = 3'd3;
    localparam WAIT_SPI  = 3'd4;

    reg [2:0] state;

    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            fifo_rd_en <= 1'b0;
            spi_start  <= 1'b0;
            spi_data   <= 16'd0;
        end else begin
            fifo_rd_en <= 1'b0;
            spi_start  <= 1'b0;

            case (state)
                IDLE: begin
                    if (!fifo_empty)
                        state <= FIFO_READ;
                end

                FIFO_READ: begin
                    fifo_rd_en <= 1'b1;
                    state      <= WAIT_DATA;
                end

                WAIT_DATA: begin
                    // FIFO read data is registered; it is valid here.
                    spi_data <= fifo_dout;
                    state    <= START_SPI;
                end

                START_SPI: begin
                    if (!spi_busy) begin
                        spi_start <= 1'b1;
                        state     <= WAIT_SPI;
                    end
                end

                WAIT_SPI: begin
                    if (spi_done)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
