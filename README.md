# High-Speed Sine-Wave Streaming with FPGA

## 1. Project Overview

This project implements and verifies an FPGA-based digital sine-wave streaming system using a Xilinx Zynq-7000 FPGA.

The design generates a digital sine waveform using the Xilinx DDS Compiler IP, captures the generated samples, buffers them through a dual-clock asynchronous FIFO, and transfers the samples through a 16-bit SPI master/slave loopback interface.

The project was developed for an EDGE ZYNQ-7020 development board and was verified at both RTL simulation level and on actual FPGA hardware using Vivado Integrated Logic Analyzer (ILA).

The complete demonstrated data path is:

    DDS Compiler IP
          |
          v
       dds_top
          |
          v
     dds_capture
          |
          v
    Async FIFO (16-bit x 16)
          |
          v
    SPI Controller
          |
          v
      SPI Master
          |
          |  SPI MOSI / SCLK / CS
          v
      SPI Slave
          |
          v
  Reconstructed 16-bit sample

The SPI master and SPI slave are connected internally as a loopback for hardware verification. Therefore, the current implementation demonstrates end-to-end digital sample generation, buffering, serialization, and deserialization inside the FPGA. It is not an external SPI communication demonstration.

---

## 2. Project Objectives

The primary objectives are:

1. Generate a stable digital sine waveform using the FPGA's DDS Compiler IP.
2. Capture valid DDS output samples using synchronous RTL logic.
3. Transfer samples between different clock domains using a properly designed asynchronous FIFO.
4. Implement a 16-bit SPI master for sample serialization.
5. Implement a 16-bit SPI slave for sample reconstruction.
6. Control FIFO reads and SPI transfers using an RTL state machine.
7. Verify each major block independently before integration.
8. Verify the complete DDS-to-SPI loopback path in simulation.
9. Implement the complete system on a Zynq-7020 FPGA.
10. Use Vivado ILA to observe internal FPGA signals.
11. Export hardware-captured samples and reconstruct the actual sine waveform from the ILA data.
12. Measure the resulting hardware waveform and verify its frequency and amplitude.

---

# 3. System Architecture

## 3.1 High-Level Architecture

```text
                 50 MHz System Clock
                        |
                        v
              +-------------------+
              | DDS Compiler IP   |
              | Digital Sine Wave |
              +-------------------+
                        |
                        v
              +-------------------+
              |    dds_top        |
              | Phase generation  |
              +-------------------+
                        |
                        v
              +-------------------+
              |  dds_capture      |
              | Valid/sample      |
              | registration      |
              +-------------------+
                        |
                        | FIFO write domain
                        v
        +--------------------------------+
        |      Asynchronous FIFO         |
        |                                |
        | Data width : 16 bits           |
        | Depth      : 16 samples        |
        |                              |
        | Write clock : 50 MHz            |
        | Read clock  : ~4.17 MHz         |
        |                              |
        | Binary/Gray CDC pointers       |
        | Two-flop synchronizers         |
        +--------------------------------+
                        |
                        | FIFO read domain
                        v
              +-------------------+
              | SPI Controller    |
              | FIFO read / SPI   |
              | transaction FSM   |
              +-------------------+
                        |
                        v
              +-------------------+
              |   SPI Master      |
              | 16-bit transfer   |
              +-------------------+
                        |
              MOSI / SCLK / CS
                        |
                        v
              +-------------------+
              |    SPI Slave      |
              | 16-bit receiver   |
              +-------------------+
                        |
                        v
                SPI RX Data
```

---

# 4. Complete Data Flow

The sample movement through the system is:

```text
DDS phase input
      |
      v
DDS Compiler
      |
      | 16-bit digital sample
      v
dds_top
      |
      v
dds_capture
      |
      | fifo_wr_en + fifo_din
      v
Asynchronous FIFO
      |
      | fifo_rd_en
      v
FIFO registered output
      |
      v
SPI Controller
      |
      | spi_start + spi_data
      v
SPI Master
      |
      | MOSI
      v
SPI Slave
      |
      v
16-bit spi_rx_data
      |
      v
Hardware ILA / verification
```

