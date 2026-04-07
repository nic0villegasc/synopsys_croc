# Croc SoC: Physical Implementation & Foundational Flow

This repository provides a unified ASIC physical design flow for the **Croc RISC-V MCU**, targeting the **GF180MCU PDK**. It utilizes Synopsys Fusion Compiler (FC) to drive the physical design flow from RTL synthesis down to layout routing and GDSII export.

## 📖 Project Background

This physical implementation framework was initially developed as part of an internship project supported by **AC3E**, **Synopsys**, and the **Universidad de los Andes**.

While it started as a targeted study of the Croc architecture and Synopsys Reference Methodologies (RM), this repository now serves as a foundational, extensible framework for ongoing personal research and educational ASIC tapeouts in VLSI physical design.

**Author:** Nicolás Villegas – Electrical Engineering Student, Universidad de los Andes, Chile.

---

## 🛠️ Prerequisites

To run this flow, your environment must have access to:

* **Synopsys Fusion Compiler** (`fc_shell`)
* **GF180MCU PDK** (OpenPDKs layout and CDL views)
* A Linux environment with `bash`

### Path Configuration

Instead of relying on environment variables, the PDK path is explicitly defined at the top of the `Makefile`. Before running the flow, ensure you open the `Makefile` and update `PDK_ROOT` to point to your local GF180MCU installation.

---

### 📂 Directory Structure

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

(Note: The work/ directory will be generated automatically during the build process to store the FC database, logs, and GDS outputs).

---

## ⚙️ Key Flow Configuration

If you need to change the target module or runsets, you can edit these variables at the top of the `Makefile`:

* **Design Top:** The default top module is set to `croc_chip`.
* **RTL List:** Driven by `croc.flist`.

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

### Cleaning Up

* `make clean` – Deletes the `work/` directory and all generated logs/databases.
* `make distclean` – Same as `make clean`, entirely resetting the workspace.

---

## 🙏 Acknowledgments

* **Croc Architecture:** The underlying Croc SoC RTL (CVE2, OBI) was developed by the Integrated Systems Laboratory at ETH Zurich and the University of Bologna.
* **Flow Base:** The foundational `Makefile` and tool integration base logic was originally authored by W. Shepherd Pitts (NCSU) and Viktor Schneider (IMS LUH).
