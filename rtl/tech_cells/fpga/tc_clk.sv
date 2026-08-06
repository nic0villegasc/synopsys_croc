// Generic (technology-independent) clock cells.
//
// Drop-in replacement for rtl/tech_cells/{gf180,ihp13}/tc_clk.sv, used when
// croc is targeted at an FPGA instead of the ASIC standard-cell library.
// Same module/port names as the ASIC variants (callers only ever touch the
// outer clk_i/clk_o-style ports), pure behavioral internals so Vivado maps
// them onto ordinary fabric logic instead of an unresolvable std-cell.

module tc_clk_inverter (
  input  logic clk_i,
  output logic clk_o
);
  assign clk_o = ~clk_i;
endmodule

module tc_clk_buffer (
  input  logic clk_i,
  output logic clk_o
);
  assign clk_o = clk_i;
endmodule

module tc_clk_mux2 (
  input  logic clk0_i,
  input  logic clk1_i,
  input  logic clk_sel_i,
  output logic clk_o
);
  assign clk_o = clk_sel_i ? clk1_i : clk0_i;
endmodule

module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);
  assign clk_o = clk0_i ^ clk1_i;
endmodule

module tc_clk_gating #(
  parameter bit IS_FUNCTIONAL = 1'b1
) (
  input  logic clk_i,
  input  logic en_i,
  input  logic test_en_i,
  output logic clk_o
);
  // Standard latch-based integrated clock gate: the enable is captured
  // while clk_i is low so clk_o can never produce a glitch/runt pulse.
  logic en_latch;

  always_latch begin
    if (!clk_i) en_latch = en_i | test_en_i;
  end

  assign clk_o = clk_i & en_latch;
endmodule
