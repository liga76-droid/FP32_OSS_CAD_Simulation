`timescale 1ns/1ps
// Exact finite A*B+Z accumulator with a compact 64-bit significand window.
// Contract: exact only when exponent-base distance <= 14; otherwise range_supported=0.
// This is deliberately a bounded-range stress DUT, not a full IEEE-754 FMA.
module fp32_fma_finite_opt #(parameter ID_W=16)(
 input wire clk, rst_n, input wire in_valid, output wire in_ready,
 input wire [ID_W-1:0] in_id, input wire [31:0] a,b,z,
 output wire out_valid, input wire out_ready, output wire [ID_W-1:0] out_id,
 output wire [47:0] product, output wire signed [63:0] sum_mantissa,
 output wire signed [10:0] sum_exp2, output wire range_supported,
 output wire [31:0] z_raw
);
 function [23:0] sig24(input [31:0] x);
  begin sig24=(x[30:23]==0)?{1'b0,x[22:0]}:{1'b1,x[22:0]}; end
 endfunction
 function signed [10:0] lsb_exp(input [31:0] x);
  begin if(x[30:23]==0) lsb_exp=-11'sd149; else lsb_exp=$signed({3'b000,x[30:23]})-11'sd150; end
 endfunction
 wire [23:0] sa=sig24(a), sb=sig24(b);
 wire mul_ready,mul_valid; wire [ID_W-1:0] mid; wire [47:0] mp;
 fp32_sigmul_linear4 #(.ID_W(ID_W)) u_mul(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(mul_ready),.in_id(in_id),.sig_a(sa),.sig_b(sb),.out_valid(mul_valid),.out_ready(out_ready),.out_id(mid),.product(mp));
 assign in_ready=mul_ready; assign out_valid=mul_valid; assign out_id=mid; assign product=mp;
 reg v0,v1,v2; reg [ID_W-1:0] id0,id1,id2; reg [31:0] z0,z1,z2; reg [31:0] a0,a1,a2,b0,b1,b2;
 reg [31:0] zo,ao,bo;
 wire r3=!mul_valid||out_ready, r2=!v2||r3, r1=!v1||r2, r0=!v0||r1;
 always @(posedge clk) begin
  if(!rst_n) begin v0<=0;v1<=0;v2<=0;id0<=0;id1<=0;id2<=0;z0<=0;z1<=0;z2<=0;a0<=0;a1<=0;a2<=0;b0<=0;b1<=0;b2<=0;zo<=0;ao<=0;bo<=0; end
  else begin
   if(r3&&v2) begin zo<=z2;ao<=a2;bo<=b2;end
   if(r2) begin v2<=v1;if(v1)begin id2<=id1;z2<=z1;a2<=a1;b2<=b1;end end
   if(r1) begin v1<=v0;if(v0)begin id1<=id0;z1<=z0;a1<=a0;b1<=b0;end end
   if(r0) begin v0<=in_valid;if(in_valid)begin id0<=in_id;z0<=z;a0<=a;b0<=b;end end
  end
 end
 // Output transaction metadata follows product's elastic pipeline.
 assign z_raw=zo;
 wire signed [10:0] ep=lsb_exp(ao)+lsb_exp(bo);
 wire signed [10:0] ez=lsb_exp(zo);
 wire signed [10:0] emin=(ep<ez)?ep:ez;
 wire signed [10:0] dp=ep-emin, dz=ez-emin;
 wire [63:0] pmag=({16'd0,mp} << dp);
 wire [63:0] zmag=({40'd0,sig24(zo)} << dz);
 wire signed [63:0] ps= (ao[31]^bo[31]) ? -$signed(pmag) : $signed(pmag);
 wire signed [63:0] zs= zo[31] ? -$signed(zmag) : $signed(zmag);
 assign sum_mantissa=ps+zs;
 assign sum_exp2=emin;
 assign range_supported=(dp<=14 && dz<=14 && ao[30:23]!=8'hff && bo[30:23]!=8'hff && zo[30:23]!=8'hff);
endmodule
