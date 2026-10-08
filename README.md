High-Speed FPGA Sine-Wave Streaming System
DDS → Asynchronous FIFO → SPI | Zynq-7020 | Verilog RTL | Vivado
A complete FPGA RTL design for digital sine-wave generation, multi-clock buffering, and serial streaming using a Xilinx Zynq-7020 FPGA.
The system generates 16-bit digital sine-wave samples using the Xilinx DDS Compiler IP, captures the generated samples into an asynchronous FIFO, and transfers the samples through a 16-bit SPI Master/Slave loopback interface. The design was verified through standalone RTL simulation, integrated simulation, FPGA implementation, and on-chip ILA hardware capture.
1. Project Overview
The project demonstrates an end-to-end digital data-streaming architecture containing:
- 16-bit DDS waveform generation
- Registered DDS sample capture
- 16-bit × 16-entry asynchronous FIFO
- Independent write/read clock domains
- Gray-code FIFO pointer synchronization
- Two-flop CDC synchronizers
- FSM-based FIFO-to-SPI controller
- 16-bit SPI Master
- 16-bit SPI Slave
- Internal SPI loopback
- Vivado simulation and self-checking testbenches
- Vivado synthesis and implementation
- Integrated Logic Analyzer (ILA) hardware debugging
- Hardware reconstruction of the generated sine waveform
High-level data path
                 50 MHz System Clock
                         │
                         ▼
                ┌─────────────────┐
                │  DDS Compiler   │
                │   16-bit DDS    │
                └────────┬────────┘
                         │
                  sine + valid
                         │
                         ▼
                ┌─────────────────┐
                │  DDS Capture    │
                │  Registered     │
                │  Sample Capture │
                └────────┬────────┘
                         │
                    FIFO Write
                         │
                         ▼
          ┌────────────────────────────┐
          │     Asynchronous FIFO      │
          │                            │
          │  16-bit × 16 entries      │
          │  Gray-code CDC             │
          │  Independent clocks        │
          └─────────────┬──────────────┘
                        │
                    FIFO Read
                        │
                        ▼
               ┌─────────────────┐
               │ SPI Controller  │
               │      FSM        │
               └────────┬────────┘
                        │
                   16-bit sample
                        │
                        ▼
               ┌─────────────────┐
               │   SPI Master    │
               └────────┬────────┘
                        │
                  MOSI / SCLK / CS
                        │
                        ▼
               ┌─────────────────┐
               │    SPI Slave    │
               └────────┬────────┘
                        │
                    16-bit RX
                        │
                        ▼
                 Received Sample

2. Project Objectives
The design was developed to demonstrate the following RTL and FPGA concepts in one complete system:
1. Generate programmable digital sine-wave samples.
2. Interface a vendor-provided DDS IP with custom Verilog RTL.
3. Transfer data between independent clock domains.
4. Implement an asynchronous FIFO using Gray-coded pointers.
5. Synchronize CDC status information using two-flop synchronizers.
6. Control FIFO reads using an FSM.
7. Serialize 16-bit samples through SPI.
8. Reconstruct the transmitted sample in an SPI receiver.
9. Verify the complete pipeline using simulation.
10. Verify the design directly on a physical Zynq-7020 FPGA using ILA.
11. Export hardware-captured samples and reconstruct the sine waveform offline.
3. Target Hardware
FPGA Board
EDGE ZYNQ-7020 development board
Target FPGA:
Xilinx Zynq-7000
XC7Z020-1CLG400C

The design uses the Programmable Logic (PL) portion of the Zynq device.
4. Clock Architecture
The design intentionally contains multiple clock domains.
4.1 System / DDS / FIFO Write Clock
Clock source : Board PL clock
Frequency    : 50 MHz
Period       : 20 ns

This clock drives:
- DDS wrapper
- DDS phase accumulator interface
- DDS capture logic
- FIFO write-side logic
The XDC constraint is:
create_clock -add \
    -name sys_clk_pin \
    -period 20.00 \
    -waveform {0 10} \
    [get_ports { clk }]

4.2 FIFO Read / SPI Controller Clock
The read clock is generated using:
clock_divider #(.HALF_PERIOD(6))

From the 50 MHz system clock:
Fsys = 50 MHz

