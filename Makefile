# -----------------------------------------------------------------------------
# Croc SoC Physical Design Flow
# Author: Nicolás Villegas - Universidad de los Andes, Chile
# Description: Unified Fusion Compiler (FC) RTL-to-GDS Makefile
# -----------------------------------------------------------------------------

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:

# ------------------------------------------------------------------------------
# Design Configuration
# ------------------------------------------------------------------------------
TOP                := croc_chip
WORK_DIR           := work

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Fusion Compiler dynamic step rules (from scripts/0*_*.tcl)
# ------------------------------------------------------------------------------
# This block automatically reads any TCL file in scripts/ that starts with a number 
# (e.g., 01_read_rtl.tcl, 02_floorplan.tcl) and creates a make target for it.
define MAKE_FC_RULE
$2: $3
	mkdir -p $(WORK_DIR) && cd $(WORK_DIR) && fc_shell -batch -f ../$1 | tee ../$(WORK_DIR)/$2.log

open_$2: $(WORK_DIR)/design.dlib/$2
	cd $(WORK_DIR) && fc_shell -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

gui_$2: $(WORK_DIR)/design.dlib/$2
	cd $(WORK_DIR) && fc_shell -gui -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

$(WORK_DIR)/design.dlib/$2: $3
	mkdir -p $(WORK_DIR) && cd $(WORK_DIR) && fc_shell -batch -f ../$1 | tee ../$(WORK_DIR)/$2.log
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
	rm -rf $(WORK_DIR)
	@echo "Cleaned work directory."

distclean: clean

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
	@echo "GUI / Interactive Commands:"
	@echo "  make open_<step> – Open a specific block in terminal mode (e.g., make open_floorplan)"
	@echo "  make gui_<step>  – Open a specific block in GUI mode (e.g., make gui_floorplan)"
	@echo "================================================================"