`timescale 1ns / 1ps

module tb_asynch_fifo;

    reg reset;
    reg wr_clk;
    reg rd_clk;
    reg wr_enb;
    reg rd_enb;
    reg [15:0] fifo_din;

    wire [15:0] fifo_dout;
    wire full;
    wire empty;

    integer i;
    integer errors;
    reg [15:0] expected [0:15];

    asynch_fifo uut (
        .reset     (reset),
        .wr_clk    (wr_clk),
        .rd_clk    (rd_clk),
        .wr_enb    (wr_enb),
        .rd_enb    (rd_enb),
        .fifo_din  (fifo_din),
        .fifo_dout (fifo_dout),
        .full      (full),
        .empty     (empty)
    );

    initial begin wr_clk = 1'b0; forever #5   wr_clk = ~wr_clk; end
    initial begin rd_clk = 1'b0; forever #125 rd_clk = ~rd_clk; end

    task write_word;
        input [15:0] data;
        begin
            @(negedge wr_clk);
            fifo_din = data;
            wr_enb   = 1'b1;
            @(posedge wr_clk);
            #1;
            wr_enb   = 1'b0;
        end
    endtask

    task read_word;
        input [15:0] data;
        begin
            @(negedge rd_clk);
            rd_enb = 1'b1;
            @(posedge rd_clk);
            #1;
            if (fifo_dout !== data) begin
                $display("[FAIL] READ expected=%h got=%h time=%0t",
                         data, fifo_dout, $time);
                errors = errors + 1;
            end else begin
                $display("[PASS] READ %h time=%0t", fifo_dout, $time);
            end
            rd_enb = 1'b0;
        end
    endtask

    initial begin
        errors  = 0;
        reset   = 1'b1;
        wr_enb  = 1'b0;
        rd_enb  = 1'b0;
        fifo_din = 16'd0;

        for (i = 0; i < 16; i = i + 1)
            expected[i] = (i + 1) * 16'd10;

        #300;
        @(negedge wr_clk);
        reset = 1'b0;

        #1;
        if (!empty) begin
            $display("[FAIL] FIFO is not EMPTY after reset");
            errors = errors + 1;
        end else begin
            $display("[PASS] FIFO EMPTY after reset");
        end

        for (i = 0; i < 16; i = i + 1)
            write_word(expected[i]);

        #1;
        if (!full) begin
            $display("[FAIL] FIFO did not become FULL");
            errors = errors + 1;
        end else begin
            $display("[PASS] FIFO FULL after 16 writes");
        end

        // 17th write must be blocked.
        @(negedge wr_clk);
        fifo_din = 16'hDEAD;
        wr_enb   = 1'b1;
        @(posedge wr_clk);
        #1;
        wr_enb = 1'b0;

        if (!full) begin
            $display("[FAIL] FIFO FULL flag dropped on blocked write");
            errors = errors + 1;
        end else begin
            $display("[PASS] 17th write blocked");
        end

        for (i = 0; i < 16; i = i + 1)
            read_word(expected[i]);

        repeat (3) @(posedge rd_clk);
        #1;

        if (!empty) begin
            $display("[FAIL] FIFO did not become EMPTY");
            errors = errors + 1;
        end else begin
            $display("[PASS] FIFO EMPTY after 16 reads");
        end

        if (errors == 0)
            $display("========== FIFO TEST PASSED ==========");
        else
            $display("========== FIFO TEST FAILED: %0d errors ==========", errors);

        $finish;
    end

endmodule
