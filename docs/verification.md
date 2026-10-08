# Verification and Hardware Results

## Simulation

The project was verified incrementally before hardware testing:

1. **Asynchronous FIFO standalone** — 16-bit data, 16-entry depth, independent write/read clocks, full/empty behavior and read ordering verified.
2. **DDS standalone** — DDS Compiler wrapper verified with `PHASE_INC = 1311` at a 50 MHz system clock; expected output frequency is approximately 1 MHz.
3. **DDS -> capture -> FIFO** — captured DDS samples were compared against FIFO reads with zero scoreboard errors.
4. **Full SPI loopback** — DDS -> FIFO -> SPI controller -> SPI master -> SPI slave loopback completed with zero reported sample mismatches.

## Hardware

Target: **EDGE ZYNQ-7020**

- PL clock: 50 MHz
- DDS phase increment: 1311
- Target DDS output: approximately 1 MHz
- ILA capture depth: 4096 samples
- Debug capture: `fifo_din[15:0]`, `fifo_wr_en`, FIFO read/control signals and SPI signals

The final ILA capture contains 4096 hardware samples. Reconstructing the three ILA fragments of `fifo_din[15:0]` gives:

- Minimum: -32766
- Maximum: 32558
- Dominant frequency estimate: 1.000977 MHz
- Peak magnitude: approximately full-scale 16-bit

The measured frequency is consistent with the configured approximately 1 MHz DDS output.

## Hardware evidence

- `hardware_results/ila_dds_waveform.png` — ILA view showing the DDS/FIFO waveform and SPI activity.
- `hardware_results/ila_spi_waveform.png` — ILA view showing SPI control and serial activity.
- `hardware_results/final_dds_hardware_capture.csv` — raw 4096-sample ILA export.
- `hardware_results/zynq7020_final_dds_hardware_waveform.png` — reconstructed signed 16-bit hardware waveform.
