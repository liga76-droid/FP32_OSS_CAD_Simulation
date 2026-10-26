`timescale 1ns/1ps
module tb_mul_reconfig;
  reg mode_8x8; reg [15:0] a,b; wire [31:0] product; integer i; reg [31:0] seed;
  alu_mul_reconfig dut(.mode_8x8(mode_8x8),.a(a),.b(b),.product(product));
  task check(input reg m,input reg [15:0] aa,input reg [15:0] bb);
    reg [15:0] xa,xb; reg [31:0] exp;
    begin mode_8x8=m;a=aa;b=bb;#1;
      if(m) begin xa={8'b0,aa[7:0]};xb={8'b0,bb[7:0]};end
      else begin xa=aa;xb=bb;end
      exp=xa*xb;
      if(product!==exp)$fatal(1,"MUL mismatch mode=%0d a=%h b=%h got=%h exp=%h",m,aa,bb,product,exp);
    end
  endtask
  initial begin
    check(1,16'h00ff,16'h00ff);check(1,16'h12ff,16'habfe);
    check(1,16'hffff,16'hffff);check(1,16'h0000,16'hffff);
    check(0,16'hffff,16'hffff);check(0,16'hffff,16'h0001);
    check(0,16'h8000,16'h0002);check(0,16'hffff,16'h0000);
    seed=32'hc001d00d;
    for(i=0;i<20000;i=i+1) begin
      seed=seed*32'd1664525+32'd1013904223;a=seed[15:0];
      seed=seed*32'd1664525+32'd1013904223;b=seed[15:0];check(i[0],a,b);
    end
    $display("PASS MUL PRIMITIVE: directed + 20000 deterministic pseudo-random cases.");
    $finish;
  end
endmodule
