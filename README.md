
---
**Notice**

The modifications in this PDK were done by **North Carolina State University** and
**Institute of Microelectronic Systems, Leibniz University Hannover**.  

It is provided *“as is”* without warranty of any kind, express or implied,  
including but not limited to correctness or fitness for a particular purpose.

**Authors:**
- W. Shepherd Pitts, PhD (NCSU) – wspitts2@ncsu.edu  
- Viktor Schneider (IMS LUH)  

Note: you can make your own NDM files by going up one directory and using the Makefile provided there.

**Copyright © 2025 North Carolina State University and Leibniz University Hannover.**
---
---

# Fusion Compiler + ICV LVS/DRC Unified Flow

This repository provides a **unified Makefile flow** that integrates
Synopsys Fusion Compiler (FC) with Synopsys IC Validator (ICV) for
running **RTL-to-GDSII synthesis**, **netlist translation (nettran)**,
and **signoff verification (LVS/DRC/Fill)** on the GF180MCU PDK.

------------------------------------------------------------------------

## Prerequisites

- **Synopsys Fusion Compiler** (`fc_shell`)
- **Synopsys IC Validator** (`icv`, `icv_nettran`)
- **GF180MCU PDK** with OpenPDKs layout and CDL views
- Linux environment with `bash`  
  (the Makefile enforces `bash -eu -o pipefail`)

Environment variables required:

- `OPENPDKS_DIR_BASE` → Path to your OpenPDKs install
- `PDK_DIR` → Path to the Synopsys runset/tech directory for ICV

------------------------------------------------------------------------

## Directory Structure

```
.
├── Makefile            # Unified flow driver
├── scripts/            # Fusion Compiler TCL scripts (e.g., 01_read_rtl.tcl, 99_finish.tcl)
├── work/               # Build artifacts (FC outputs, merged netlists, logs)
├── synopsys_custom/    # Pre-fill signoff outputs (LVS/DRC)
└── fill/               # Post-fill outputs (filled GDS, LVS/DRC runs)
```

------------------------------------------------------------------------

## Key Variables

- **Design**
  - `TOP` – Top design name (default: `top`)
  - `RTL_SV` – RTL source (default: `$(TOP).sv`)
  - `DESIGN_VERILOG` – Synthesized Verilog netlist (`work/$(TOP).v`)
  - `GDS` – Final layout GDS (`work/$(TOP).gds`)
- **PDK**
  - `GF180MCU_PDK_DIR` – Base path to GF180 PDK OpenPDKs flavor
  - `STDCELLS_CDL` – Standard cell CDL
  - `IO_CDL` – IO cell CDL
- **Runsets**
  - `LVS_RUN_SET` – LVS rule deck (default: `cmos018hv.3p3.6v.lvs.rs`)
  - `DRC_RUN_SET` – DRC rule deck (default: `gf180mcu_drc.rs`)
  - `FILL_RUN_SET` – Fill rule deck (default: `gf180mcu_fill.rs`)

------------------------------------------------------------------------

## Main Targets

- `make finish`  
  Run Fusion Compiler full flow (up to `finish.tcl`), exporting:
  - Gate-level Verilog (`work/top.v`)
  - Layout GDS (`work/top.gds`)

- `make all`  
  Run the **complete flow**: `finish` → `nettran` → `LVS` → `DRC` → `FILL-ALL`.

- `make lvs`  
  Run ICV LVS with `work/top_lvs_merged.cdl` and `work/top.gds`.

- `make drc`  
  Run ICV DRC with the exported layout GDS.

- `make fill`  
  Run ICV metal fill only. Produces a filled GDS in `fill/top.icv.fill/`.

- `make fill-lvs`  
  Run LVS on the filled GDS (requires `make fill`).

- `make fill-drc`  
  Run DRC on the filled GDS (requires `make fill`).

- `make fill-all`  
  Run fill + fill-lvs + fill-drc.

------------------------------------------------------------------------

## Cleaning Targets

- `make clean` – Remove nettran, LVS, DRC, and fill outputs
- `make clean-lvs` – Remove LVS and fill-LVS run directories
- `make clean-drc` – Remove DRC and fill-DRC run directories
- `make clean-fill` – Remove fill directories
- `make clean-nettran` – Remove merged CDL (`*_lvs_merged.cdl`)
- `make distclean` – Clean everything (including `work/`)

------------------------------------------------------------------------

## Stepwise Targets

The Makefile dynamically generates rules from `scripts/0*_*.tcl`:

- `make read_rtl` – Run RTL import/init
- `make floorplan` – Floorplanning + power grid
- `make synthesis` – Logic synthesis
- `make cts` – Clock tree synthesis
- `make route` – Routing
- `make finish` – Finalize, export Verilog + GDS

You can also run:  
- `make open_<step>` – Open a block in terminal mode  
- `make gui_<step>` – Open a block in GUI mode  

Example:

```bash
make gui_floorplan
```

------------------------------------------------------------------------

## Nettran

After Fusion Compiler finishes, `icv_nettran` merges:  
- The synthesized Verilog (`work/top.v`)  
- Standard cell CDL  
- IO cell CDL  

into a single merged SPICE netlist:

```
work/top_lvs_merged.cdl
```

This is the **schematic netlist** used for LVS.

------------------------------------------------------------------------

## LVS & DRC

- **LVS**: Runs IC Validator in `$(WORK_LVS_DIR)` and compares
  `work/top.gds` vs `work/top_lvs_merged.cdl`.
- **DRC**: Runs IC Validator in `$(WORK_DRC_DIR)` against the foundry rule deck.
- **Fill LVS/DRC**: Post-fill signoff runs are placed under `fill/top.icv.fill.*`.

Logs are written to:  
- `stdout.lvs.log`  
- `stdout.drc.log`  
- `stdout.fill.log`  

------------------------------------------------------------------------

## Example Usage

```bash
# Run the complete flow
make all -j$(nproc)

# Just run LVS after synthesis
make lvs

# Just run DRC
make drc

# Run fill and post-fill checks
make fill-all

# Clean outputs
make clean

# Clean only LVS results
make clean-lvs

# Clean only DRC results
make clean-drc
```

------------------------------------------------------------------------

## Notes

- Ensure your `finish.tcl` script **exports Verilog and GDS**;
  otherwise, `make all` will fail at nettran.
- The Makefile enforces tool checks before each stage with `require_tool`.
- Parallel builds (`make -j`) are supported and safe.
