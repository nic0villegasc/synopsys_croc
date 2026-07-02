module W25Q128JWxxIM (
    input  wire CSn,
    input  wire CLK,
    inout  wire DIO,
    inout  wire DO,
    inout  wire WPn,
    inout  wire HOLDn
);

  // Tie the bi-directional I/O ports to high-impedance (Z).
  // This prevents Verilator from complaining about undriven nets
  // and avoids multiple-driver conflicts on the bus.
  assign DIO   = 1'bz;
  assign DO    = 1'bz;
  assign WPn   = 1'bz;
  assign HOLDn = 1'bz;

endmodule