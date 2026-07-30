################################################################################
# mode_func.tcl  --  functional-mode constraints for croc_soc
#
# Port list verified against croc_soc.sv.
# Clock domains verified against croc_domain.sv / user_domain.sv / obi_qspi.sv /
# qqspi.v and against check_timing.rpt (356/356 unclocked endpoints were in
# i_dmi_jtag; zero anywhere else).
#
# What changed vs. the original:
#   1. jtag_tck_i is now a real clock. This was the sole cause of all 356
#      'unclocked' endpoints, all 283 TCK-002 register clock pins with no fanin
#      clock, and the 10,914 TCK-001 warnings in the mapped netlist.
#   2. clk_i and jtag_tck_i declared asynchronous (the dmi_cdc 2-phase crossing
#      is NOT a synchronous path and must not be timed as one).
#   3. Ports are classified instead of blanket-swept with all_inputs/all_outputs.
#   4. testmode_i pinned to 0 by case analysis (functional mode).
#   5. Async/static straps get false paths instead of meaningless setup checks.
#   6. Drive + load models added -- without them the I/O delays were fiction.
#   7. Explicit max_transition / max_capacitance / max_fanout.
#
# Expects from the setup file: CLOCK_PORT_NAME, CLOCK_PERIOD
################################################################################

current_mode func

################################################################################
# 0. Parameters
################################################################################

#-------------------------------------------------------------------------------
# Main system clock.
#
# 10.0 ns (100 MHz) is NOT reachable on GF180MCU with this netlist. Measured
# floor from your own route database: data arrival 40.17 ns + 1.79 setup +
# uncertainty => ~43 ns (~23 MHz). Gate delays on the critical path run
# 0.4-1.2 ns per stage at the slow corner and the fetch->OBI->peripheral cone is
# ~60 levels deep.
#
# 50 ns (20 MHz) gives ~15% margin over that floor. Close it here first, then
# binary-search down (40 -> 30 -> 25) until post-route WNS goes negative. That
# number is your real Fmax.
#-------------------------------------------------------------------------------
if { ![info exists CLOCK_PORT_NAME] } { set CLOCK_PORT_NAME "clk_i" }
if { ![info exists CLOCK_PERIOD]    } { set CLOCK_PERIOD    50.0    }

#-------------------------------------------------------------------------------
# JTAG test clock. Driven off-chip by the debug probe; it never needs to be
# fast, and keeping it slow costs nothing.
#-------------------------------------------------------------------------------
set JTAG_TCK_PORT   "jtag_tck_i"
set JTAG_TCK_PERIOD 100.0                            ;# 10 MHz

#-------------------------------------------------------------------------------
# ref_clk_i: NOT a clock in this netlist.
#
# It is a port on croc_soc and is fanned out to croc_domain (i_core_wrap,
# i_timer) and user_domain (where it is declared and never used). But
# check_timing found ZERO unclocked registers outside i_dmi_jtag, which means
# ref_clk_i clocks nothing today -- it is either tied off inside those modules
# or synchronized into the clk_i domain as data.
#
# Treated below as an asynchronous DATA input into the clk_i domain. Verify with:
#     all_fanout -from [get_ports ref_clk_i] -flat -endpoints_only
# If it ever does clock registers, set REF_CLK_ACTIVE to 1.
#-------------------------------------------------------------------------------
set REF_CLK_PORT    "ref_clk_i"
set REF_CLK_PERIOD  30517.578                        ;# 32.768 kHz RTC
set REF_CLK_ACTIVE  0

#-------------------------------------------------------------------------------
# QSPI. See section 11. Leave at 0 unless you know what you are turning on.
#-------------------------------------------------------------------------------
set QSPI_SOURCE_SYNC 0

#-------------------------------------------------------------------------------
# Margins.
#
# Pre-CTS uncertainty must cover expected skew + jitter. Your last CTS run
# measured 3.02 ns of global skew at the slow corner -- the old fixed 1.0 ns was
# fiction. 5% of the period is a sane opening budget. Tune it to whatever
# report_clock_qor actually gives you, then shrink it after set_propagated_clock.
#-------------------------------------------------------------------------------
set SETUP_UNCERT     [expr {max(0.05 * $CLOCK_PERIOD, 0.5)}]
set HOLD_UNCERT      0.25
set CLOCK_IDEAL_TRAN 0.4        ;# ignored once propagated; kills pre-CTS optimism
set IO_DELAY_FRAC    0.20       ;# fraction of period reserved for off-chip delay

