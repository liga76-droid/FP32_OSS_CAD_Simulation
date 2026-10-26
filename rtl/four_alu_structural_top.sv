`timescale 1ns/1ps
module four_alu_structural_top(
  input wire [3:0] mode_8x8,
  input wire [15:0] a0,b0,a1,b1,a2,b2,a3,b3,
  output wire [31:0] p0,p1,p2,p3
);
  alu_mul_reconfig alu0(.mode_8x8(mode_8x8[0]),.a(a0),.b(b0),.product(p0));
  alu_mul_reconfig alu1(.mode_8x8(mode_8x8[1]),.a(a1),.b(b1),.product(p1));
  alu_mul_reconfig alu2(.mode_8x8(mode_8x8[2]),.a(a2),.b(b2),.product(p2));
  alu_mul_reconfig alu3(.mode_8x8(mode_8x8[3]),.a(a3),.b(b3),.product(p3));
endmodule