The divider toggles after six system-clock cycles.
Therefore the generated read clock is approximately:
Fread ≈ 4.1667 MHz

This clock drives:
- FIFO read side
- SPI controller
- SPI master
4.3 SPI Clock
The SPI Master uses:
CLK_DIV = 2

with the approximately 4.1667 MHz read-domain clock.
The resulting SPI clock is approximately:
SPI SCLK ≈ 1.0417 MHz

The SPI transfer therefore operates significantly slower than the DDS producer.
This is intentional in the current demonstration and also demonstrates why buffering is required.
5. DDS Waveform Generation
The project uses the Xilinx DDS Compiler IP.
The custom RTL wrapper is:
rtl/dds_top.v

The DDS interface contains:
.aclk
.s_axis_phase_tvalid
.s_axis_phase_tdata
.m_axis_data_tvalid
.m_axis_data_tdata

The phase accumulator is driven using:
parameter [15:0] PHASE_INC = 16'd1311

Therefore:
Phase increment = 1311
Phase width     = 16 bits
Clock           = 50 MHz

The ideal DDS relationship is:
\[
f_{out} = \frac{FCW}{2^N}f_{clk}
\]
where:
- \(FCW\) = frequency control word
- \(N\) = phase accumulator width
- \(f_{clk}\) = DDS input clock
For this implementation, the generated waveform is approximately:
1 MHz sine wave

The actual hardware capture later measured:
≈ 1.000977 MHz

6. DDS Capture Logic
File:
rtl/dds_capture.v

The capture block receives:
sine
sine_valid

and produces:
fifo_din
fifo_wr_en

The capture logic registers the DDS sample when sine_valid is asserted.
Conceptually:
DDS sample
    │
    │ sine_valid
    ▼
DDS Capture Register
    │
    ├── fifo_din
    └── fifo_wr_en

This provides a clean interface between the DDS output and FIFO write logic.
7. Asynchronous FIFO
File:
rtl/asynch_fifo.v

Configuration:
Data width : 16 bits
Depth      : 16 entries

Therefore the FIFO stores:
\[
16 \times 16 = 256\text{ bits}
\]
of sample data.
7.1 Why an Asynchronous FIFO?
The producer and consumer operate in different clock domains:
Write domain:
50 MHz

        ↓

     FIFO

        ↓

Read domain:
≈4.1667 MHz

Directly transferring multi-bit data between unrelated clocks would create CDC problems.
The asynchronous FIFO isolates the two clock domains.
8. FIFO Pointer Architecture
The FIFO uses:
- Binary write pointer
- Binary read pointer
- Gray-coded write pointer
- Gray-coded read pointer
- Two-stage synchronizers
The pointer width is:
PTR_WIDTH = 5

for a depth of 16.
The additional pointer bit allows full/empty distinction.
8.1 Binary → Gray Conversion
The standard Gray-code relationship is:
\[
Gray = Binary \oplus (Binary >> 1)
\]
Gray-coded pointers are transferred between clock domains because only one bit changes between adjacent pointer values.
8.2 CDC Synchronization
The synchronized pointer passes through two flip-flops in the receiving clock domain.
Conceptually:
Write pointer
     │
     ▼
Binary → Gray
     │
     ▼
Synchronizer FF1
     │
     ▼
Synchronizer FF2
     │
     ▼
Read-domain logic

and equivalently for the read pointer.
This prevents asynchronous pointer signals from being used directly by the opposite clock domain.
9. FIFO Full and Empty Detection
Empty
The FIFO is empty when:
rd_ptr_gray == wr_gray_sync2

meaning the read pointer has caught up with the synchronized write pointer.
Full
The FIFO full condition compares the write pointer against the synchronized read pointer with the appropriate inverted upper Gray-pointer bits.
This allows the FIFO to distinguish:
EMPTY

from:
FULL

even though the lower address bits may be equal.
10. FIFO Verification
The asynchronous FIFO was first verified independently before integration.
The standalone testbench verified:
- Reset behavior
- Empty detection
- 16 successful writes
- Full detection
- Blocking of the 17th write
- 16 successful reads
- Correct data ordering
- Return to empty state
The testbench produced:
[PASS] FIFO EMPTY after reset
[PASS] FIFO FULL after 16 writes
[PASS] 17th write blocked
[PASS] READ 000a
...
[PASS] READ 00a0
[PASS] FIFO EMPTY after 16 reads

