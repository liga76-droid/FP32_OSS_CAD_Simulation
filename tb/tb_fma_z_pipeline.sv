`timescale 1ns/1ps
module tb_fma_z_pipeline;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0, in_valid=0, out_ready=1;
  reg [15:0] in_id=0;
  reg [31:0] a=0,b=0,z=0;
  wire in_ready,out_valid;
  wire [15:0] out_id;
  wire [47:0] product;
  wire product_sign,z_sign;
  wire signed [10:0] product_exp_unbiased,z_exp_unbiased;
  wire [23:0] z_significand;
  wire [31:0] z_raw;
  wire [2:0] a_class,b_class,z_class;
  wire finite_operands;
  wire signed [559:0] exact_sum_scaled;
  integer sent=0,got=0,cycles=0;
  reg [15:0] ids[0:7]; reg [47:0] prods[0:7]; reg [31:0] zs[0:7];
  fp32_fma_z_pipeline dut(.*);
  always @(posedge clk) begin
    if(!rst_n) cycles<=0;
    else begin
      cycles<=cycles+1;
      if(in_valid&&in_ready) begin
        ids[sent]<=in_id; prods[sent]<={24'b0,((a[30:23]==0)?{1'b0,a[22:0]}:{1'b1,a[22:0]})} * {24'b0,((b[30:23]==0)?{1'b0,b[22:0]}:{1'b1,b[22:0]})};
        zs[sent]<=z; sent<=sent+1;
      end
      if(out_valid&&out_ready) begin
        if(out_id!==ids[got]) $fatal(1,"ID mismatch got=%0d",got);
        if(product!==prods[got]) $fatal(1,"product mismatch got=%0d",got);
        if(z_raw!==zs[got]) $fatal(1,"Z sideband mismatch got=%0d expected=%h actual=%h",got,zs[got],z_raw);
        if(!finite_operands) $fatal(1,"finite operands incorrectly classified");
        case (got)
          0: if(exact_sum_scaled !== ($signed(560'd5) <<< 298)) $fatal(1,"A*B+Z case0 mismatch"); // 1*2+3=5
          1: if(exact_sum_scaled !== ($signed(560'd19) <<< 295)) $fatal(1,"A*B+Z case1 mismatch"); // 1.5*2.25-1=2.375
          2: if(exact_sum_scaled !== ($signed(560'd5) <<< 296)) $fatal(1,"A*B+Z case2 mismatch"); // 0.5*0.5+1=1.25
        endcase
        got<=got+1;
      end
    end
  end
  task send(input [31:0] aa,input [31:0] bb,input [31:0] zz,input [15:0] id);
    begin
      @(negedge clk); in_valid=1; a=aa;b=bb;z=zz;in_id=id;
      do @(posedge clk); while(!(in_valid&&in_ready));
      @(negedge clk); in_valid=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk); rst_n=1;
    send(32'h3f800000,32'h40000000,32'h40400000,16'd1); // 1*2 + Z=3 metadata
    send(32'h3fc00000,32'h40100000,32'hbf800000,16'd2);
    send(32'h3f000000,32'h3f000000,32'h3f800000,16'd3);
    wait(got==3); @(negedge clk);
    $display("PASS FMA A*B+Z EXACT FINITE SUM: directed cases, IDs and Z sideband aligned.");
    $display("LIMIT: exact sum uses 560-bit 2^-298 fixed scale; binary32 normalize/round and IEEE special-case result handling are not implemented.");
    $finish;
  end
  initial begin #10000; $fatal(1,"timeout sent=%0d got=%0d",sent,got); end
endmodule
