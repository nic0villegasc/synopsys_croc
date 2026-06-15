# -----------------------------------------------------------------------------
# Croc SoC Physical Design Flow
# Author: Nicolás Villegas - Universidad de los Andes, Chile
# Description: Unified Fusion Compiler (FC) RTL-to-GDS Makefile
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.DELETE_ON_ERROR:

# ------------------------------------------------------------------------------
# Design Configuration
# ------------------------------------------------------------------------------
TOP                := croc_chip
WORK_DIR           := work
LOGS_DIR           := logs
REPO_DIR           := $(shell pwd)

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Fusion Compiler dynamic step rules (from scripts/0*_*.tcl)
# ------------------------------------------------------------------------------
# This block automatically reads any TCL file in scripts/ that starts with a number 
# (e.g., 01_read_rtl.tcl, 02_floorplan.tcl) and creates a make target for it.
define MAKE_FC_RULE
.PHONY: $2 open_$2 gui_$2

$2: $(WORK_DIR)/design.dlib/$2

open_$2: $(WORK_DIR)/design.dlib/$2
	cd $(WORK_DIR) && fc_shell -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

gui_$2: $(WORK_DIR)/design.dlib/$2
	cd $(WORK_DIR) && fc_shell -gui -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

$(WORK_DIR)/design.dlib/$2: $3
	mkdir -p $(WORK_DIR) $(LOGS_DIR) && cd $(WORK_DIR) && set -o pipefail; fc_shell -batch -f ../$1 | tee ../$(LOGS_DIR)/$2.log
endef

TCL_FILES = $(sort $(wildcard scripts/0*_*.tcl))

DEPENDENCY :=
$(foreach file,$(TCL_FILES),\
  $(eval base := $(shell echo $(notdir $(file)) | sed -E 's/^[0-9]+_(.*)\.tcl/\1/'))\
  $(eval $(call MAKE_FC_RULE,$(file),$(base),$(DEPENDENCY)))\
  $(eval DEPENDENCY := $(WORK_DIR)/design.dlib/$(base))\
)

# ------------------------------------------------------------------------------
# Full Flow
# ------------------------------------------------------------------------------
.PHONY: all
all: $(DEPENDENCY)
	@echo "[FLOW] Fusion Compiler flow completed successfully up to the final TCL script."

# ------------------------------------------------------------------------------
# Clean
# ------------------------------------------------------------------------------
.PHONY: clean distclean
clean:
	rm -rf $(WORK_DIR) $(LOGS_DIR)
	@echo "Cleaned work and logs directories."

# ------------------------------------------------------------------------------
# Software & Simulation Flow
# ------------------------------------------------------------------------------
.PHONY: sw sim sim-vcs verilate run clean-sw clean-sim

# Default application binary. Override on the command line, e.g.:
#   make run BIN=sim/sw/bin/test/test_gpio.hex
BIN ?= sim/sw/hello_world/bin/helloworld.hex

sw:
	@echo "[SW] Compiling RISC-V bare-metal software..."
	@$(MAKE) -C sim/sw

clean-sw:
	@echo "[SW] Cleaning software binaries..."
	@$(MAKE) -C sim/sw clean

# Compile the Verilator hardware model only (re-run after any RTL change).
verilate:
	@echo "[SIM] Compiling Verilator hardware model..."
	@cd sim && BUILD_ONLY=1 bash scripts/run_verilator.sh

# Run a binary on the already-compiled model -- no recompile, near-instant.
run: sw
	@echo "[SIM] Running $(BIN) ..."
	@cd sim && BIN=$(abspath $(BIN)) SKIP_BUILD=1 bash scripts/run_verilator.sh

# Compile + run in one shot (original behavior; defaults to helloworld).
sim: sw
	@echo "[SIM] Launching Verilator simulation flow..."
	@cd sim && BIN=$(abspath $(BIN)) bash scripts/run_verilator.sh

sim-vcs: sw
	@echo "[SIM] Launching VCS simulation flow..."
	@cd sim && bash scripts/run_vcs.sh

clean-sim:
	@echo "[SIM] Cleaning simulation builds..."
	@rm -rf sim/build/*

# ------------------------------------------------------------------------------
# Help Menu
# ------------------------------------------------------------------------------
.PHONY: help
help:
	@echo "================================================================"
	@echo " Croc SoC Fusion Compiler Flow"
	@echo "================================================================"
	@echo "Main Targets:"
	@echo "  make all        – Run all available Fusion Compiler steps sequentially"
	@echo "  make clean      – Delete the 'work' directory and all generated logs"
	@echo ""
	@echo "Individual Steps (dynamically generated from scripts/):"
	@echo "  make read_rtl"
	@echo "  make floorplan"
	@echo "  make synthesis"
	@echo "  make cts"
	@echo "  make route"
	@echo "  make finish"
	@echo ""
	@echo "Simulation (Verilator):"
	@echo "  make sim                       – Compile + run (defaults to helloworld)"
	@echo "  make sim BIN=<path/to.hex>     – Compile + run a specific application"
	@echo "  make verilate                  – Compile the HW model only (after RTL changes)"
	@echo "  make run BIN=<path/to.hex>     – Run an app on the compiled model (no recompile)"
	@echo "  make clean-sim                 – Remove the simulation build directory"
	@echo ""
	@echo "GUI / Interactive Commands:"
	@echo "  make open_<step> – Open a specific block in terminal mode (e.g., make open_floorplan)"
	@echo "  make gui_<step>  – Open a specific block in GUI mode (e.g., make gui_floorplan)"
	@echo "================================================================"