The producer side operates from the 50 MHz system clock.

The FIFO reader and SPI logic operate from a divided clock. This creates an actual clock-domain crossing between the DDS/sample producer and the SPI consumer.

---

# 5. Clock Domains

The design intentionally contains two clock domains.

## 5.1 Write Clock Domain

The DDS, sample capture, and FIFO write logic use:

```text
Write clock = 50 MHz
Clock period = 20 ns
```

This is the board's PL system clock.

XDC constraint:

```tcl
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports { clk }]
```

## 5.2 Read Clock Domain

The FIFO read side and SPI logic use a divided version of the 50 MHz clock.

The current implementation uses:

```text
HALF_PERIOD = 6
```

which produces approximately:

```text
Read clock ≈ 4.1667 MHz
```

The SPI master further divides this clock.

With:

```text
CLK_DIV = 2
```

the resulting SPI clock is approximately:

```text
SPI SCLK ≈ 1.0417 MHz
```

The exact relationship should be understood from the RTL clock-divider and SPI-divider implementation rather than treated as an external precision clock specification.

---

# 6. RTL Module Description

## 6.1 `dds_top.v`

### Purpose

Wraps the Xilinx DDS Compiler IP and supplies the phase input.

### Main parameters

```verilog
PHASE_INC = 16'd1311
```

### Main interface

```text
clk
reset
sine[15:0]
valid
```

### Operation

After reset, the phase register starts from zero.

On every active clock:

```text
phase_reg <= phase_reg + PHASE_INC
```

The phase-valid signal is asserted after reset, allowing the DDS Compiler to process phase samples.

The DDS Compiler produces:

```text
dds_data
dds_valid
```

which are passed to:

```text
sine
valid
```

### Measured hardware result

The resulting waveform was measured from the hardware ILA capture at approximately:

```text
1.000977 MHz
```

The measured result is based on the exported 4096-sample hardware capture.

---

# 7. DDS Compiler IP

The project uses the Xilinx/Vivado DDS Compiler IP.

The generated IP interface used by the RTL is:

```verilog
dds_compiler_0 dds (
    .aclk(aclk),
    .s_axis_phase_tvalid(s_axis_phase_tvalid),
    .s_axis_phase_tdata(s_axis_phase_tdata),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tdata(m_axis_data_tdata)
);
```

The DDS IP generates the digital waveform; the surrounding RTL handles phase generation, sample capture, buffering, and streaming.

The DDS IP is therefore an external Vivado IP dependency of the project.

The generated IP source/output products are intentionally not committed to the repository because Vivado-generated files are excluded by `.gitignore`.

---

# 8. `dds_capture.v`

## Purpose

Registers the valid DDS sample and generates the FIFO write enable.

The module receives:

```text
sine_valid
sine[15:0]
```

and produces:

```text
fifo_wr_en
fifo_din[15:0]
```

When the DDS sample is valid:

```text
fifo_wr_en <= sine_valid
fifo_din   <= sine
```

The standalone verification confirmed the expected registered behavior.

---

# 9. Asynchronous FIFO

File:

```text
rtl/asynch_fifo.v
```

## 9.1 Configuration

```text
Data width : 16 bits
Depth      : 16 entries
Pointer    : 5 bits
Write clock: 50 MHz
Read clock : approximately 4.1667 MHz
```

The FIFO is required because the sample producer and consumer operate in different clock domains.

## 9.2 FIFO Architecture

The FIFO uses:

- Binary write pointer
- Binary read pointer
- Gray-coded write pointer
- Gray-coded read pointer
- Two-flop synchronizers
- Independent write and read clocks
- Asynchronous reset
- Registered FIFO output

## 9.3 Why Gray Code Is Used

