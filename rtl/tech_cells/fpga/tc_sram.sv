// Generic (technology-independent) single/multi-port synchronous SRAM.
//
// Drop-in replacement for rtl/tech_cells/gf180/tc_sram.sv, used when croc is
// targeted at an FPGA instead of the ASIC standard-cell/macro library. The
// GF180 version instantiates a hard memory macro (gf180mcu_fd_ip_sram__...)
// that does not exist on Xilinx parts, so here the array is described
// behaviorally with a simple registered read -- the pattern Vivado infers
// as Block RAM. Same module/parameter/port list as the ASIC variant so it
// can be swapped in the flist without touching any caller (croc_domain.sv).
//
// Only Latency == 1 is implemented -- the only configuration croc uses.

module tc_sram_blackbox #(
  parameter int unsigned NumWords     = 32'd0,
  parameter int unsigned DataWidth    = 32'd0,
  parameter int unsigned ByteWidth    = 32'd0,
  parameter int unsigned NumPorts     = 32'd0,
  parameter int unsigned Latency      = 32'd0,
  parameter              SimInit      = "none",
  parameter bit          PrintSimCfg  = 1'b0,
  parameter              ImplKey      = "none"
) ();
endmodule

module tc_sram #(
  parameter int unsigned NumWords     = 32'd1024,
  parameter int unsigned DataWidth    = 32'd128,
  parameter int unsigned ByteWidth    = 32'd8,
  parameter int unsigned NumPorts     = 32'd2,
  parameter int unsigned Latency      = 32'd1,
  parameter              SimInit      = "none",
  parameter bit          PrintSimCfg  = 1'b0,
  parameter              ImplKey      = "none",
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth,
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic  [NumPorts-1:0] req_i,
  input  logic  [NumPorts-1:0] we_i,
  input  addr_t [NumPorts-1:0] addr_i,
  input  data_t [NumPorts-1:0] wdata_i,
  input  be_t   [NumPorts-1:0] be_i,
  output data_t [NumPorts-1:0] rdata_o
);

  data_t mem [NumWords];

  for (genvar p = 0; p < NumPorts; p++) begin : gen_port
    always_ff @(posedge clk_i) begin
      if (req_i[p]) begin
        if (we_i[p]) begin
          for (int unsigned b = 0; b < BeWidth; b++) begin
            if (be_i[p][b]) mem[addr_i[p]][b*ByteWidth +: ByteWidth] <= wdata_i[p][b*ByteWidth +: ByteWidth];
          end
        end else begin
          rdata_o[p] <= mem[addr_i[p]];
        end
      end
    end
  end

endmodule