========== FIFO TEST PASSED ==========

This established the FIFO independently before connecting it to the DDS and SPI system.
11. SPI Architecture
The SPI subsystem consists of three RTL blocks:
spi_controller.v
spi_master.v
spi_slave.v

12. SPI Controller
File:
rtl/spi_controller.v

The controller coordinates:
FIFO
 ↓
FIFO read
 ↓
sample capture
 ↓
SPI start
 ↓
SPI transfer
 ↓
SPI completion

The FSM contains the following states:
IDLE
FIFO_READ
WAIT_FIFO
CAPTURE
START_SPI
WAIT_SPI

12.1 Why WAIT_FIFO Exists
The FIFO output is registered.
Therefore, asserting:
fifo_rd_en

does not mean that the new FIFO sample is immediately available on fifo_dout in the same controller state.
The controller therefore explicitly waits before capturing the returned sample.
This is an important timing detail in the architecture.
13. SPI Master
File:
rtl/spi_master.v

The SPI master accepts:
start
data_in[15:0]

and generates:
mosi
sclk
cs
busy
done

The transfer is:
16 bits
MSB first

The master contains:
- 16-bit shift register
- 5-bit bit counter
- clock divider
- chip-select control
- busy state
- transfer completion indication
14. SPI Slave
File:
rtl/spi_slave.v

The slave receives:
MOSI
SCLK
CS

and reconstructs the transmitted 16-bit sample.
The receive shift operation is:
shift_reg <= {shift_reg[14:0], mosi};

After 16 received bits:
rx_data

is updated and:
rx_valid

is asserted.
15. SPI Loopback
The current hardware design uses an internal SPI loopback:
SPI Master
    │
    │ MOSI
    ▼
SPI Slave

The SPI slave is instantiated inside the same FPGA design.
Therefore this project demonstrates:
- SPI serialization
- SPI clock generation
- chip select
- bit counting
- data reconstruction
- end-to-end digital sample integrity
Important scope
This is an internal FPGA loopback, not an external SPI peripheral demonstration.
The current implementation exposes the SPI signals at the top-level FPGA pins, but the verification path shown in the repository uses the internally instantiated slave.
16. Complete RTL Hierarchy
The project hierarchy is:
top_wrapper
│
└── uart_fifo_dds_core
    │
    ├── clock_divider
    │
    ├── dds_top
    │   └── dds_compiler_0
    │
    ├── dds_capture
    │
    ├── asynch_fifo
    │
    ├── spi_controller
    │
    ├── spi_master
    │
    └── spi_slave

17. RTL Module Reference
Module	Function
dds_top.v	DDS Compiler interface and phase-control logic
dds_capture.v	Registers valid DDS samples for FIFO input
asynch_fifo.v	16-bit × 16-entry asynchronous FIFO
clock_divider.v	Generates the FIFO-read/SPI clock
spi_controller.v	FSM controlling FIFO reads and SPI transfers
spi_master.v	Serializes 16-bit samples
spi_slave.v	Reconstructs 16-bit samples
uart_fifo_dds_core.v	Integrates all functional blocks
top_wrapper.v	Physical FPGA top-level interface


18. Simulation Verification Strategy
Verification was performed incrementally rather than debugging the complete design immediately.
Verification sequence
1. Async FIFO standalone
          ↓
2. DDS standalone
          ↓
3. DDS Capture
          ↓
4. DDS → Capture → FIFO
          ↓
5. SPI Master / Slave
          ↓
6. FIFO → SPI Controller
          ↓
7. Complete integration
          ↓
8. Synthesis
          ↓
9. Implementation
          ↓
10. Hardware + ILA

This block-level verification strategy isolates failures and simplifies debugging.
19. DDS Verification
The DDS was simulated independently.
The testbench verified:
- Reset behavior
- Phase progression
- DDS valid signal
- Output waveform
- Signed waveform behavior
- Expected frequency
The DDS configuration used:
Clock       = 50 MHz
Phase width = 16 bits
Phase inc   = 1311

The resulting output was approximately:
1 MHz