A binary counter can change multiple bits during one increment.

For example:

```text
0111 -> 1000
```

changes multiple bits simultaneously.

Transferring such a binary pointer directly across a clock domain can create ambiguous intermediate states.

Gray coding changes only one bit between consecutive pointer values.

The Gray-coded pointers are therefore synchronized into the opposite clock domain using two flip-flop stages.

## 9.4 Full Detection

The FIFO uses the standard asynchronous FIFO full-detection technique by comparing the write Gray pointer against the synchronized read Gray pointer with the required inverted upper pointer bits.

The implementation is:

```verilog
assign full = (wr_ptr_gray ==
               {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
                rd_gray_sync2[PTR_WIDTH-3:0]});
```

## 9.5 Empty Detection

Empty is detected by comparing the read pointer against the synchronized write pointer:

```verilog
assign empty = (rd_ptr_gray == wr_gray_sync2);
```

## 9.6 FIFO Verification

The standalone FIFO test verified:

```text
FIFO empty after reset
16 successful writes
17th write blocked
16 successful reads
FIFO empty after all reads
```

The tested data sequence was:

```text
000A
0014
001E
0028
0032
003C
0046
0050
005A
0064
006E
0078
0082
008C
0096
00A0
```

Result:

```text
========== FIFO TEST PASSED ==========
```

---

# 10. `clock_divider.v`

The clock divider generates the slower read-domain clock from the 50 MHz system clock.

The current integration uses:

```text
HALF_PERIOD = 6
```

This produces approximately:

```text
4.1667 MHz
```

for the FIFO read and SPI control domain.

The divider is used to create a deliberately slower consumer clock so that the asynchronous FIFO is exercised under a real producer/consumer rate difference.

---

# 11. SPI Controller

File:

```text
rtl/spi_controller.v
```

## Purpose

Coordinates the FIFO read operation and SPI transfer.

The controller is implemented as an FSM with the following states:

```text
IDLE
FIFO_READ
WAIT_FIFO
CAPTURE
START_SPI
WAIT_SPI
```

## State operation

### IDLE

Waits until the FIFO is not empty.

### FIFO_READ

Pulses:

```text
fifo_rd_en
```

to request a FIFO read.

### WAIT_FIFO

Waits for the registered FIFO output latency.

### CAPTURE

Captures:

```text
fifo_dout
```

into:

```text
spi_data
```

### START_SPI

Starts an SPI transaction when the SPI master is not busy.

### WAIT_SPI

Waits for:

```text
spi_done
```

before returning to the IDLE state.

This explicit wait/capture sequence is necessary because the FIFO output is registered.

---

# 12. SPI Master

File:

```text
rtl/spi_master.v
```

## Configuration

```text
Transfer width : 16 bits
CLK_DIV        : 2
```

The SPI master generates:

```text
MOSI
SCLK
CS
```

and provides:

```text
busy
done
```

status signals.

## Transfer sequence

When `start` is asserted:

1. The 16-bit input sample is loaded.
2. `CS` is asserted low.
3. The MSB is placed on MOSI.
4. SCLK is generated.
5. One bit is transmitted per SPI bit period.
6. The final bit completes the transaction.
7. `CS` returns high.
8. `done` is asserted.

The current implementation transmits MSB first.

---

# 13. SPI Slave

File:

```text
rtl/spi_slave.v
```

The SPI slave receives the serialized MOSI stream.

For every active SCLK edge, the incoming bit is shifted into a 16-bit shift register.

After 16 received bits:

```text
rx_data
```

is updated and:

```text
rx_valid
```

is asserted.

The slave therefore reconstructs the same 16-bit sample transmitted by the SPI master.

---

# 14. SPI Loopback

The current hardware architecture connects the SPI master directly to the SPI slave inside the FPGA.

```text
SPI Master MOSI
      |
      v
SPI Slave MOSI input
```

The SCLK and CS signals are also internally connected.

Therefore:

