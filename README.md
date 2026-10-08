# DDS → Asynchronous FIFO → SPI_TX -> SPI_RX -> SINEWAVE_RECONSTRUCTION on Zynq-7020

A hardware-verified FPGA data path implementing a Xilinx DDS Compiler driven by a 50 MHz PL clock, a 16-bit asynchronous FIFO, and a 16-bit SPI master/slave loopback.

## Architecture

```text
             +------------------+
             |  Xilinx DDS IP   |
             +--------+---------+
                      |
                      v
             +------------------+
             |    dds_top       |
             +--------+---------+
                      |
                      v
             +------------------+
             |   dds_capture    |
             +--------+---------+
                      |
                      | fifo_din[15:0]
                      v
             +------------------+
             |  Async FIFO       |
             | 16-bit x 16       |
             +--------+---------+
                      |
                      v
             +------------------+
             | SPI Controller    |
             +--------+---------+
                      |
                      v
             +------------------+
             |   SPI Master     |
             +---+----+----+----+
                 |    |    |
                CS   SCLK MOSI
                 |    |    |
                 +----+----+-------> SPI Slave
                                      |
                                      v
                                16-bit RX data
```

## Key features

- Verilog RTL implementation
- 50 MHz Zynq PL clock
- 16-bit, 16-entry asynchronous FIFO
- Gray-coded CDC pointers with two-stage synchronizers
- 16-bit SPI master/slave loopback
- Vivado DDS Compiler integration
- ILA-based hardware verification
- 4096-sample hardware capture
- Reconstructed signed 16-bit DDS waveform from real FPGA samples

## Repository layout

```text
rtl/
  asynch_fifo.v
  clock_divider.v
  dds_capture.v
  dds_top.v
  spi_controller.v
  spi_master.v
  spi_slave.v
  top_wrapper.v
  uart_fifo_dds_core.v

tb/
  asynch_fifo_tb.v
  uart_fifo_dds_loopback_tb.v

constraints/
  edge_zynq_7020.xdc
  edge_zynq_7020_dds_spi.xdc

hardware_results/
  final_dds_hardware_capture.csv
  ila_dds_waveform.png
  ila_spi_waveform.png
  zynq7020_final_dds_hardware_waveform.png

docs/
  verification.md
  ila_probe_configuration.txt
```

## Hardware result

The final Zynq-7020 ILA capture contains **4096 samples**. After reconstructing the complete 16-bit `fifo_din` bus from the ILA-exported fragments:

| Measurement | Result |
|---|---:|
| ILA samples | 4096 |
| Minimum amplitude | -32766 |
| Maximum amplitude | 32558 |
| Peak magnitude | ~32766 |
| Estimated dominant frequency | 1.000977 MHz |

The result demonstrates real hardware DDS activity and the downstream FIFO/SPI data path.

## DDS configuration

`dds_top.v` expects a Vivado DDS Compiler IP instance named `dds_compiler_0` with the ports used by the wrapper. The generated IP source is intentionally not committed here; recreate/import the DDS Compiler IP in Vivado using the project configuration before synthesis.

For the current design:

```text
System clock = 50 MHz
PHASE_INC    = 1311
Target DDS frequency ≈ 1 MHz
```

## Board constraints

The supplied XDC targets the EDGE ZYNQ-7020 board:

- PL clock: `U18` — 50 MHz
- Reset: `P15`
- SPI MOSI: `J20`
- SPI SCLK: `H20`
- SPI CS: `G19`
- LEDs: `R16`, `R17`, `T17`, `R18`

## Verification flow

```text
FIFO standalone
      ↓
DDS standalone
      ↓
DDS → Capture → FIFO
      ↓
Full SPI loopback
      ↓
Synthesis / Implementation
      ↓
ILA insertion
      ↓
Zynq-7020 programming
      ↓
4096-sample hardware capture
      ↓
CSV reconstruction
      ↓
DDS hardware waveform
```

## Notes

This repository intentionally excludes Vivado-generated run/cache/IP-user directories. The DDS Compiler IP must be generated in Vivado because its generated files are tool/version/configuration dependent.