20. DDS → FIFO Verification
The integrated producer path:
DDS
 ↓
DDS Capture
 ↓
Async FIFO

was independently tested.
Measured simulation result:
FIFO WRITES ACCEPTED = 51
FIFO READS CHECKED   = 35
ERRORS               = 0

==============================================
 DDS -> CAPTURE -> FIFO TEST PASSED
==============================================

Example verified samples included:
8220
F0CF
7DE4
0F1B

with no detected data mismatch.
21. SPI Verification
The SPI subsystem was independently tested using loopback.
The verification covered representative 8-bit patterns during the earlier SPI block-level validation, including:
A5
3C
81
00
FF
AA
55

The final integrated architecture uses 16-bit SPI transfers.
22. Full System Simulation
The complete simulation uses a self-checking scoreboard.
The testbench:
- Records accepted FIFO writes
- Tracks transmitted samples
- Monitors SPI receive-valid events
- Compares received samples against expected samples
- Counts errors
- Runs the complete integrated design
Final integrated simulation result:
FIFO SAMPLES ACCEPTED = 46
SPI SAMPLES RECEIVED  = 29
TOTAL ERRORS          = 0

FULL LOOPBACK TEST PASSED

The difference between accepted and received samples is expected because the DDS producer is faster than the current SPI consumer.
At the end of the simulation:
46 samples accepted
29 samples transmitted/received
17 samples remained buffered

This is not a data-integrity failure.
It reflects the current throughput relationship:
DDS sample generation
        >
SPI sample consumption

23. Throughput Relationship
The current implementation uses approximately:
DDS sample rate    ≈ 1 MSample/s
FIFO read clock    ≈ 4.1667 MHz
SPI SCLK           ≈ 1.0417 MHz

A 16-bit SPI transfer requires 16 serial clock cycles.
Therefore the SPI consumer cannot drain the FIFO as quickly as the DDS produces samples.
The FIFO consequently provides temporary buffering between the two rates.
Conceptually:
Fast producer
     │
     ▼
┌───────────┐
│   FIFO    │
└───────────┘
     │
     ▼
Slower consumer

This is one of the main architectural reasons for including the asynchronous FIFO.
24. FPGA Implementation
The design was synthesized and implemented using:
Xilinx Vivado

The physical top-level interface was deliberately kept small to avoid unconstrained internal signals becoming FPGA package pins.
The physical top-level contains:
clk
reset
spi_mosi
spi_sclk
spi_cs
led[3:0]

Internal signals such as:
fifo_dout
fifo_din
spi_data
fifo_rd_en
spi_start
spi_busy
spi_done

remain internal to the FPGA design.
25. FPGA Pin Mapping
Clock
Signal : clk
Pin    : U18
I/O    : LVCMOS33
Freq   : 50 MHz

Reset
Signal : reset
Pin    : P15

Reset is connected to the board switch assigned to this pin.
SPI
Signal	FPGA Pin
spi_mosi	J20
spi_sclk	H20
spi_cs	G19


LEDs
LED	FPGA Pin	Function
led[0]	R16	FIFO Full
led[1]	R17	FIFO Empty
led[2]	T17	SPI RX Valid
led[3]	R18	SPI Chip Select active


The LEDs are intended as status indicators, not as the primary waveform demonstration.
26. ILA Hardware Debugging
The final hardware build contains one Vivado Integrated Logic Analyzer core:
u_ila_0

The ILA uses the 50 MHz system clock.
Final capture depth:
4096 samples

27. ILA Probe Configuration
The ILA monitors the important points in the streaming path.
The probes include:
FIFO output data
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

The producer-side probes were particularly important because observing only fifo_dout captures samples after FIFO read, while observing fifo_din allows direct observation of the DDS-generated samples entering the FIFO.
28. Why FIFO Input Was Added to the ILA
The final ILA configuration captures:
fifo_din
fifo_wr_en

This gives direct visibility into:
DDS
 ↓
DDS Capture
 ↓
FIFO input

rather than relying only on the consumer-side FIFO output.
The final capture therefore provides evidence of the actual generated waveform entering the streaming pipeline.
29. Hardware Waveform Reconstruction
The ILA stores the 16-bit FIFO input across multiple displayed bus fragments.
The exported CSV contains the individual bus fragments.
The complete 16-bit sample is reconstructed as:
sample[15:10] = fifo_din_2[15:10]