```text
DDS sample
    |
    v
FIFO
    |
    v
SPI Master
    |
    v
SPI Slave
    |
    v
Recovered 16-bit sample
```

This is an internal FPGA loopback.

It verifies the digital SPI transmission/reception path but does not verify an external SPI cable, external ADC/DAC, or external SPI peripheral.

---

# 15. Top-Level Integration

## 15.1 `uart_fifo_dds_core.v`

This module integrates:

```text
clock_divider
dds_top
dds_capture
asynch_fifo
spi_controller
spi_master
spi_slave
```

It exposes internal status and SPI signals for verification.

## 15.2 `top_wrapper.v`

The physical FPGA top level exposes only the required board pins:

```text
clk
reset
spi_mosi
spi_sclk
spi_cs
led[3:0]
```

This wrapper prevents internal signals from becoming unconstrained physical FPGA ports.

---

# 16. FPGA Board

Target platform:

```text
EDGE ZYNQ-7020 development board
Xilinx Zynq-7000
```

The design uses the programmable-logic clock and GPIO/SPI-related pins defined in:

```text
constraints/edge_zynq_7020_dds_spi.xdc
```

---

# 17. Hardware Pin Mapping

## Clock

```text
Signal : clk
Pin    : U18
I/O    : LVCMOS33
Frequency: 50 MHz
```

## Reset

```text
Signal : reset
Pin    : P15
I/O    : LVCMOS33
```

The reset is active high.

## SPI

```text
spi_mosi : J20
spi_sclk : H20
spi_cs   : G19
```

## LEDs

```text
led[0] : R16
led[1] : R17
led[2] : T17
led[3] : R18
```

The LEDs provide status indication.

They are not the primary waveform measurement mechanism.

---

# 18. Simulation Verification Strategy

The project was verified incrementally rather than relying only on the final integrated simulation.

Verification stages:

```text
1. Async FIFO standalone
2. DDS standalone
3. DDS capture
4. DDS -> capture -> FIFO
5. SPI master/slave loopback
6. Full DDS -> FIFO -> SPI loopback
7. FPGA implementation
8. Hardware ILA capture
```

This staged approach isolates failures at the block level before integration.

---

# 19. FIFO Standalone Verification

The FIFO testbench verified:

- Reset behavior
- Empty flag
- Full flag
- Write protection when full
- Read sequence
- Empty condition after all reads
- Correct ordering of data

Result:

```text
========== FIFO TEST PASSED ==========
```

---

# 20. DDS Verification

The DDS testbench verified that:

- Phase samples are generated.
- DDS valid output occurs.
- Digital waveform samples are produced.
- The output waveform has the expected sinusoidal behavior.

The selected phase increment was:

```text
1311
```

The expected output is approximately 1 MHz from the 50 MHz clock configuration.

The observed hardware frequency was:

```text
1.000977 MHz
```

---

# 21. DDS -> FIFO Verification

The integrated producer-side simulation verified:

```text
DDS
  ->
dds_capture
  ->
asynchronous FIFO
```

Measured simulation result:

```text
FIFO WRITES ACCEPTED = 51
FIFO READS CHECKED   = 35
ERRORS               = 0
```

Result:

```text
==============================================
 DDS -> CAPTURE -> FIFO TEST PASSED
==============================================
```

---

# 22. SPI Verification

The SPI master/slave loopback was independently verified using multiple test patterns, including:

```text
A5
3C
81
00
FF
AA
55
```

The loopback verified that the transmitted and received data matched.

The final system uses 16-bit samples.

---

# 23. Full Integrated Simulation

The complete simulation verifies:

```text
DDS
 ->
capture
 ->
async FIFO
 ->
SPI controller
 ->
SPI master
 ->
SPI slave
```

The final self-checking testbench records accepted FIFO writes and compares received SPI samples against the expected sequence.

Simulation result:

