// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
// Authors:
//
// -Thomas Benz <tbenz@iis.ee.ethz.ch>
// -Tobias Senti <tsenti@student.ethz.ch>

module tc_clk_inverter (
    input  logic clk_i,
    output logic clk_o
  );
  (* keep *)(* dont_touch = "true" *)
  gf180mcu_fd_sc_mcu7t5v0__clkinv_1 i_inv (
    .I ( clk_i ),
    .ZN ( clk_o )
  );

endmodule

module tc_clk_buffer (
  input  logic clk_i,
  output logic clk_o
);
  (* keep *)(* dont_touch = "true" *)
  gf180mcu_fd_sc_mcu7t5v0__clkbuf_1 i_buf (
    .I ( clk_i ),
    .Z ( clk_o )
  );

endmodule

module tc_clk_mux2 (
    input  logic clk0_i,
    input  logic clk1_i,
    input  logic clk_sel_i,
    output logic clk_o
  );
  (* keep *)(* dont_touch = "true" *)
  gf180mcu_fd_sc_mcu7t5v0__mux2_1 i_mux (
    .I0 ( clk0_i    ),
    .I1 ( clk1_i    ),
    .S  ( clk_sel_i ),
    .Z  ( clk_o     )
  );
endmodule

module tc_clk_xor2 (
  input  logic clk0_i,
  input  logic clk1_i,
  output logic clk_o
);

  (* keep *)(* dont_touch = "true" *)
  gf180mcu_fd_sc_mcu7t5v0__xor2_1 i_mux (
    .A1 ( clk0_i ),
    .A2 ( clk1_i ),
    .Z ( clk_o  )
  );
endmodule

module tc_clk_gating #(
    parameter bit IS_FUNCTIONAL = 1'b1
  )(
    input  logic clk_i,
    input  logic en_i,
    input  logic test_en_i,
    output logic clk_o
  );

  if (IS_FUNCTIONAL || `ifdef USE_CLKGATE 1 `else 0 `endif) begin
    (* keep *)(* dont_touch = "true" *)
    gf180mcu_fd_sc_mcu7t5v0__icgtn_1 i_clkgate (
      .E ( en_i  ),
      .TE  ( test_en_i ),
      .CLKN  ( clk_i ),
      .Q ( clk_o )
    );
  end else begin
    assign clk_o = clk_i;
  end

endmodule