sample[9:1]   = fifo_din[9:1]

sample[0]     = fifo_din_1[0]

Therefore:
sample[15:0] =
    {fifo_din_2[15:10],
     fifo_din[9:1],
     fifo_din_1[0]}

The resulting unsigned 16-bit sample is converted to signed two's-complement form for waveform analysis.
30. Hardware Measurement Result
Final hardware ILA capture:
Capture depth       : 4096 samples
ILA clock           : 50 MHz
Sample interval     : 20 ns

The reconstructed waveform produced:
Minimum sample      : -32766
Maximum sample      : +32558
Peak magnitude      : approximately 32766

FFT analysis of the captured hardware samples produced a dominant frequency of approximately:
1.000977 MHz

This is consistent with the intended approximately 1 MHz DDS configuration.
31. Hardware Evidence
The repository contains captured evidence under:
hardware_results/

including:
Board.jpeg
Implementation.png
schematic.png
ILA_SIGNELS.png
dds_hardware_ila.png
dds_hardware_waveform.png
ila_dds_waveform.png
ila_spi_waveform.png
Sine_wave_2.png
zynq7020_final_dds_hardware_waveform.png
final_dds_hardware_capture.csv

The CSV is the raw exported ILA capture used for hardware waveform reconstruction.
The waveform images provide visual evidence of the reconstructed sine-wave behavior.
32. Repository Structure
UART_FIFO_DDS/
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
├── tb/
│   ├── asynch_fifo_tb.v
│   └── uart_fifo_dds_loopback_tb.v
│
└── hardware_results/
    ├── Board.jpeg
    ├── ILA_SIGNELS.png
    ├── Implementation.png
    ├── Sine_wave_2.png
    ├── dds_hardware_ila.png
    ├── dds_hardware_waveform.png
    ├── final_dds_hardware_capture.csv
    ├── ila_dds_waveform.png
    ├── ila_spi_waveform.png
    ├── schematic.png
    └── zynq7020_final_dds_hardware_waveform.png

33. How to Reproduce the Design
Required tools
Xilinx Vivado
Verilog/SystemVerilog simulation support
Zynq-7020 development board
JTAG programming cable

