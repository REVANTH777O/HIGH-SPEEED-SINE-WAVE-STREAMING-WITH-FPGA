`timescale 1ns / 1ps

module asynch_fifo #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  reset,
    input  wire                  wr_clk,
    input  wire                  rd_clk,
    input  wire                  wr_enb,
    input  wire                  rd_enb,
    input  wire [DATA_WIDTH-1:0] fifo_din,
    output reg  [DATA_WIDTH-1:0] fifo_dout,
    output wire                  full,
    output wire                  empty
);

    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    reg [PTR_WIDTH-1:0] wr_ptr_bin, rd_ptr_bin;
    reg [PTR_WIDTH-1:0] wr_ptr_gray, rd_ptr_gray;

    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_sync1, rd_gray_sync2;
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_sync1, wr_gray_sync2;

    wire wr_do = wr_enb && !full;
    wire rd_do = rd_enb && !empty;

    wire [PTR_WIDTH-1:0] wr_bin_next  = wr_ptr_bin + wr_do;
    wire [PTR_WIDTH-1:0] rd_bin_next  = rd_ptr_bin + rd_do;
    wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    wire [PTR_WIDTH-1:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    assign empty = (rd_ptr_gray == wr_gray_sync2);

    // Current-state full flag. The pointer is advanced only when
    // wr_enb && !full is true, so full asserts immediately after
    // the 16th accepted write and blocks the 17th write.
    assign full = (wr_ptr_gray ==
                   {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
                     rd_gray_sync2[PTR_WIDTH-3:0]});

    always @(posedge wr_clk or posedge reset) begin
        if (reset) begin
            wr_ptr_bin  <= 'd0;
            wr_ptr_gray <= 'd0;
        end else if (wr_do) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= fifo_din;
            wr_ptr_bin  <= wr_bin_next;
            wr_ptr_gray <= wr_gray_next;
        end
    end

    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            rd_ptr_bin  <= 'd0;
            rd_ptr_gray <= 'd0;
            fifo_dout   <= 'd0;
        end else if (rd_do) begin
            fifo_dout   <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin  <= rd_bin_next;
            rd_ptr_gray <= rd_gray_next;
        end
    end

    always @(posedge wr_clk or posedge reset) begin
        if (reset) begin
            rd_gray_sync1 <= 'd0;
            rd_gray_sync2 <= 'd0;
        end else begin
            rd_gray_sync1 <= rd_ptr_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    always @(posedge rd_clk or posedge reset) begin
        if (reset) begin
            wr_gray_sync1 <= 'd0;
            wr_gray_sync2 <= 'd0;
        end else begin
            wr_gray_sync1 <= wr_ptr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

endmodule