```text
FIFO SAMPLES ACCEPTED = 46
SPI SAMPLES RECEIVED  = 29
TOTAL ERRORS          = 0

FULL LOOPBACK TEST PASSED
```

The number of received samples is lower than the number of produced samples because the DDS producer operates substantially faster than the SPI consumer.

This causes samples to accumulate in the FIFO.

This is expected behavior and is not a functional error.

---

# 24. Throughput Relationship

The current configuration intentionally has:

```text
DDS/sample producer ≈ 1 MSample/s
```

while the SPI link operates at approximately:

```text
SPI SCLK ≈ 1.0417 MHz
```

A 16-bit SPI transaction requires multiple SPI clock cycles.

Therefore the effective sample-transfer rate of the SPI consumer is lower than the DDS production rate.

Consequently:

```text
Producer rate > Consumer rate
```

and the FIFO can accumulate samples.

This explains why the simulation and hardware captures can contain more generated samples than completed SPI transfers.

The FIFO is therefore functioning as a rate-matching buffer between the two domains.

---

# 25. Hardware Implementation

The complete design was synthesized, implemented, and converted into a bitstream for the Zynq-7020 FPGA.

The implementation was successfully programmed through the board's JTAG interface.

Two implementation configurations were used during development:

1. Normal bitstream without ILA.
2. Debug bitstream containing a Vivado ILA core.

The final verification uses the ILA-enabled implementation.

---

# 26. Vivado ILA Debugging

The ILA was added to observe internal signals without changing the functional RTL architecture.

The ILA configuration uses:

```text
Sample depth = 4096
ILA clock    = 50 MHz
```

The debug clock is the system clock.

Important observed signals include:

```text
FIFO data
FIFO read enable
SPI data
SPI start
SPI busy
SPI done
SPI CS
SPI SCLK
SPI MOSI
FIFO input data
FIFO write enable
```

The FIFO input data and FIFO write-enable signals are particularly important because they allow the actual DDS waveform entering the FIFO to be observed directly.

---

# 27. ILA Probe Configuration

The producer-side signals include:

```text
probe8 : fifo_din[15:0]
probe9 : fifo_wr_en
```

The FIFO input bus is displayed by Vivado as split signal fragments in the waveform viewer in some captures.

The complete 16-bit sample must therefore be reconstructed from:

```text
fifo_din[15:10]
fifo_din[9:1]
fifo_din[0]
```

The hardware CSV export contains these signal fragments.

---

# 28. Hardware Waveform Reconstruction

The final hardware ILA capture contained:

```text
4096 samples
```

at a 50 MHz ILA sampling clock.

The complete 16-bit unsigned sample was reconstructed as:

```text
u16 =
    (upper_6_bits << 10)
    |
    (middle_9_bits << 1)
    |
    lower_1_bit
```

The resulting 16-bit two's-complement value was then interpreted as a signed waveform.

Conceptually:

```text
16-bit unsigned sample
          |
          v
two's-complement conversion
          |
          v
signed sine amplitude
```

This reconstruction produced a clear sinusoidal waveform.

---

# 29. Final Hardware Measurement

The exported ILA capture was analyzed offline.

Measured results:

```text
ILA samples       : 4096
ILA clock         : 50 MHz
Sample interval   : 20 ns

Minimum sample    : -32766
Maximum sample    : 32558

Peak magnitude    : approximately 32766

Dominant frequency:
                   1.000977 MHz
```

The hardware capture therefore demonstrates an approximately 1 MHz digital sine waveform generated by the FPGA.

---

# 30. Hardware Evidence

The repository contains hardware evidence under:

```text
hardware_results/
```

Important files include:

```text
Board.jpeg
ILA_SIGNELS.png
Implementation.png
Sine_wave_2.png
dds_hardware_ila.png
dds_hardware_waveform.png
final_dds_hardware_capture.csv
ila_dds_waveform.png
ila_spi_waveform.png
schematic.png
zynq7020_final_dds_hardware_waveform.png
```

