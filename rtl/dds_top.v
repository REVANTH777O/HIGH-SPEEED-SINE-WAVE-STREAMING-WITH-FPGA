`timescale 1ns / 1ps

// Wrapper for the Xilinx DDS Compiler IP.
//
// IMPORTANT:
// Configure/create the DDS Compiler IP in Vivado with the desired
// phase/data widths. The exact generated IP port list must match this
// wrapper. This file intentionally does not invent IP configuration
// parameters.

module dds_top #(
    parameter [15:0] PHASE_INC = 16'd1311
)(
    input  wire        clk,
    input  wire        reset,
    output wire [15:0] sine,
    output wire        valid
);

    reg        phase_valid;
    reg [15:0] phase_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            phase_reg   <= 16'd0;
            phase_valid <= 1'b0;
        end else begin
            phase_reg   <= phase_reg + PHASE_INC;
            phase_valid <= 1'b1;
        end
    end

    dds_compiler_0 u_dds (
        .aclk                 (clk),
        .s_axis_phase_tvalid  (phase_valid),
        .s_axis_phase_tdata   (phase_reg),
        .m_axis_data_tdata    (sine),
        .m_axis_data_tvalid   (valid)
    );

endmodule
