`timescale 1ns/1ps
module tb_partial_product_scheduler;
  localparam N=5000;
  reg clk=0;always #5 clk=~clk;
  reg rst_n=0,in_valid=0,out_ready=1;
  reg [15:0] in_context_id=0;reg [23:0] sig_a=0,sig_b=0;
  wire in_ready,out_valid;wire [15:0] out_context_id;wire [47:0] product;
  wire [8:0] unique_valid,unique_commit;wire [3:0] sv,sr;
  reg [47:0] expected[0:N-1];reg [15:0] ids[0:N-1];
  integer sent=0,got=0,cycle=0,lasta=-1,lastr=-1,i,watchdog;
  reg [31:0] seed=32'h7f4a7c15;
  partial_product_scheduler dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_context_id(in_context_id),.sig_a(sig_a),.sig_b(sig_b),.out_valid(out_valid),.out_ready(out_ready),
    .out_context_id(out_context_id),.product(product),.unique_valid(unique_valid),.unique_commit(unique_commit),
    .stage_valid_dbg(sv),.stage_ready_dbg(sr));
  always @(posedge clk) if(rst_n) begin
    cycle=cycle+1;
    if(in_valid&&in_ready) begin
      expected[sent]={24'b0,sig_a}*{24'b0,sig_b};ids[sent]=in_context_id;
      if(lasta>=0&&cycle-lasta!=1)$fatal(1,"scheduler II_acc gap=%0d",cycle-lasta);
      lasta=cycle;sent=sent+1;
    end
    if(out_valid&&out_ready) begin
      if(got>=sent)$fatal(1,"scheduler retired unaccepted context");
      if(out_context_id!==ids[got])$fatal(1,"scheduler context ordering error index=%0d",got);
      if(product!==expected[got])$fatal(1,"nine-partial product mismatch id=%0d expected=%h got=%h",out_context_id,expected[got],product);
      if(unique_valid!==9'h1ff||unique_commit!==9'h1ff)$fatal(1,"partial provenance/commit mask incomplete");
      if(lastr>=0&&cycle-lastr!=1)$fatal(1,"scheduler II_ret gap=%0d",cycle-lastr);
      lastr=cycle;got=got+1;
    end
  end
  task send_one(input [23:0] a,input [23:0] b,input [15:0] id);
    reg done;
    begin @(negedge clk);in_valid=1;sig_a=a;sig_b=b;in_context_id=id;done=0;
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
        for(i=3;i<N;i=i+1)begin
          seed=seed*32'd1664525+32'd1013904223;sig_a=seed[23:0];
          seed=seed*32'd1664525+32'd1013904223;sig_b=seed[23:0];
          send_one(sig_a,sig_b,i[15:0]);
        end
        @(negedge clk);in_valid=0;
      end
      begin watchdog=0;while(got<N&&watchdog<30000)begin @(negedge clk);watchdog=watchdog+1;end
        if(got<N)$fatal(1,"scheduler timeout sent=%0d got=%0d",sent,got);end
    join
    if(sent!=N||got!=N)$fatal(1,"scheduler count mismatch sent=%0d got=%0d",sent,got);
    $display("PASS NINE-PARTIAL REFERENCE: %0d exact products; II_acc=1, II_ret=1; context/provenance checked.",N);
    $display("LIMIT: literal schedule windows tracked, but packed 16x16 schedule mapping not yet proven.");
    $finish;
  end
endmodule
