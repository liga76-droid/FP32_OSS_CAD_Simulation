`timescale 1ns/1ps
module tb_fma_ieee;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0, in_valid=0, out_ready=1;
 reg [15:0] in_id=0; reg [31:0] a=0,b=0,z=0;
 wire in_ready,out_valid; wire [15:0] out_id; wire [31:0] result;
 wire flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact;
 integer checks=0;
 fp32_fma_ieee dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),.in_id(in_id),.a(a),.b(b),.z(z),
  .out_valid(out_valid),.out_ready(out_ready),.out_id(out_id),.result(result),.flag_invalid(flag_invalid),.flag_divzero(flag_divzero),
  .flag_overflow(flag_overflow),.flag_underflow(flag_underflow),.flag_inexact(flag_inexact));
 task automatic run_case(input [31:0] aa,bb,zz, input [31:0] exp_result, input [4:0] exp_flags);
  integer timeout;
  begin
   @(negedge clk); a=aa;b=bb;z=zz;in_id=checks;in_valid=1;
   do @(posedge clk); while(!in_ready);
   @(negedge clk); in_valid=0;
   timeout=0;
   while(!out_valid && timeout<12) begin @(negedge clk); timeout=timeout+1; end
   if(!out_valid) begin $display("FAIL timeout case %0d",checks); $fatal(1); end
   if(out_id!==checks[15:0] || result!==exp_result || {flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact}!==exp_flags) begin
    $display("FAIL case=%0d a=%h b=%h z=%h got=%h flags=%b id=%0d expected=%h flags=%b id=%0d",checks,aa,bb,zz,result,{flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact},out_id,exp_result,exp_flags,checks);
    $fatal(1);
   end
   checks=checks+1;
   @(negedge clk);
  end
 endtask
 initial begin
  repeat(3) @(negedge clk); rst_n=1;
  run_case(32'h3f800000,32'h40000000,32'h40400000,32'h40a00000,5'b00000); // 1*2+3=5
  run_case(32'h3fc00000,32'h40100000,32'hbf800000,32'h40180000,5'b00000); // 1.5*2.25-1=2.375
  run_case(32'h3f000000,32'h3f000000,32'h3f800000,32'h3fa00000,5'b00000); // .25+1=1.25
  run_case(32'hbf800000,32'h40000000,32'h3f800000,32'hbf800000,5'b00000); // -2+1=-1
  run_case(32'h00000000,32'h3f800000,32'h80000000,32'h00000000,5'b00000); // opposite signed zeros => +0 RNE
  run_case(32'h00000001,32'h3f000000,32'h00000000,32'h00000000,5'b00011); // min subnormal * .5 -> zero, UF|NX
  run_case(32'h7f7fffff,32'h40000000,32'h00000000,32'h7f800000,5'b00101); // overflow, inexact
  run_case(32'h7fc12345,32'h3f800000,32'h00000000,32'h7fc12345,5'b00000); // qNaN propagation
  run_case(32'h7f812345,32'h3f800000,32'h00000000,32'h7fc12345,5'b10000); // sNaN quiet + invalid
  run_case(32'h7f800000,32'h00000000,32'h3f800000,32'h7fc00000,5'b10000); // inf*0 invalid
  run_case(32'h7f800000,32'h3f800000,32'hff800000,32'h7fc00000,5'b10000); // +inf + -inf invalid
  run_case(32'h7f800000,32'h3f800000,32'h3f800000,32'h7f800000,5'b00000); // +inf + finite
  run_case(32'h00000000,32'h3f800000,32'h40400000,32'h40400000,5'b00000); // zero product + Z
  $display("PASS IEEE FMA directed cases: %0d",checks);
  $display("LIMIT: directed vectors only; run randomized differential/reference testing before claiming IEEE-754 conformance.");
  $finish;
 end
endmodule