# Off-chip environment. croc_soc instantiates real GF180 IO pads, so these
# describe the board side of the pad, not a standard-cell driver.
set EXT_INPUT_TRAN   1.0        ;# ns, slew arriving at the pad
set EXT_LOAD         5.0        ;# pF, board/trace/probe load on outputs

# Design rule constraints.
set MAX_TRAN_DATA    1.5
set MAX_TRAN_CLK     0.5
set MAX_CAP          0.3
set MAX_FANOUT       20


################################################################################
# 1. Clocks
################################################################################

create_clock -name clock \
             -period $CLOCK_PERIOD \
             [get_ports $CLOCK_PORT_NAME]

# THE fix. Without this the entire TAP + DMI CDC (283 flops in i_dmi_jtag) has
# no clock: they are dropped from timing, dropped from CTS, and left to the
# router. Every 'unclocked' endpoint in check_timing.rpt lives here.
create_clock -name jtag_tck \
             -period $JTAG_TCK_PERIOD \
             [get_ports $JTAG_TCK_PORT]

if { $REF_CLK_ACTIVE } {
  create_clock -name ref_clk \
               -period $REF_CLK_PERIOD \
               [get_ports $REF_CLK_PORT]
}


################################################################################
# 2. QSPI generated clock -- OPTIONAL, off by default
#
# qqspi.v drives sclk from a register on posedge clk:
#     always @(posedge clk) sclk <= sclk_next;   // toggles every clk edge
# so qspi_clk_o is a divide-by-2 of clk_i. BUT it clocks nothing inside the
# chip -- every register in qqspi/obi_qspi is on clk_i, which is exactly why
# check_timing found no unclocked flops in i_obi_qspi.
#
# Declaring it a generated clock therefore:
#   - creates a clock with zero sinks (CTS-905), no tree to build, and
#   - invents a launch/capture edge relationship between `clock` and a
#     divide-by-2 that you then have to repair with a multicycle path.
#
# Meanwhile the thing that actually matters (does the PSRAM/flash see valid
# setup at its pins?) is a board-level check across two chip boundaries that
# internal STA cannot answer regardless.
#
# The default path (section 8) constrains every QSPI pin against `clock`, which
# is LITERALLY correct per the RTL: qspi_sd_i is captured by a clk_i flop
# (spi_buf <= ... sio_in), and qspi_sd_o / qspi_csn_o / qspi_clk_o are all
# launched by clk_i flops.
#
# Turn this on only if you specifically want source-synchronous analysis, and
# expect to tune the edges.
################################################################################

if { $QSPI_SOURCE_SYNC } {
  create_generated_clock -name qspi_clk \
    -source [get_ports $CLOCK_PORT_NAME] \
    -divide_by 2 \
    [get_ports qspi_clk_o]

  # Data is launched on the clk_i edge where sclk FALLS; the external device
  # captures on the sclk RISE one clk_i period later. Model the launch edge, and
  # expect to add a set_multicycle_path to get the capture edge right. VERIFY
  # with report_timing -to [get_ports qspi_sd_o*] before trusting this.
  set QSPI_IO_DELAY [expr {$IO_DELAY_FRAC * 2.0 * $CLOCK_PERIOD}]
  set_output_delay -mode func -clock qspi_clk -clock_fall $QSPI_IO_DELAY \
                   [get_ports {qspi_sd_o* qspi_sd_en_o* qspi_csn_o*}]
  set_input_delay  -mode func -clock qspi_clk $QSPI_IO_DELAY \
                   [get_ports qspi_sd_i*]
}


################################################################################
# 3. Clock properties
################################################################################

set_clock_uncertainty -mode func -setup $SETUP_UNCERT [get_clocks clock]
set_clock_uncertainty -mode func -hold  $HOLD_UNCERT  [get_clocks clock]

# TCK is slow and off-chip: loose, fixed margins.
set_clock_uncertainty -mode func -setup 2.0 [get_clocks jtag_tck]
set_clock_uncertainty -mode func -hold  0.5 [get_clocks jtag_tck]

if { $REF_CLK_ACTIVE } {
  set_clock_uncertainty -mode func -setup 2.0 [get_clocks ref_clk]
  set_clock_uncertainty -mode func -hold  0.5 [get_clocks ref_clk]
}

