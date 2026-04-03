module inverter (
                 input wire  clk,
                 input wire  A,
                 output wire Z
                 );

   reg Z_reg;

   always @(posedge clk) begin
     Z_reg <= ~A;
   end

   assign Z = Z_reg;

endmodule
