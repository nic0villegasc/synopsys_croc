## -----------------------------------------------------------------------
## ZedBoard (xc7z020clg484-1) constraints for croc_zedboard_top
##
## Pin numbers taken from Digilent's official Zedboard-Master.xdc
## (github.com/Digilent/digilent-xdc). Double check against your board
## revision before bring-up.
##
## Bank IOSTANDARDs on the ZedBoard (fixed by the board's supply rails):
##   Bank 13 (Pmod JA/JB/JC, GCLK) -> LVCMOS33
##   Bank 33 (LEDs)                -> LVCMOS33
##   Bank 34 (push buttons)        -> LVCMOS18
##   Bank 35 (slide switches)      -> LVCMOS18
## -----------------------------------------------------------------------

## ------------------------------------------------------------------
## Clock (100 MHz onboard oscillator -> MMCM -> 20 MHz croc clk_i)
## ------------------------------------------------------------------
set_property PACKAGE_PIN Y9   [get_ports clk_100mhz_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz_i]
create_clock -period 10.000 -name clk_100mhz [get_ports clk_100mhz_i]

## JTAG TCK is a second, fully asynchronous clock domain (external debug
## probe). dmi_jtag/dmi_cdc handle the CDC in RTL -- these are legitimate
## exception paths, not masking a real timing bug.
create_clock -period 100.000 -name jtag_tck [get_ports jtag_tck_i]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks clk_100mhz] -group [get_clocks jtag_tck]

## ------------------------------------------------------------------
## Reset -- center pushbutton (active-high on ZedBoard)
## ------------------------------------------------------------------
set_property PACKAGE_PIN P16 [get_ports btnc_i]
set_property IOSTANDARD LVCMOS18 [get_ports btnc_i]

## ------------------------------------------------------------------
## JTAG -> Pmod JA (bank 13)
## ------------------------------------------------------------------
set_property PACKAGE_PIN Y11  [get_ports jtag_tck_i]
set_property PACKAGE_PIN AA11 [get_ports jtag_tms_i]
set_property PACKAGE_PIN Y10  [get_ports jtag_tdi_i]
set_property PACKAGE_PIN AA9  [get_ports jtag_tdo_o]
set_property PACKAGE_PIN AB11 [get_ports jtag_trst_ni]
set_property IOSTANDARD LVCMOS33 [get_ports {jtag_tck_i jtag_tms_i jtag_tdi_i jtag_tdo_o jtag_trst_ni}]

## Keep the debug module out of permanent reset / TAP out of an undefined
## state when no JTAG probe is plugged into JA.
set_property PULLUP true [get_ports jtag_trst_ni]
set_property PULLUP true [get_ports jtag_tms_i]
set_property PULLUP true [get_ports jtag_tdi_i]

## ------------------------------------------------------------------
## UART -> Pmod JB (bank 13)
## ------------------------------------------------------------------
set_property PACKAGE_PIN W12 [get_ports uart_tx_o]
set_property PACKAGE_PIN W11 [get_ports uart_rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx_o uart_rx_i}]

## ------------------------------------------------------------------
## QSPI -> Pmod JC (bank 13)
## ------------------------------------------------------------------
set_property PACKAGE_PIN AB7 [get_ports qspi_clk_o]
set_property PACKAGE_PIN AB6 [get_ports {qspi_csn_o[0]}]
set_property PACKAGE_PIN Y4  [get_ports {qspi_csn_o[1]}]
set_property PACKAGE_PIN AA4 [get_ports {qspi_csn_o[2]}]
set_property PACKAGE_PIN R6  [get_ports {qspi_sd_io[0]}]
set_property PACKAGE_PIN T6  [get_ports {qspi_sd_io[1]}]
set_property PACKAGE_PIN T4  [get_ports {qspi_sd_io[2]}]
set_property PACKAGE_PIN U4  [get_ports {qspi_sd_io[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {qspi_clk_o qspi_csn_o[*] qspi_sd_io[*]}]

## ------------------------------------------------------------------
## GPIO -> switches (bank 35, inputs) and LEDs (bank 33, outputs)
## ------------------------------------------------------------------
set_property PACKAGE_PIN F22 [get_ports {sw_io[0]}]
set_property PACKAGE_PIN G22 [get_ports {sw_io[1]}]
set_property PACKAGE_PIN H22 [get_ports {sw_io[2]}]
set_property PACKAGE_PIN F21 [get_ports {sw_io[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw_io[*]}]

set_property PACKAGE_PIN T22 [get_ports {led_io[0]}]
set_property PACKAGE_PIN T21 [get_ports {led_io[1]}]
set_property PACKAGE_PIN U14 [get_ports {led_io[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_io[*]}]

set_property PACKAGE_PIN U22 [get_ports led2_o]
set_property IOSTANDARD LVCMOS33 [get_ports led2_o]

## ------------------------------------------------------------------
## Config / bitstream options (safe defaults for the ZedBoard's SPI flash)
## ------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
