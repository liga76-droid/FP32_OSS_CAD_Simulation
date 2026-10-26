`timescale 1ns/1ps
module tb_sigmul_linear4;
  localparam N=10000;
  reg clk=0;always #5 clk=~clk;
  reg rst_n=0,in_valid=0,out_ready=1;reg [15:0] in_id=0;reg [23:0] sig_a=0,sig_b=0;
  wire in_ready,out_valid;wire [15:0] out_id;wire [47:0] product;
  reg [47:0] expected[0:N-1];reg [15:0] expected_id[0:N-1];
  integer sent=0,got=0,cycle=0,last_acc=-1,last_ret=-1,gap,i,watchdog;
  reg [31:0] seed=32'h1234abcd;
  fp32_sigmul_linear4 dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_id(in_id),.sig_a(sig_a),.sig_b(sig_b),.out_valid(out_valid),.out_ready(out_ready),
    .out_id(out_id),.product(product));
  always @(posedge clk) begin
    if(!rst_n)cycle=0;
    else begin
      cycle=cycle+1;
      if(in_valid&&in_ready) begin
        expected[sent]={24'b0,sig_a}*{24'b0,sig_b};expected_id[sent]=in_id;
        if(last_acc>=0&&cycle-last_acc!=1)$fatal(1,"sigmul II_acc not 1 gap=%0d",cycle-last_acc);
        last_acc=cycle;sent=sent+1;
      end
      if(out_valid&&out_ready) begin
        if(got>=sent)$fatal(1,"sigmul retire without accept");
        if(out_id!==expected_id[got])$fatal(1,"sigmul ID/order mismatch index=%0d",got);
        if(product!==expected[got])$fatal(1,"sigmul product mismatch index=%0d a/b expected=%h got=%h",got,expected[got],product);
        if(last_ret>=0&&cycle-last_ret!=1)$fatal(1,"sigmul II_ret not 1 gap=%0d",cycle-last_ret);
        last_ret=cycle;got=got+1;
      end
    end
  end
  task send_one(input [23:0] a,input [23:0] b,input [15:0] id);
    reg done;
    begin @(negedge clk);in_valid=1;sig_a=a;sig_b=b;in_id=id;done=0;
      while(!done)begin @(posedge clk);if(in_valid&&in_ready)done=1;else @(negedge clk);end
    end
  endtask
  initial begin
    repeat(4)@(negedge clk);rst_n=1;
    fork
      begin
        send_one(24'hffffff,24'hffffff,0);
        send_one(24'h800000,24'h800000,1);
        send_one(24'hffffff,24'h000001,2);
        send_one(24'h000000,24'hffffff,3);
        for(i=4;i<N;i=i+1)begin
          seed=seed*32'd1664525+32'd1013904223;sig_a=seed[23:0];
          seed=seed*32'd1664525+32'd1013904223;sig_b=seed[23:0];
          send_one(sig_a,sig_b,i[15:0]);
        end
        @(negedge clk);in_valid=0;
      end
      begin watchdog=0;while(got<N&&watchdog<30000)begin @(negedge clk);watchdog=watchdog+1;end
        if(got<N)$fatal(1,"sigmul timeout sent=%0d got=%0d",sent,got);end
    join
    if(sent!=N||got!=N)$fatal(1,"sigmul count mismatch sent=%0d got=%0d",sent,got);
    $display("PASS SIGMUL DUT: %0d exact 24x24 products; II_acc=1, II_ret=1; ordered IDs.",N);
    $display("LIMIT: significand product only; no exponent, Z alignment, GRS, rounding or IEEE special cases.");
    $finish;
  end
endmodule
