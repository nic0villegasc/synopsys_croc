// rtl/obi_qspi/qqspi.v sets `default_nettype none and never resets it.
// Vivado's read_verilog treats the whole flist as one compilation unit, so
// that directive otherwise leaks forward into every file listed after it
// (obi_qspi.sv's plainly-typed `logic` ports then fail elaboration with
// "net type must be explicitly specified"). Placed in the flist right
// after qqspi.v to restore the default before any later file is read,
// without touching the vendored qqspi.v itself.
`default_nettype wire
