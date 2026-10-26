`timescale 1ns/1ps
// One unsigned 16x16 multiplier operator, operand selection before operator.
// 8x8 mode zero-extends the selected low bytes; result remains 32 bits.
module alu_mul_reconfig (
  input wire mode_8x8,
  input wire [15:0] a,
  input wire [15:0] b,
  output wire [31:0] product
);
  wire [15:0] mul_a = mode_8x8 ? {8'b0,a[7:0]} : a;
  wire [15:0] mul_b = mode_8x8 ? {8'b0,b[7:0]} : b;
  assign product = mul_a * mul_b;
endmodule
