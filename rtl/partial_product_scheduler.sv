`timescale 1ns/1ps
// v0.3 literal schedule-window tracker + exact nine-partial reference datapath.
// This is an integration/functional reference, NOT yet the physical packed-16x16
// implementation of the schedule. See README for the distinction.
module partial_product_scheduler #(
  parameter ID_W=16
)(
  input wire clk,rst_n,
  input wire in_valid, output wire in_ready,
  input wire [ID_W-1:0] in_context_id,
  input wire [23:0] sig_a,sig_b,
  output reg out_valid, input wire out_ready,
  output reg [ID_W-1:0] out_context_id,
  output reg [47:0] product,
  output reg [8:0] unique_valid,
  output reg [8:0] unique_commit,
  output wire [3:0] stage_valid_dbg,
  output wire [3:0] stage_ready_dbg
);
  localparam [8:0] B_AA=9'b000000001, B_AB=9'b000000010,
    B_AC=9'b000000100, B_BA=9'b000001000, B_BB=9'b000010000,
    B_BC=9'b000100000, B_CA=9'b001000000, B_CB=9'b010000000,
    B_CC=9'b100000000;
  localparam [8:0] STAGE0_MASK=B_AA;
  localparam [8:0] STAGE1_MASK=B_AB|B_AC|B_BB|B_BC;
  localparam [8:0] STAGE2_MASK=B_BA|B_BB|B_CA|B_CB;
  localparam [8:0] STAGE3_MASK=B_BB|B_BC|B_CB|B_CC;

  reg v0,v1,v2;
  reg [ID_W-1:0] id0,id1,id2;
  reg [23:0] a0,b0;
  reg [15:0] pAA1,pAB1,pAC1,pBA1,pBB1,pBC1,pCA1,pCB1,pCC1;
  reg [15:0] pAA2,pAB2,pAC2,pBA2,pBB2,pBC2,pCA2,pCB2,pCC2;
  reg [15:0] pAA3,pAB3,pAC3,pBA3,pBB3,pBC3,pCA3,pCB3,pCC3;
  wire r3=!out_valid||out_ready;
  wire r2=!v2||r3;
  wire r1=!v1||r2;
  wire r0=!v0||r1;
  assign in_ready=r0;
  assign stage_valid_dbg={out_valid,v2,v1,v0};
  assign stage_ready_dbg={r3,r2,r1,r0};

  wire [7:0] aA=a0[23:16], aB=a0[15:8], aC=a0[7:0];
  wire [7:0] bA=b0[23:16], bB=b0[15:8], bC=b0[7:0];
  wire [15:0] ppAA=aA*bA, ppAB=aA*bB, ppAC=aA*bC;
  wire [15:0] ppBA=aB*bA, ppBB=aB*bB, ppBC=aB*bC;
  wire [15:0] ppCA=aC*bA, ppCB=aC*bB, ppCC=aC*bC;

  // The nine unique contributions are summed exactly once. Their repeated
  // appearance in stage masks is provenance/window metadata, not extra terms.
  wire [47:0] total =
      ({32'b0,pAA2} << 32) +
      ({32'b0,pAB2} << 24) +
      ({32'b0,pAC2} << 16) +
      ({32'b0,pBA2} << 24) +
      ({32'b0,pBB2} << 16) +
      ({32'b0,pBC2} << 8)  +
      ({32'b0,pCA2} << 16) +
      ({32'b0,pCB2} << 8)  +
      ({32'b0,pCC2});

  always @(posedge clk) begin
    if(!rst_n) begin
      v0<=0;v1<=0;v2<=0;out_valid<=0;
      id0<=0;id1<=0;id2<=0;out_context_id<=0;
      a0<=0;b0<=0;
      pAA1<=0;pAB1<=0;pAC1<=0;pBA1<=0;pBB1<=0;pBC1<=0;pCA1<=0;pCB1<=0;pCC1<=0;
      pAA2<=0;pAB2<=0;pAC2<=0;pBA2<=0;pBB2<=0;pBC2<=0;pCA2<=0;pCB2<=0;pCC2<=0;
      pAA3<=0;pAB3<=0;pAC3<=0;pBA3<=0;pBB3<=0;pBC3<=0;pCA3<=0;pCB3<=0;pCC3<=0;
      product<=0;unique_valid<=0;unique_commit<=0;
    end else begin
      if(r3) begin
        out_valid<=v2;
        if(v2) begin
          out_context_id<=id2;
          product<=total;
          unique_valid<=9'h1ff;
          unique_commit<=9'h1ff;
        end else begin unique_valid<=0;unique_commit<=0;end
      end
      if(r2) begin
        v2<=v1;
        if(v1) begin
          id2<=id1;
          pAA2<=pAA1;pAB2<=pAB1;pAC2<=pAC1;pBA2<=pBA1;pBB2<=pBB1;
          pBC2<=pBC1;pCA2<=pCA1;pCB2<=pCB1;pCC2<=pCC1;
        end
      end
      if(r1) begin
        v1<=v0;
        if(v0) begin
          id1<=id0;
          pAA1<=ppAA;pAB1<=ppAB;pAC1<=ppAC;pBA1<=ppBA;pBB1<=ppBB;
          pBC1<=ppBC;pCA1<=ppCA;pCB1<=ppCB;pCC1<=ppCC;
        end
      end
      if(r0) begin
        v0<=in_valid;
        if(in_valid) begin id0<=in_context_id;a0<=sig_a;b0<=sig_b;end
      end
    end
  end
endmodule
