# -----------------------------------------------------------------------------
# All Rights Reserved.
# Copyright 2025 North Carolina State University
#
# This file was created at the North Carolina State University.
# It is provided "as is" without warranty of any kind, express or implied,
# including but not limited to correctness or fitness for a particular purpose.
#
# Authors:
#   W. Shepherd Pitts, PhD (NCSU)  wspitts2@ncsu.edu
# -----------------------------------------------------------------------------

# ==============================================================================
# Fusion Compiler + ICV LVS/DRC unified Makefile
# ==============================================================================
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:

# ------------------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------------------
GF180MCU_SNPS      ?= $(realpath ../)
export GF180MCU_SNPS

GF180MCU_PDK_DIR   ?= ${OPENPDKS_DIR_BASE}/share/pdk/gf180mcuD
ICV_LVS            ?= $(PDK_DIR)/LVS_ICV/LVS/ICV
ICV_DRC            ?= $(PDK_DIR)/DRC_ICV

# Runsets
LVS_RUN_SET        ?= cmos018hv.3p3.6v.lvs.rs
DRC_RUN_SET        ?= gf180mcu_drc.rs
FILL_RUN_SET       ?= gf180mcu_fill.rs

# CDL libraries
STDCELLS_CDL       ?= $(GF180MCU_PDK_DIR)/libs.ref/gf180mcu_fd_sc_mcu7t5v0/cdl/gf180mcu_fd_sc_mcu7t5v0.cdl
IO_CDL             ?= $(GF180MCU_PDK_DIR)/libs.ref/gf180mcu_fd_io/cdl/gf180mcu_fd_io.cdl
UNIT_CDL           ?= $(ICV_LVS)/unit.cdl

# Design
TOP                ?= top
RTL_SV             ?= $(TOP).sv
DESIGN_VERILOG     ?= work/$(TOP).v
GDS                ?= work/$(TOP).gds
WORK_DIR           ?= synopsys_custom
WORK_LVS_DIR       ?= $(WORK_DIR)/$(TOP).icv.lvs
WORK_DRC_DIR       ?= $(WORK_DIR)/$(TOP).icv.drc

# Fill-specific directories
FILL_DIR           ?= fill
WORK_FILL_DIR      ?= $(FILL_DIR)/$(TOP).icv.fill
WORK_FILL_LVS_DIR  ?= $(FILL_DIR)/$(TOP).icv.fill.lvs
WORK_FILL_DRC_DIR  ?= $(FILL_DIR)/$(TOP).icv.fill.drc

# Derived
NETTRAN_CDL        := work/$(TOP)_lvs_merged.cdl

.DEFAULT_GOAL := help

# ------------------------------------------------------------------------------
# Utilities
# ------------------------------------------------------------------------------
define require_tool
	@command -v $(1) >/dev/null 2>&1 || { echo "Error: missing tool '$(1)' in PATH"; exit 127; }
endef

# ------------------------------------------------------------------------------
# Fusion Compiler step rules (from scripts/0*_*.tcl)
# ------------------------------------------------------------------------------
define MAKE_FC_RULE
$2: $3
	mkdir -p work && cd work && fc_shell -batch -f ../$1 | tee ../work/$2.log

open_$2: work/design.dlib/$2
	cd work && fc_shell -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

gui_$2: work/design.dlib/$2
	cd work && fc_shell -gui -f ../scripts/common/setup.tcl -x "open_lib design.dlib; open_block $2"

work/design.dlib/$2: $3
	mkdir -p work && cd work && fc_shell -batch -f ../$1 | tee ../work/$2.log
endef

TCL_FILES = $(sort $(wildcard scripts/0*_*.tcl))

DEPENDENCY :=
$(foreach file,$(TCL_FILES),\
  $(eval base := $(shell echo $(notdir $(file)) | sed -E 's/^[0-9]+_(.*)\.tcl/\1/'))\
  $(eval $(call MAKE_FC_RULE,$(file),$(base),$(DEPENDENCY)))\
  $(eval DEPENDENCY := work/design.dlib/$(base))\
)

# ------------------------------------------------------------------------------
# Finish step and exports
# ------------------------------------------------------------------------------
.PHONY: finish
finish: work/design.dlib/finish

