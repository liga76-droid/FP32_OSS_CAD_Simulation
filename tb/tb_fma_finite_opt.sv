`timescale 1ns/1ps
module tb_fma_finite_opt;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,in_valid=0,out_ready=1; reg [15:0] in_id=0; reg [31:0] a=0,b=0,z=0;
 wire in_ready,out_valid; wire [15:0] out_id; wire [47:0] product; wire signed [63:0] sum_mantissa; wire signed [10:0] sum_exp2; wire range_supported; wire [31:0] z_raw;
 fp32_fma_finite_opt dut(.*);
 function [23:0] sig24(input [31:0] x); begin sig24=(x[30:23]==0)?{1'b0,x[22:0]}:{1'b1,x[22:0]}; end endfunction
 function signed [10:0] baseexp(input [31:0] x); begin if(x[30:23]==0) baseexp=-11'sd149; else baseexp=$signed({3'b000,x[30:23]})-11'sd150; end endfunction
 reg [15:0] ids[0:1023]; reg [31:0] asave[0:1023], bsave[0:1023], zs[0:1023]; reg signed [559:0] refs[0:1023];
 integer sent=0,got=0,cyc=0,accepted_cycle=0; integer i,ea,eb,ez; reg [31:0] ra,rb,rz; reg [47:0] rp; reg signed [559:0] refv, lhs;
 always @(posedge clk) begin
  if(!rst_n) cyc<=0; else begin
   cyc<=cyc+1;
   if(in_valid&&in_ready) sent<=sent+1;
   if(out_valid&&out_ready) begin
    if(out_id!==ids[got]) $fatal(1,"ID order mismatch index=%0d got=%0d expected=%0d",got,out_id,ids[got]);
    if(z_raw!==zs[got]) $fatal(1,"Z sideband mismatch index=%0d",got);
    if(!range_supported) $fatal(1,"range_supported false index=%0d",got);
    lhs=$signed({{496{sum_mantissa[63]}},sum_mantissa}) <<< (sum_exp2+298);
    if(lhs!==refs[got]) $fatal(1,"sum mismatch index=%0d exp2=%0d mant=%h",got,sum_exp2,sum_mantissa);
    got<=got+1;
   end
  end
 end
 task make_case(input integer idx);
  integer x,y,ze; reg [22:0] fa,fb,fz; reg [31:0] aa,bb,zz; reg [47:0] prod; reg signed [559:0] pterm,zterm;
  reg signed [10:0] epa,ezb,base;
  begin
   // Exponents selected so product and Z have identical binary scale; random signs/fractions stress exact cancellation and carry.
   x=120+(($random & 32'h7fffffff)%21); y=120+(($random & 32'h7fffffff)%21); ze=x+y-150;
   fa=$random; fb=$random; fz=$random;
   aa={1'b0,x[7:0],fa}; bb={1'b0,y[7:0],fb}; zz={1'b0,ze[7:0],fz};
   if(($random & 1)!=0) aa[31]=1; if(($random & 1)!=0) bb[31]=1; if(($random & 1)!=0) zz[31]=1;
   if((idx%17)==0) begin aa={1'b0,x[7:0],23'd0}; bb={1'b0,y[7:0],23'd0}; zz={1'b0,ze[7:0],23'd0}; end
   ids[idx]=idx[15:0]; asave[idx]=aa; bsave[idx]=bb; zs[idx]=zz;
   prod=sig24(aa)*sig24(bb); epa=baseexp(aa)+baseexp(bb); ezb=baseexp(zz); base=(epa<ezb)?epa:ezb;
   pterm=($signed({512'd0,prod}) <<< (epa+298)); zterm=($signed({536'd0,sig24(zz)}) <<< (ezb+298));
   if(aa[31]^bb[31]) pterm=-pterm; if(zz[31]) zterm=-zterm; refs[idx]=pterm+zterm;
  end
 endtask
 initial begin
  repeat(4) @(negedge clk); rst_n=1;
  // Prepare independent exact references before driving the stream.
  for(i=0;i<512;i=i+1) make_case(i);
  i=0;
  while(i<512) begin
   @(negedge clk);
   out_ready=(($random & 32'h7fffffff)%5)!=0;
   if((($random & 32'h7fffffff)%4)!=0) begin
    in_valid=1; in_id=ids[i]; a=asave[i]; b=bsave[i]; z=zs[i];
   end else in_valid=0;
   @(posedge clk);
   if(in_valid&&in_ready) i=i+1;
  end
  @(negedge clk); in_valid=0; out_ready=1;
  wait(got==sent); $display("PASS optimized finite FMA stress"); $finish;
 end
 initial begin #1000000; $fatal(1,"timeout sent=%0d got=%0d",sent,got); end
endmodule