These files provide visual and numerical evidence for the FPGA implementation and hardware capture.

The CSV file is the exported ILA capture used for waveform reconstruction and frequency analysis.

---

# 31. Repository Structure

```text
HIGH-SPEEED-SINE-WAVE-STREAMING-WITH-FPGA/
│
├── README.md
├── README_FLOW.md
├── .gitignore
│
├── constraints/
│   └── edge_zynq_7020_dds_spi.xdc
│
├── docs/
│   ├── ila_probe_configuration.txt
│   └── verification.md
│
├── hardware_results/
│   ├── Board.jpeg
│   ├── ILA_SIGNELS.png
│   ├── Implementation.png
│   ├── Sine_wave_2.png
│   ├── dds_hardware_ila.png
│   ├── dds_hardware_waveform.png
│   ├── final_dds_hardware_capture.csv
│   ├── ila_dds_waveform.png
│   ├── ila_spi_waveform.png
│   ├── schematic.png
│   └── zynq7020_final_dds_hardware_waveform.png
│
├── rtl/
│   ├── asynch_fifo.v
│   ├── clock_divider.v
│   ├── dds_capture.v
│   ├── dds_top.v
│   ├── spi_controller.v
│   ├── spi_master.v
│   ├── spi_slave.v
│   ├── top_wrapper.v
│   └── uart_fifo_dds_core.v
│
└── tb/
    ├── asynch_fifo_tb.v
    └── uart_fifo_dds_loopback_tb.v
```

Vivado-generated directories and products are intentionally excluded using `.gitignore`.

---

# 32. Reproducing the Project

## Required tools

The project requires:

```text
Xilinx Vivado
Zynq-7000 device support
EDGE ZYNQ-7020 development board
```

The RTL is written in Verilog.

The DDS Compiler IP must be generated using Vivado because it is a Vivado IP dependency.

## Recommended flow

### Step 1

Create a new Vivado project targeting the appropriate Zynq-7000 device used by the board.

### Step 2

Add the RTL files from:

```text
rtl/
```

### Step 3

Add the testbenches from:

```text
tb/
```

### Step 4

Add:

```text
constraints/edge_zynq_7020_dds_spi.xdc
```

### Step 5

Generate the required DDS Compiler IP with the interface expected by `dds_top.v`.

The required interface is:

```text
aclk
s_axis_phase_tvalid
s_axis_phase_tdata
m_axis_data_tvalid
m_axis_data_tdata
```

### Step 6

Set:

```text
top_wrapper
```

as the synthesis/implementation top module.

### Step 7

Run RTL simulation using the provided testbenches.

### Step 8

Run synthesis.

### Step 9

Run implementation.

### Step 10

Generate the bitstream.

### Step 11

Program the Zynq-7020 through JTAG.

### Step 12

For internal debugging, add a Vivado ILA and connect the required signals documented in:

```text
docs/ila_probe_configuration.txt
```

---

# 33. Verification Matrix

| Block | Verification Method | Result |
|---|---|---|
| DDS | RTL simulation + hardware ILA | PASS |
| DDS Capture | RTL simulation | PASS |
| Async FIFO | Standalone simulation | PASS |
| DDS -> FIFO | Integrated simulation | PASS |
| SPI Master/Slave | Loopback simulation | PASS |
| Full system | Self-checking simulation | PASS |
| FPGA synthesis | Vivado | PASS |
| FPGA implementation | Vivado | PASS |
| Bitstream generation | Vivado | PASS |
| FPGA programming | JTAG | PASS |
| ILA debug | Hardware | PASS |
| Hardware sine reconstruction | 4096-sample ILA CSV | PASS |

---

# 34. Important Design Decisions

## Why an asynchronous FIFO?

The DDS/sample producer and SPI consumer operate at different clock rates.

The asynchronous FIFO:

- Provides clock-domain crossing.
- Buffers samples.
- Decouples producer and consumer timing.
- Prevents direct unsafe transfer of multi-bit data between unrelated clock domains.