$(DESIGN_VERILOG) $(GDS): finish
	@echo "[FC] Fusion Compiler finish step complete."
	@test -f "$(DESIGN_VERILOG)" || { echo "Error: missing $(DESIGN_VERILOG). Did finish.tcl export Verilog?"; exit 1; }
	@test -f "$(GDS)" || { echo "Error: missing $(GDS). Did finish.tcl export GDS?"; exit 1; }

.PHONY: export
export: finish
	@echo "[EXPORT] Verifying design exports..."
	@ls -lh "$(DESIGN_VERILOG)" "$(GDS)"

# ------------------------------------------------------------------------------
# Nettran
# ------------------------------------------------------------------------------
$(NETTRAN_CDL): $(DESIGN_VERILOG)
	$(call require_tool,icv_nettran)
	@echo "[NETTRAN] Merging $< with stdcells + IO + PRIMATIVES -> $@"
	test -r "$(STDCELLS_CDL)" || { echo "Error: STDCELLS_CDL not found"; exit 1; }
	test -r "$(IO_CDL)"       || { echo "Error: IO_CDL not found"; exit 1; }
	test -r "$(UNIT_CDL)"     || { echo "Error: UNIT_CDL not found"; exit 1; }
	icv_nettran -verilog $< -sp "$(STDCELLS_CDL)" "$(IO_CDL)" "$(UNIT_CDL)" -outType SPICE -outName $@

# ------------------------------------------------------------------------------
# LVS
# ------------------------------------------------------------------------------
.PHONY: lvs
lvs: export $(NETTRAN_CDL)
	$(call require_tool,icv)
	@echo "[LVS] Running ICV LVS in $(WORK_LVS_DIR)"
	mkdir -p "$(WORK_LVS_DIR)"
	cd "$(WORK_LVS_DIR)"; \
	  icv \
	    -f gdsii \
	    -i "$(abspath $(GDS))" \
	    -c "$(TOP)" \
	    -I "$(ICV_LVS)" \
	    -s "$(abspath $(NETTRAN_CDL))" \
	    -sf SPICE \
	    -stc "$(TOP)" \
	    -oa_dm6 \
	    -vue "$(ICV_LVS)/$(LVS_RUN_SET)" \
	    2>&1 | tee stdout.lvs.log

# ------------------------------------------------------------------------------
# DRC
# ------------------------------------------------------------------------------
.PHONY: drc
drc: export $(GDS)
	$(call require_tool,icv)
	@echo "[DRC] Running ICV DRC in $(WORK_DRC_DIR)"
	mkdir -p "$(WORK_DRC_DIR)"
	cd "$(WORK_DRC_DIR)"; \
	  icv \
	    -f gdsii \
	    -i "$(abspath $(GDS))" \
	    -c "$(TOP)" \
	    -vue "$(ICV_DRC)/$(DRC_RUN_SET)" \
	    2>&1 | tee stdout.drc.log

