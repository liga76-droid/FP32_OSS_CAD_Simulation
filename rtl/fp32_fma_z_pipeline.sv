`timescale 1ns/1ps
// FMA integration boundary: linear4 significand product + transaction-aligned Z metadata.
// This module is intentionally an integration milestone, NOT a completed IEEE-754 FMA.
module fp32_fma_z_pipeline #(
  parameter ID_W=16
)(
  input wire clk, rst_n,
  input wire in_valid, output wire in_ready,
  input wire [ID_W-1:0] in_id,
  input wire [31:0] a, b, z,
  output wire out_valid, input wire out_ready,
  output wire [ID_W-1:0] out_id,
  output wire [47:0] product,
  output wire product_sign,
  output wire signed [10:0] product_exp_unbiased,
  output wire [23:0] z_significand,
  output wire z_sign,
  output wire signed [10:0] z_exp_unbiased,
  output wire [31:0] z_raw,
  output wire [2:0] a_class, b_class, z_class,
  output wire finite_operands,
  output reg signed [559:0] exact_sum_scaled
);
  function [23:0] sig24(input [31:0] x);
    begin sig24 = (x[30:23]==0) ? {1'b0,x[22:0]} : {1'b1,x[22:0]}; end
  endfunction
  function signed [10:0] exp_unbiased(input [31:0] x);
    begin
      if (x[30:23]==0) exp_unbiased = -11'sd126;
      else exp_unbiased = $signed({3'b000,x[30:23]}) - 11'sd127;
    end
  endfunction
  // class: 000 zero, 001 subnormal, 010 normal, 011 infinity, 100 NaN
  function [2:0] fpclass(input [31:0] x);
    begin
      if (x[30:23]==8'hff) fpclass = (x[22:0]==0) ? 3'b011 : 3'b100;
      else if (x[30:23]==0) fpclass = (x[22:0]==0) ? 3'b000 : 3'b001;
      else fpclass = 3'b010;
    end
  endfunction

  wire [23:0] sig_a=sig24(a), sig_b=sig24(b);
  wire mul_in_ready;
  wire [ID_W-1:0] mul_out_id;
  wire mul_out_valid;
  wire [47:0] mul_product;
  assign in_ready=mul_in_ready;
  assign out_valid=mul_out_valid;
  assign out_id=mul_out_id;
  assign product=mul_product;

  fp32_sigmul_linear4 #(.ID_W(ID_W)) u_sigmul (
    .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(mul_in_ready),
    .in_id(in_id),.sig_a(sig_a),.sig_b(sig_b),
    .out_valid(mul_out_valid),.out_ready(out_ready),.out_id(mul_out_id),.product(mul_product)
  );

  // Sideband follows the same elastic ready chain as fp32_sigmul_linear4.
  reg v0,v1,v2;
  reg [ID_W-1:0] id0,id1,id2;
  reg [31:0] z0,z1,z2, a0,a1,a2, b0,b1,b2;
  reg [31:0] z_out,a_out,b_out;
  wire r3=!mul_out_valid || out_ready;
  wire r2=!v2 || r3;
  wire r1=!v1 || r2;
  wire r0=!v0 || r1;
  // Assertion-by-construction: the multiplier's in_ready is the same r0.
  always @(posedge clk) begin
    if(!rst_n) begin
      v0<=0; v1<=0; v2<=0;
      id0<=0;id1<=0;id2<=0;
      z0<=0;z1<=0;z2<=0;a0<=0;a1<=0;a2<=0;b0<=0;b1<=0;b2<=0;
      z_out<=0;a_out<=0;b_out<=0;
    end else begin
      if(r3 && v2) begin z_out<=z2; a_out<=a2; b_out<=b2; end
      if(r2) begin v2<=v1; if(v1) begin id2<=id1;z2<=z1;a2<=a1;b2<=b1;end end
      if(r1) begin v1<=v0; if(v0) begin id1<=id0;z1<=z0;a1<=a0;b1<=b0;end end
      if(r0) begin v0<=in_valid; if(in_valid) begin id0<=in_id;z0<=z;a0<=a;b0<=b;end end
    end
  end
  assign z_raw=z_out;
  assign z_sign=z_out[31];
  assign z_significand=sig24(z_out);
  assign z_exp_unbiased=exp_unbiased(z_out);
  assign product_sign=a_out[31]^b_out[31];
  assign product_exp_unbiased=exp_unbiased(a_out)+exp_unbiased(b_out);
  assign a_class=fpclass(a_out);
  assign b_class=fpclass(b_out);
  assign z_class=fpclass(z_out);
  assign finite_operands=(a_class!=3'b011 && a_class!=3'b100 &&
                          b_class!=3'b011 && b_class!=3'b100 &&
                          z_class!=3'b011 && z_class!=3'b100);

  // Exact finite-input algebraic A*B+Z, before binary32 normalization/rounding.
  // Common quantum is 2^-298. This wide reference datapath preserves every bit
  // of finite binary32 operands, including subnormals; it is not area-optimized.
  integer p_shift, z_shift;
  reg [559:0] p_mag, z_mag;
  reg signed [559:0] p_signed, z_signed;
  always @* begin
    p_shift = $signed(exp_unbiased(a_out)) + $signed(exp_unbiased(b_out)) + 252;
    z_shift = $signed(exp_unbiased(z_out)) + 275;
    p_mag = 560'd0;
    z_mag = 560'd0;
    if (p_shift >= 0 && p_shift <= 506)
      p_mag = ({512'd0, product} << p_shift);
    if (z_shift >= 0 && z_shift <= 402)
      z_mag = ({536'd0, z_significand} << z_shift);
    p_signed = product_sign ? -$signed(p_mag) : $signed(p_mag);
    z_signed = z_sign ? -$signed(z_mag) : $signed(z_mag);
    exact_sum_scaled = p_signed + z_signed;
  end
endmodule
