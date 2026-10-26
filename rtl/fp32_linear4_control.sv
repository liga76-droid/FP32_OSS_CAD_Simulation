`timescale 1ns/1ps
// Four-stage elastic control pipeline. This module is control-only.
module fp32_linear4_control #(
  parameter ID_W=16, PAYLOAD_W=64
)(
  input wire clk, rst_n,
  input wire in_valid, output wire in_ready,
  input wire [ID_W-1:0] in_id,
  input wire [PAYLOAD_W-1:0] in_payload,
  output wire out_valid, input wire out_ready,
  output wire [ID_W-1:0] out_id,
  output wire [PAYLOAD_W-1:0] out_payload,
  output reg [31:0] accepted_count, retired_count,
  output reg [31:0] input_stall_count,
  output reg [31:0] s0_stall_count, s1_stall_count, s2_stall_count, s3_stall_count
);
  reg v0,v1,v2,v3;
  reg [ID_W-1:0] id0,id1,id2,id3;
  reg [PAYLOAD_W-1:0] p0,p1,p2,p3;
  wire r3=!v3||out_ready, r2=!v2||r3, r1=!v1||r2, r0=!v0||r1;
  assign in_ready=r0;
  assign out_valid=v3;
  assign out_id=id3;
  assign out_payload=p3;
  always @(posedge clk) begin
    if (!rst_n) begin
      v0<=0;v1<=0;v2<=0;v3<=0;
      id0<=0;id1<=0;id2<=0;id3<=0;p0<=0;p1<=0;p2<=0;p3<=0;
      accepted_count<=0;retired_count<=0;input_stall_count<=0;
      s0_stall_count<=0;s1_stall_count<=0;s2_stall_count<=0;s3_stall_count<=0;
    end else begin
      if(in_valid&&in_ready) accepted_count<=accepted_count+1;
      else if(in_valid&&!in_ready) input_stall_count<=input_stall_count+1;
      if(v0&&!r0) s0_stall_count<=s0_stall_count+1;
      if(v1&&!r1) s1_stall_count<=s1_stall_count+1;
      if(v2&&!r2) s2_stall_count<=s2_stall_count+1;
      if(v3&&!r3) s3_stall_count<=s3_stall_count+1;
      if(out_valid&&out_ready) retired_count<=retired_count+1;
      if(r3) begin v3<=v2; if(v2) begin id3<=id2;p3<=p2;end end
      if(r2) begin v2<=v1; if(v1) begin id2<=id1;p2<=p1;end end
      if(r1) begin v1<=v0; if(v0) begin id1<=id0;p1<=p0;end end
      if(r0) begin v0<=in_valid; if(in_valid) begin id0<=in_id;p0<=in_payload;end end
    end
  end
endmodule