# ------------------------------------------------------------------------------
# FILL ONLY
# ------------------------------------------------------------------------------
.PHONY: fill
fill: export $(GDS)
	$(call require_tool,icv)
	@echo "[FILL] Running ICV metal fill with BEOL_DENSITY=1 in $(WORK_FILL_DIR)"
	mkdir -p "$(WORK_FILL_DIR)"
	cd "$(WORK_FILL_DIR)"; \
	  BEOL_DENSITY=1 \
	  icv \
	    -f gdsii \
	    -i "$(abspath $(GDS))" \
	    -c "$(TOP)" \
	    -vue "$(ICV_DRC)/$(FILL_RUN_SET)" \
	    2>&1 | tee stdout.fill.log ; exit 0
	@FILLED_GDS=$$(ls $(WORK_FILL_DIR)/*.gds 2>/dev/null | head -n1); \
	if [ -z "$$FILLED_GDS" ]; then \
	  echo "[FILL] Error: No filled GDS produced."; exit 1; \
	else \
	  echo "[FILL] Filled GDS available at: $$FILLED_GDS"; \
	fi

# ------------------------------------------------------------------------------
# FILL LVS
# ------------------------------------------------------------------------------
.PHONY: fill-lvs
fill-lvs: $(NETTRAN_CDL) fill
	@FILLED_GDS=$$(ls $(WORK_FILL_DIR)/*.gds 2>/dev/null | head -n1); \
	if [ -z "$$FILLED_GDS" ]; then \
	  echo "[FILL LVS] Error: No filled GDS available. Run 'make fill' first."; exit 1; \
	else \
	  ABS_FILLED_GDS=$$(realpath $$FILLED_GDS); \
	  echo "[FILL LVS] Running LVS on $$ABS_FILLED_GDS"; \
	  mkdir -p "$(WORK_FILL_LVS_DIR)"; \
	  cd "$(WORK_FILL_LVS_DIR)"; \
	    icv \
	      -f gdsii \
	      -i "$$ABS_FILLED_GDS" \
	      -c "$(TOP)" \
	      -I "$(ICV_LVS)" \
	      -s "$(abspath $(NETTRAN_CDL))" \
	      -sf SPICE \
	      -stc "$(TOP)" \
	      -oa_dm6 \
	      -vue "$(ICV_LVS)/$(LVS_RUN_SET)" \
	      2>&1 | tee stdout.lvs.log ; exit 0; \
	fi

# ------------------------------------------------------------------------------
# FILL DRC
# ------------------------------------------------------------------------------
.PHONY: fill-drc
fill-drc: fill
	@FILLED_GDS=$$(ls $(WORK_FILL_DIR)/*.gds 2>/dev/null | head -n1); \
	if [ -z "$$FILLED_GDS" ]; then \
	  echo "[FILL DRC] Error: No filled GDS available. Run 'make fill' first."; exit 1; \
	else \
	  ABS_FILLED_GDS=$$(realpath $$FILLED_GDS); \
	  echo "[FILL DRC] Running DRC on $$ABS_FILLED_GDS"; \
	  mkdir -p "$(WORK_FILL_DRC_DIR)"; \
	  cd "$(WORK_FILL_DRC_DIR)"; \
	    icv \
	      -f gdsii \
	      -i "$$ABS_FILLED_GDS" \
	      -c "$(TOP)" \
	      -vue "$(ICV_DRC)/$(DRC_RUN_SET)" \
	      2>&1 | tee stdout.drc.log ; exit 0; \
	fi

# ------------------------------------------------------------------------------
# FILL ALL (fill + fill-lvs + fill-drc)
# ------------------------------------------------------------------------------
.PHONY: fill-all
fill-all: fill fill-lvs fill-drc
	@echo "[FILL-ALL] Fill + LVS + DRC completed successfully."

# ------------------------------------------------------------------------------
# Full flow
# ------------------------------------------------------------------------------
.PHONY: all
all: finish $(NETTRAN_CDL) lvs drc fill-all
	@echo "[FLOW] Full flow completed successfully."

# ------------------------------------------------------------------------------
# Clean
# ------------------------------------------------------------------------------
.PHONY: clean clean-nettran clean-lvs clean-drc clean-fill distclean
clean: clean-nettran clean-lvs clean-drc clean-fill
	rm -rf work $(WORK_DIR)

clean-nettran:
	rm -f $(NETTRAN_CDL) icv_nettran.log icv_nettran.sum

clean-lvs:
	rm -rf "$(WORK_LVS_DIR)" "$(WORK_FILL_LVS_DIR)"

clean-drc:
	rm -rf "$(WORK_DRC_DIR)" "$(WORK_FILL_DRC_DIR)"

clean-fill:
	rm -rf "$(WORK_FILL_DIR)"

distclean: clean

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
.PHONY: help
help:
	@echo "Main Targets:"
	@echo "  make finish     – run Fusion Compiler full flow (export Verilog + GDS)"
	@echo "  make all        – run finish + nettran + LVS + DRC + FILL-ALL"
	@echo "  make lvs        – run ICV LVS"
	@echo "  make drc        – run ICV DRC"
	@echo "  make fill       – run ICV metal fill only"
	@echo "  make fill-lvs   – run LVS on filled GDS (requires 'make fill')"
	@echo "  make fill-drc   – run DRC on filled GDS (requires 'make fill')"
	@echo "  make fill-all   – run fill + fill-lvs + fill-drc"
	@
