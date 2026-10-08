# ================================================================
# EDGE ZYNQ-7020
# DDS -> ASYNC FIFO -> SPI
# Hardware Top-Level Constraints
# ================================================================

# ================================================================
# 50 MHz PL CLOCK
# Board PL clock: 50 MHz
# Zynq PL pin: U18
# ================================================================

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { clk }]

create_clock -add \
    -name sys_clk_pin \
    -period 20.00 \
    -waveform {0 10} \
    [get_ports { clk }]


# ================================================================
# RESET
# SW8
# Zynq PL pin: P15
# ================================================================

set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { reset }]


# ================================================================
# SPI MOSI
#
# J13 Expansion Connector
# J13 Pin 5 -> J20
# ================================================================

set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]


# ================================================================
# SPI SCLK
#
# J13 Expansion Connector
# J13 Pin 6 -> H20
# ================================================================

set_property -dict { PACKAGE_PIN H20 IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }]


# ================================================================
# SPI CHIP SELECT
#
# J13 Expansion Connector
# J13 Pin 7 -> G19
# ================================================================

set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS33 } [get_ports { spi_cs }]


# ================================================================
# STATUS LED 0
# D4
# Zynq PL pin: R16
#
# FIFO FULL
# ================================================================

set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]


# ================================================================
# STATUS LED 1
# D5
# Zynq PL pin: R17
#
# FIFO EMPTY
# ================================================================

set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]


# ================================================================
# STATUS LED 2
# D6
# Zynq PL pin: T17
#
# SPI RX VALID
# ================================================================

set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]


# ================================================================
# STATUS LED 3
# D7
# Zynq PL pin: R18
#
# SPI ACTIVE
# ================================================================

set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]