set_clock_transition $CLOCK_IDEAL_TRAN [get_clocks *]

# After CTS the flow must switch to the real network. clock_opt does this, but
# if you are running stages by hand:
#     set_propagated_clock [all_clocks]


################################################################################
# 4. Clock groups
#
# clk_i and jtag_tck_i have no phase relationship whatsoever. Without this the
# tool tries to time the dmi_cdc 2-phase crossing synchronously -- meaningless
# and unfixable. The RTL already handles the crossing safely (cdc_2phase +
# reset controller in i_dmi_jtag/i_dmi_cdc).
#
# NOTE (from the set_clock_groups man page): a relationship on a master clock
# does NOT propagate to its generated clocks. qspi_clk must be listed explicitly
# in the same group as `clock`, or it would have no declared relationship to
# jtag_tck.
################################################################################

set GRP_SYS [get_clocks clock]
if { $QSPI_SOURCE_SYNC } {
  set GRP_SYS [add_to_collection $GRP_SYS [get_clocks qspi_clk]]
}

if { $REF_CLK_ACTIVE } {
  set_clock_groups -asynchronous -name async_domains \
    -group $GRP_SYS \
    -group [get_clocks jtag_tck] \
    -group [get_clocks ref_clk]
} else {
  set_clock_groups -asynchronous -name async_domains \
    -group $GRP_SYS \
    -group [get_clocks jtag_tck]
}

# ADVANCED (do this only after the basic version closes): instead of fully
# cutting the CDC, keep the asynchronous crosstalk model but still bound the
# wire delay on the crossing, so the multi-bit data_src_q -> data_dst_q skew
# inside cdc_2phase stays sane:
#
#   set_clock_groups -asynchronous -allow_paths -name async_domains \
#     -group [get_clocks clock] -group [get_clocks jtag_tck]
#   set_max_delay $JTAG_TCK_PERIOD -ignore_clock_latency \
#     -from [get_clocks jtag_tck] -to [get_clocks clock]
#   set_max_delay $CLOCK_PERIOD    -ignore_clock_latency \
#     -from [get_clocks clock]     -to [get_clocks jtag_tck]


################################################################################
# 5. Case analysis -- functional mode
#
# testmode_i is 0 in functional operation. It feeds i_rstgen.test_mode_i, the
# SRAM test bypass, and the ICG test-enable pins. Pinning it removes those paths
# from timing instead of leaving the tool to optimize logic that can never
# switch. This also means testmode_i needs no false path -- case analysis
# already removes it.
################################################################################

set_case_analysis 0 [get_ports testmode_i]


################################################################################
# 6. Port classification
#
# Verified against croc_soc.sv. Full port list:
#   in : clk_i rst_ni ref_clk_i testmode_i fetch_en_i
#        jtag_tck_i jtag_tdi_i jtag_tms_i jtag_trst_ni
#        uart_rx_i qspi_sd_i[3:0] gpio_i[15:0]
#   out: status_o jtag_tdo_o uart_tx_o
#        qspi_clk_o qspi_sd_o[3:0] qspi_sd_en_o[3:0] qspi_csn_o[2:0]
#        gpio_o[15:0] gpio_out_en_o[15:0]
################################################################################

set CLK_PORTS [get_ports [list $CLOCK_PORT_NAME $JTAG_TCK_PORT]]

# Asynchronous / static. Never launched by any clock, so a setup check against
# `clock` (which is what the old all_inputs sweep produced) is meaningless.
#   rst_ni       -> i_rstgen async reset input
#   jtag_trst_ni -> TAP async reset
#   fetch_en_i   -> static strap, lands in i_ext_intr_sync (2-FF synchronizer)
#   testmode_i   -> already handled by case analysis above
set ASYNC_PORTS [get_ports {rst_ni jtag_trst_ni fetch_en_i testmode_i}]

# JTAG data pins live in the tck domain, not the clk_i domain.
set JTAG_IN  [get_ports {jtag_tdi_i jtag_tms_i}]
set JTAG_OUT [get_ports {jtag_tdo_o}]

# QSPI pins, only carved out if the optional generated clock is enabled.
if { $QSPI_SOURCE_SYNC } {
  set QSPI_IN  [get_ports qspi_sd_i*]
  set QSPI_OUT [get_ports {qspi_clk_o qspi_sd_o* qspi_sd_en_o* qspi_csn_o*}]
} else {
  set QSPI_IN  [get_ports -quiet ""]
  set QSPI_OUT [get_ports -quiet ""]
}