## Why Gray-coded pointers?

Gray coding limits pointer transitions to one bit at a time, making pointer synchronization across clock domains safer.

## Why two-flop synchronizers?

The synchronized pointer signals cross clock domains and use two flip-flop stages to reduce metastability propagation risk.

## Why register FIFO output?

The FIFO implementation provides registered read data. Therefore the SPI controller explicitly waits for the FIFO read latency before capturing `fifo_dout`.

## Why use ILA?

LEDs cannot display a high-frequency digital sine waveform or individual 16-bit samples.

ILA allows internal FPGA signals to be captured at system-clock resolution and exported for offline analysis.

---

# 35. Known Limitations

1. The current SPI interface is an internal FPGA loopback.
2. No external DAC is used in the current implementation.
3. The current design therefore produces a digital sine waveform, not an analog sine-wave output.
4. The SPI consumer is slower than the DDS producer in the current configuration.
5. Therefore the FIFO can accumulate samples.
6. The DDS Compiler IP must be regenerated in a compatible Vivado environment.
7. Vivado-generated IP/project output products are not stored in the repository.
8. The current hardware demonstration relies on ILA for waveform observation.
9. The current project does not include an external SPI receiver.
10. The current implementation does not include an external DAC interface.

These limitations are intentional and define the current scope of the project.

---

# 36. Possible Future Improvements

Potential extensions include:

- External SPI receiver connection.
- Higher SPI clock frequency.
- Larger asynchronous FIFO depth.
- FIFO overflow/underflow monitoring.
- Programmable DDS frequency control.
- AXI4-Lite control interface for runtime frequency configuration.
- External DAC interface.
- Real-time analog waveform observation.
- DMA-based sample streaming.
- Continuous high-throughput waveform transmission.
- Hardware performance counters.
- Additional ILA trigger conditions.
- Parameterized sample width and FIFO depth.
- Support for multiple waveform types.
- Runtime waveform selection.

---

# 37. Engineering Takeaways

This project demonstrates practical FPGA design concepts including:

- FPGA-based digital signal generation
- DDS architecture
- Phase accumulation
- Valid/ready-style streaming concepts
- Clock-domain crossing
- Asynchronous FIFO design
- Binary-to-Gray pointer conversion
- Two-flop synchronization
- FIFO full/empty detection
- RTL finite-state-machine design
- SPI master design
- SPI slave design
- Serial-to-parallel conversion
- FPGA timing constraints
- Vivado synthesis and implementation
- Bitstream generation
- JTAG hardware programming
- Vivado ILA debugging
- Hardware waveform capture
- CSV-based hardware data analysis
- Digital two's-complement waveform reconstruction

---

# 38. Final Result

The completed system successfully demonstrates:

```text
Digital sine generation
        |
        v
Sample capture
        |
        v
Asynchronous clock-domain crossing
        |
        v
FIFO buffering
        |
        v
16-bit SPI serialization
        |
        v
SPI loopback
        |
        v
16-bit sample reconstruction
        |
        v
Hardware ILA observation
        |
        v
Offline waveform reconstruction
```

The final hardware ILA capture produced a clear sinusoidal waveform with:

```text
Measured frequency : 1.000977 MHz
Minimum amplitude  : -32766
Maximum amplitude  : 32558
ILA capture depth  : 4096 samples
```

The project therefore demonstrates an end-to-end FPGA digital signal-generation and streaming pipeline from waveform generation through hardware-observed sample reconstruction.

---

# 39. Project Status

```text
RTL Design              : COMPLETE
Block Verification      : COMPLETE
Integration Verification: COMPLETE
Simulation              : PASS
Synthesis               : PASS
Implementation          : PASS
Bitstream Generation    : PASS
Zynq-7020 Programming   : PASS
ILA Hardware Debug      : PASS
Hardware Waveform       : VERIFIED
GitHub Packaging        : COMPLETE
```

