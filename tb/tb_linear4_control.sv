`timescale 1ns/1ps
module tb_linear4_control;
  localparam N0=256,N1=80;
  reg clk=0;always #5 clk=~clk;
  reg rst_n=0,in_valid=0,out_ready=1;reg [15:0] in_id=0;reg [63:0] in_payload=0;
  wire in_ready,out_valid;wire [15:0] out_id;wire [63:0] out_payload;
  wire [31:0] ac,rc,isc,s0sc,s1sc,s2sc,s3sc;
  reg [15:0] exp_id[0:1023];reg [63:0] exp_payload[0:1023];
  integer cycle=0,sent=0,got=0,last_acc=-1,last_ret=-1,min_acc_gap=999,min_ret_gap=999,gap;
  integer i,watchdog,phase=0;reg was_stalled=0;reg [15:0] stalled_id;reg [63:0] stalled_payload;
  fp32_linear4_control dut(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_id(in_id),.in_payload(in_payload),.out_valid(out_valid),.out_ready(out_ready),
    .out_id(out_id),.out_payload(out_payload),.accepted_count(ac),.retired_count(rc),
    .input_stall_count(isc),.s0_stall_count(s0sc),.s1_stall_count(s1sc),.s2_stall_count(s2sc),.s3_stall_count(s3sc));
  always @(posedge clk) begin
    if(!rst_n) cycle=0;
    else begin
      cycle=cycle+1;
      if(in_valid&&!in_ready) begin
        if(was_stalled&&(in_id!==stalled_id||in_payload!==stalled_payload))$fatal(1,"source changed while stalled");
        was_stalled=1;stalled_id=in_id;stalled_payload=in_payload;
      end else was_stalled=0;
      if(in_valid&&in_ready) begin
        if(last_acc>=0) begin gap=cycle-last_acc;if(gap<min_acc_gap)min_acc_gap=gap;
          if(phase==0&&gap!=1)$fatal(1,"II_acc gap=%0d",gap);end
        last_acc=cycle;exp_id[sent]=in_id;exp_payload[sent]=in_payload;sent=sent+1;
      end
      if(out_valid&&out_ready) begin
        if(got>=sent)$fatal(1,"retirement without acceptance");
        if(out_id!==exp_id[got]||out_payload!==exp_payload[got])$fatal(1,"ordering/payload mismatch index=%0d",got);
        if(last_ret>=0) begin gap=cycle-last_ret;if(gap<min_ret_gap)min_ret_gap=gap;
          if(phase==0&&gap!=1)$fatal(1,"II_ret gap=%0d",gap);end
        last_ret=cycle;got=got+1;
      end
    end
  end
  task send_one(input [15:0] id,input [63:0] payload);
    reg done;
    begin @(negedge clk);in_valid=1;in_id=id;in_payload=payload;done=0;
      while(!done) begin @(posedge clk);if(in_valid&&in_ready)done=1;else @(negedge clk);end
    end
  endtask
  initial begin
    repeat(4)@(negedge clk);rst_n=1;phase=0;out_ready=1;
    fork
      begin for(i=0;i<N0;i=i+1)send_one(i[15:0],64'hd1b54a32d192ed03^i);@(negedge clk);in_valid=0;end
      begin watchdog=0;while(got<N0&&watchdog<4000)begin @(negedge clk);watchdog=watchdog+1;end
        if(got<N0)$fatal(1,"phase0 timeout");end
    join
    if(sent!=N0||got!=N0||ac!=N0||rc!=N0||min_acc_gap!=1||min_ret_gap!=1)$fatal(1,"phase0 counters/II failed");
    $display("PASS phase0 CONTROL: contexts=%0d II_acc=1 II_ret=1",N0);
    rst_n=0;in_valid=0;out_ready=1;repeat(3)@(negedge clk);rst_n=1;
    sent=0;got=0;last_acc=-1;last_ret=-1;min_acc_gap=999;min_ret_gap=999;phase=1;was_stalled=0;
    fork
      begin for(i=0;i<N1;i=i+1)send_one(16'd1000+i,64'h94d049bb133111eb^(i*32'h101));@(negedge clk);in_valid=0;end
      begin repeat(2)@(negedge clk);while(got<N1)begin out_ready=0;repeat(3)@(negedge clk);out_ready=1;repeat(4)@(negedge clk);end end
      begin watchdog=0;while(got<N1&&watchdog<5000)begin @(negedge clk);watchdog=watchdog+1;end
        if(got<N1)$fatal(1,"phase1 timeout");end
    join
    if(sent!=N1||got!=N1||ac!=N1||rc!=N1)$fatal(1,"phase1 counts failed");
    if((s0sc+s1sc+s2sc+s3sc)==0)$fatal(1,"backpressure not observed");
    $display("PASS phase1 CONTROL: contexts=%0d backpressure; input_stalls=%0d stage_stalls=%0d/%0d/%0d/%0d",N1,isc,s0sc,s1sc,s2sc,s3sc);
    $finish;
  end
endmodule