The design also depends on the generated Xilinx DDS Compiler IP.
Step 1 — Create Vivado Project
Create a new Vivado RTL project targeting the appropriate Zynq-7020 device.
Add:
rtl/*.v
tb/*.v
constraints/edge_zynq_7020_dds_spi.xdc

Step 2 — Generate DDS IP
Create the required:
DDS Compiler

IP with the interface expected by:
rtl/dds_top.v

The generated IP must provide:
aclk
s_axis_phase_tvalid
s_axis_phase_tdata
m_axis_data_tvalid
m_axis_data_tdata

The generated Vivado IP/project files are intentionally excluded from Git because they are tool-generated artifacts.
34. Simulation Flow
Start with:
tb/asynch_fifo_tb.v

and verify:
FIFO TEST PASSED

Then verify the complete system with:
tb/uart_fifo_dds_loopback_tb.v

Expected final integrated result:
TOTAL ERRORS = 0
FULL LOOPBACK TEST PASSED

35. Implementation Flow
After simulation:
Synthesis
   ↓
Implementation
   ↓
Timing analysis
   ↓
Generate Bitstream
   ↓
Program Zynq-7020

The provided XDC constrains the physical clock and external ports.
36. Hardware Debug Flow
For ILA-enabled debugging:
Create ILA
      ↓
Connect ILA clock
      ↓
Connect FIFO/DDS/SPI probes
      ↓
Synthesize
      ↓
Implement
      ↓
Generate bitstream + LTX
      ↓
Program FPGA
      ↓
Open Hardware Manager
      ↓
Run ILA capture
      ↓
Export CSV
      ↓
Reconstruct waveform

37. Important Design Decisions
Why DDS?
The DDS provides programmable digital waveform generation without requiring an analog DAC.
The output is a sequence of digital samples.
DDS
 ↓
Digital sine samples

The SPI subsystem transports those digital samples; it does not generate the sine wave.
Why FIFO?
The DDS producer and SPI consumer operate at different effective rates.
The FIFO decouples:
Producer timing

from:
Consumer timing

and provides temporary buffering.
Why asynchronous FIFO?
Because the FIFO write and read sides use different clock domains.
The asynchronous FIFO provides proper CDC handling instead of directly sampling multi-bit data across unrelated clocks.
Why Gray code?
Gray-coded pointers reduce the number of simultaneously changing bits crossing the clock-domain boundary.
Combined with two-stage synchronizers, this provides the CDC mechanism used by the FIFO status logic.
Why ILA?
Simulation verifies the RTL model.
ILA verifies that the synthesized/implemented hardware actually exhibits the expected behavior on the FPGA.
This gives three distinct levels of evidence:
RTL simulation
      ↓
FPGA implementation
      ↓
Actual hardware capture

38. Known Limitations
1. Current SPI receiver is internal loopback
The current demonstrated receive path is:
FPGA SPI Master
      ↓
FPGA SPI Slave

An external SPI peripheral has not been used for the final demonstration.
2. SPI consumer is slower than the DDS producer
The current configuration generates samples faster than the SPI interface can transmit them.
Therefore the FIFO can accumulate samples.
This is expected behavior.
3. DDS Compiler IP is vendor-generated
The repository contains the RTL wrapper but excludes Vivado-generated IP/project artifacts through .gitignore.
The DDS IP must therefore be regenerated when rebuilding the project in a fresh Vivado environment.
4. No analog DAC is used
The output waveform demonstrated in this repository is a digital reconstructed waveform from ILA samples.
It is not an analog sine wave measured directly using an oscilloscope.
39. Possible Future Improvements
Future versions could include:
- External SPI receiver
- MISO support
- Configurable SPI clock
- Higher-throughput SPI
- FIFO depth parameterization
- Runtime DDS frequency control
- AXI4-Lite register interface
- PS-to-PL control through Zynq
- DMA-based sample streaming
- External DAC interface
- Real-time waveform output to an analog instrument
- FIFO occupancy monitoring
- ILA-triggered automated capture
- Hardware frequency sweep
- Multiple waveform modes
40. Key Engineering Concepts Demonstrated
This project covers a complete set of practical FPGA RTL concepts:
Digital waveform generation
        │
        ▼
Vendor IP integration
        │
        ▼
Synchronous RTL
        │
        ▼
Registered data capture
        │
        ▼
Clock-domain crossing
        │
        ▼
Gray-code asynchronous FIFO
        │
        ▼
FSM-based control
        │
        ▼
Serial protocol implementation
        │
        ▼
Self-checking simulation
        │
        ▼
FPGA synthesis
        │
        ▼
FPGA implementation
        │
        ▼
On-chip hardware debugging
        │
        ▼
Hardware data extraction
        │
        ▼
Numerical waveform reconstruction

41. Final Results
Parameter	Result
FPGA	Zynq-7020
System clock	50 MHz
DDS phase width	16 bits
DDS phase increment	1311
Target waveform	~1 MHz sine
FIFO width	16 bits
FIFO depth	16 entries
FIFO architecture	Asynchronous
CDC	Gray-code + 2FF synchronizers
Read clock	≈4.1667 MHz
SPI width	16 bits
SPI clock	≈1.0417 MHz
Simulation errors	0
Full loopback simulation	PASS
ILA depth	4096 samples
Hardware frequency	≈1.000977 MHz
Hardware sample minimum	-32766
Hardware sample maximum	+32558


42. Conclusion
This project implements and validates a complete FPGA digital streaming chain:
DDS
 ↓
Sample Capture
 ↓
Asynchronous FIFO
 ↓
FSM Controller
 ↓
SPI Master
 ↓
SPI Slave
 ↓
Received Sample

The design was not only simulated but also synthesized, implemented, programmed onto a Zynq-7020 FPGA, and debugged using Vivado ILA.
The final hardware capture was exported and numerically reconstructed to demonstrate the expected approximately 1 MHz digital sine-wave behavior.
The repository therefore contains the RTL, testbenches, constraints, verification documentation, ILA configuration, raw hardware capture, and hardware evidence required to understand and reproduce the implementation.
