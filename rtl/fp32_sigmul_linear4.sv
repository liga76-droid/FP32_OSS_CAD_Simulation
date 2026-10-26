`timescale 1ns/1ps
module fp32_sigmul_linear4 #(
  parameter ID_W=16
)(
  input wire clk, rst_n,
  input wire in_valid, output wire in_ready,
  input wire [ID_W-1:0] in_id,
  input wire [23:0] sig_a, sig_b,
  output reg out_valid, input wire out_ready,
  output reg [ID_W-1:0] out_id,
  output reg [47:0] product
);
  // Exact unsigned 24x24 significand product, 4-stage elastic pipeline.
  // Stage 0 captures inputs. Stage 1 performs four parallel limb products.
  // Stage 2 performs a 3:2 CSA reduction. Stage 3 performs final carry-propagate.
  reg v0,v1,v2;
  reg [ID_W-1:0] id0,id1,id2;
  reg [23:0] a0,b0;
  reg [31:0] p_hh1;
  reg [23:0] p_hl1,p_lh1;
  reg [15:0] p_ll1;
  reg [47:0] csa_sum2,csa_carry2;
  reg [15:0] p_ll2;
  wire r3=!out_valid||out_ready;
  wire r2=!v2||r3;
  wire r1=!v1||r2;
  wire r0=!v0||r1;
  assign in_ready=r0;

  wire [31:0] p_hh_comb,p_hl_comb,p_lh_comb,p_ll_comb;
  alu_mul_reconfig alu0(.mode_8x8(1'b0),.a(a0[23:8]),.b(b0[23:8]),.product(p_hh_comb));
  alu_mul_reconfig alu1(.mode_8x8(1'b0),.a({8'b0,a0[7:0]}),.b(b0[23:8]),.product(p_hl_comb));
  alu_mul_reconfig alu2(.mode_8x8(1'b0),.a(a0[23:8]),.b({8'b0,b0[7:0]}),.product(p_lh_comb));
  alu_mul_reconfig alu3(.mode_8x8(1'b1),.a({8'b0,a0[7:0]}),.b({8'b0,b0[7:0]}),.product(p_ll_comb));

  wire [47:0] term_hh={p_hh1,16'b0};
  wire [47:0] term_hl={16'b0,p_hl1,8'b0};
  wire [47:0] term_lh={16'b0,p_lh1,8'b0};
  wire [47:0] term_ll={32'b0,p_ll1};
  wire [47:0] csa_s_comb=term_hh^term_hl^term_lh;
  wire [47:0] csa_c_comb=((term_hh&term_hl)|(term_hh&term_lh)|(term_hl&term_lh))<<1;
  wire [47:0] term_ll2={32'b0,p_ll2};
  wire [47:0] csa2_s=csa_sum2^csa_carry2^term_ll2;
  wire [47:0] csa2_c=((csa_sum2&csa_carry2)|(csa_sum2&term_ll2)|(csa_carry2&term_ll2))<<1;

  always @(posedge clk) begin
    if(!rst_n) begin
      v0<=0;v1<=0;v2<=0;out_valid<=0;
      id0<=0;id1<=0;id2<=0;out_id<=0;a0<=0;b0<=0;
      p_hh1<=0;p_hl1<=0;p_lh1<=0;p_ll1<=0;
      csa_sum2<=0;csa_carry2<=0;p_ll2<=0;product<=0;
    end else begin
      if(r3) begin out_valid<=v2; if(v2) begin out_id<=id2;product<=csa2_s+csa2_c;end end
      if(r2) begin
        v2<=v1;
        if(v1) begin id2<=id1;csa_sum2<=csa_s_comb;csa_carry2<=csa_c_comb;p_ll2<=p_ll1;end
      end
      if(r1) begin
        v1<=v0;
        if(v0) begin
          id1<=id0;p_hh1<=p_hh_comb;p_hl1<=p_hl_comb[23:0];
          p_lh1<=p_lh_comb[23:0];p_ll1<=p_ll_comb[15:0];
        end
      end
      if(r0) begin v0<=in_valid;if(in_valid)begin id0<=in_id;a0<=sig_a;b0<=sig_b;end end
    end
  end
endmodule
