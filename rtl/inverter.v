module inverter(
                input      clk,
                input      A,
                output reg Z
                );

   always @(posedge clk) begin
     Z <= ~A;
   end

endmodule