# Everything else: functional I/O in the clk_i domain.
#   ref_clk_i, uart_rx_i, gpio_i  -> async in reality, but each lands one gate
#                                    from a 2-FF synchronizer, so constraining
#                                    them costs nothing and keeps them visible.
#   qspi_sd_i                     -> genuinely captured by a clk_i flop.
set FUNC_IN  [all_inputs]
foreach coll [list $CLK_PORTS $ASYNC_PORTS $JTAG_IN $QSPI_IN] {
  if { [sizeof_collection $coll] > 0 } {
    set FUNC_IN [remove_from_collection $FUNC_IN $coll]
  }
}

set FUNC_OUT [all_outputs]
foreach coll [list $JTAG_OUT $QSPI_OUT] {
  if { [sizeof_collection $coll] > 0 } {
    set FUNC_OUT [remove_from_collection $FUNC_OUT $coll]
  }
}


################################################################################
# 7. Asynchronous / static inputs -> false paths
################################################################################

set_false_path -from [get_ports rst_ni]
set_false_path -from [get_ports jtag_trst_ni]
set_false_path -from [get_ports fetch_en_i]

# This only cuts the PORT-to-first-flop asynchronous path. The recovery/removal
# checks from i_rstgen's synchronizer output to every flop's async reset pin are
# still timed against `clock` -- correct, and what you want.


################################################################################
# 8. Functional I/O -- clk_i domain
################################################################################

set IO_DELAY [expr {$IO_DELAY_FRAC * $CLOCK_PERIOD}]

set_input_delay  -mode func -clock clock $IO_DELAY $FUNC_IN
set_output_delay -mode func -clock clock $IO_DELAY $FUNC_OUT

# If you would rather cut the genuinely asynchronous single-bit inputs cleanly
# (they all land in 2-FF synchronizers) instead of timing them:
#
#   set_false_path -from [get_ports {ref_clk_i uart_rx_i gpio_i*}]


################################################################################
# 9. JTAG I/O -- constrained against tck, not clk
################################################################################

set JTAG_IO_DELAY [expr {$IO_DELAY_FRAC * $JTAG_TCK_PERIOD}]

# The TAP samples TDI/TMS on the RISING edge of TCK.
set_input_delay -mode func -clock jtag_tck $JTAG_IO_DELAY $JTAG_IN

# The TAP launches TDO on the FALLING edge of TCK (IEEE 1149.1). Timing it
# against the rising edge -- which the old all_outputs sweep effectively did,
# against the wrong clock entirely -- is simply wrong.
set_output_delay -mode func -clock jtag_tck -clock_fall $JTAG_IO_DELAY $JTAG_OUT


################################################################################
# 10. Drive and load
#
# Without these the tool assumes a zero-impedance driver and a zero load. That
# is why the old run reported in2reg slack of +4.06 ns: it was not real. Expect
# in2reg/reg2out to get WORSE after this change -- that is the constraint
# telling the truth for the first time.
################################################################################

set_input_transition $EXT_INPUT_TRAN [all_inputs]
set_load             $EXT_LOAD       [all_outputs]


################################################################################
# 11. Design rule constraints
################################################################################

set_max_transition  $MAX_TRAN_DATA [current_design]
set_max_transition  $MAX_TRAN_CLK  [get_clocks *] -clock_path
set_max_capacitance $MAX_CAP       [current_design]
set_max_fanout      $MAX_FANOUT    [current_design]

# If your FC build rejects `-clock_path` on set_max_transition, drop that line
# and use the CTS-side option instead:
#     set_clock_tree_options -max_transition $MAX_TRAN_CLK


################################################################################
# 12. Sanity checks -- run these and READ them before trusting any QoR number
################################################################################

# report_clocks                    ;# expect 2 master clocks (clock, jtag_tck)
# check_timing                     ;# TCK-001 should collapse from 10,914 to
#                                  ;#   ~148 'case constant' (dead flops:
#                                  ;#   ibex imd_val_q_reg, OBI aid/rid tied to 0)
#                                  ;# TCK-002 should go to 0
# check_clock_trees                ;# CTS-905 / CTS-906 must both be 0
# report_clock_qor -type summary   ;# watch max latency and global skew
# report_constraint -all_violators