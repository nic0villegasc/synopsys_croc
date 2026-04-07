# Croc SoC: Physical Implementation & Foundational Flow

This repository provides a unified ASIC physical design flow for the **Croc RISC-V MCU**, targeting the **GF180MCU PDK**. It integrates Synopsys Fusion Compiler (FC) for RTL-to-GDSII and Synopsys IC Validator (ICV) for signoff verification (LVS, DRC, and Metal Fill).

## 📖 Project Background
This physical implementation framework was initially developed as part of an internship project supported by **AC3E**, **Synopsys**, and the **Universidad de los Andes**. 

While it started as a targeted study of the Croc architecture and Synopsys Reference Methodologies (RM), this repository now serves as a foundational, extensible framework for ongoing personal research and educational ASIC tapeouts in VLSI physical design.

**Author:** Nicolás Villegas – Electrical Engineering Student, Universidad de los Andes, Chile.

---

## 🛠️ Prerequisites

To run this flow, your environment must have access to:
* **Synopsys Fusion Compiler** (`fc_shell`)
* **Synopsys IC Validator** (`icv`, `icv_nettran`)
* **GF180MCU PDK** (OpenPDKs layout and CDL views)
* A Linux environment with `bash`

### Environment Variables
Ensure the following variables are set in your terminal before running the flow:
* `OPENPDKS_DIR_BASE` → Path to your OpenPDKs installation.
* `PDK_DIR` → Path to the Synopsys runset/tech directory for ICV.

---

## 📂 Directory Structure

This repository acts as a single source of truth for the flow, driven entirely by the `Makefile`.

```text
.
├── Makefile            # Unified flow driver (handles FC and ICV runs)
├── README.md           # Project documentation
├── croc.flist          # Unified RTL source manifest
├── rtl/                # Source SystemVerilog files (CVE2, OBI, APB, etc.)
├── scripts/            # Fusion Compiler TCL scripts (01_read_rtl.tcl, etc.)
│   └── common/         # Technology setup and constraints
├── documentation/      # Flow documentation and physical design guides
```

*(Note: The directories `work/`, `synopsys_custom/`, and `fill/` will be generated automatically during the build process to store logs, artifacts, and GDS outputs).*

---

## ⚙️ Key Flow Configuration

If you need to change the target module or runsets, you can edit these variables at the top of the `Makefile`:

* **Design Top:** The default top module is set to `croc_chip`.
* **RTL List:** Driven by `croc.flist`.
* **Runsets:** Defaults to `cmos018hv.3p3.6v.lvs.rs` (LVS), `gf180mcu_drc.rs` (DRC), and `gf180mcu_fill.rs` (Fill).

---

## 🚀 How to Run the Flow

The `Makefile` dynamically generates rules from the TCL scripts in the `scripts/` directory.

### Full Automation
* `make all`
    * Runs the complete RTL-to-GDS flow: Synthesis → Nettran → LVS → DRC → Metal Fill → Post-Fill Checks.

### Step-by-Step Build
You can run the Fusion Compiler stages sequentially:
* `make read_rtl` – Load RTL and elaborate
* `make floorplan` – Floorplanning and Power Grid (PG) creation
* `make synthesis` – Logic Synthesis
* `make cts` – Clock Tree Synthesis
* `make route` – Routing
* `make finish` – Finalize and export the Verilog netlist and GDSII

*(Tip: You can open any stage in the GUI by prefixing `gui_`, e.g., `make gui_floorplan`)*.

### Signoff Checks (IC Validator)
If you already have your `work/croc_chip.gds` generated, you can run individual checks:
* `make lvs` – Runs LVS against the merged SPICE netlist.
* `make drc` – Runs DRC against the GF180 foundry rules.
* `make fill-all` – Runs metal fill insertion, followed by a final LVS/DRC on the filled GDS.

### Cleaning Up
* `make clean` – Removes LVS, DRC, and Fill artifacts.
* `make distclean` – Wipes the entire environment clean, including the `work/` directory containing the exported GDS.

---

## 🙏 Acknowledgments

* **Croc Architecture:** The underlying Croc SoC RTL (CVE2, OBI) was developed by the Integrated Systems Laboratory at ETH Zurich and the University of Bologna. 
* **Flow Base:** The foundational `Makefile` and tool integration base logic was originally authored by W. Shepherd Pitts (NCSU) and Viktor Schneider (IMS LUH).