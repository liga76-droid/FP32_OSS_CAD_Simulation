`timescale 1ns/1ps
module tb_fma_ieee_diff;
  parameter N = 100000;
  reg clk=0; always #5 clk=~clk;
  reg rst_n=0, in_valid=0, out_ready=1;
  reg [15:0] in_id=0;
  reg [31:0] a=0,b=0,z=0;
  wire in_ready,out_valid;
  wire [15:0] out_id;
  wire [31:0] result;
  wire flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact;
  reg [31:0] va[0:N-1], vb[0:N-1], vz[0:N-1], vr[0:N-1];
  reg [4:0] vf[0:N-1];
  integer fd, rc, loaded=0, sent=0, got=0, i, watchdog=0;
  reg [31:0] fa,fb,fz,fr;
  reg [7:0] ff;
  reg [31:0] mismatch_count=0;
  reg [31:0] nan_mismatch_count=0;
  reg [31:0] flag_mismatch_count=0;
  reg [31:0] first_bad_a,first_bad_b,first_bad_z,first_bad_got,first_bad_ref;
  reg [4:0] first_bad_flags,first_bad_ref_flags;
  reg first_bad_valid=0;

  fp32_fma_ieee dut(
    .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),
    .in_id(in_id),.a(a),.b(b),.z(z),.out_valid(out_valid),
    .out_ready(out_ready),.out_id(out_id),.result(result),
    .flag_invalid(flag_invalid),.flag_divzero(flag_divzero),
    .flag_overflow(flag_overflow),.flag_underflow(flag_underflow),
    .flag_inexact(flag_inexact)
  );

  function is_nan(input [31:0] x);
    begin is_nan=(x[30:23]==8'hff)&&(x[22:0]!=0); end
  endfunction

  initial begin
    fd=$fopen("build/fma_vectors.hex","r");
    if(!fd) begin $display("ERROR: cannot open build/fma_vectors.hex"); $fatal(1); end
    while (!$feof(fd) && loaded<N) begin
      rc=$fscanf(fd,"%h %h %h %h %h\n",fa,fb,fz,fr,ff);
      if(rc==5) begin
        va[loaded]=fa; vb[loaded]=fb; vz[loaded]=fz; vr[loaded]=fr;
        vf[loaded]=ff[4:0]; loaded=loaded+1;
      end else if (!$feof(fd)) begin
        $display("ERROR: malformed vector file at row %0d rc=%0d",loaded,rc); $fatal(1);
      end
    end
    $fclose(fd);
    if(loaded!=N) begin $display("ERROR: expected %0d vectors, loaded %0d",N,loaded); $fatal(1); end

    repeat(4) @(negedge clk);
    rst_n=1;

    fork
      begin : driver
        for(i=0;i<N;i=i+1) begin
          @(negedge clk);
          in_valid=1; in_id=i[15:0]; a=va[i]; b=vb[i]; z=vz[i];
          do @(posedge clk); while(!in_ready);
          sent=sent+1;
        end
        @(negedge clk); in_valid=0;
      end
      begin : monitor
        while(got<N && watchdog<2000000) begin
          @(posedge clk); watchdog=watchdog+1;
          if(out_valid && out_ready) begin
            if(out_id !== got[15:0]) begin
              $display("FAIL ID/order expected=%0d got=%0d",got,out_id); $fatal(1);
            end
            if ({flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact} !== vf[got]) begin
              flag_mismatch_count=flag_mismatch_count+1;
              if(!first_bad_valid) begin
                first_bad_a=va[got]; first_bad_b=vb[got]; first_bad_z=vz[got];
                first_bad_got=result; first_bad_ref=vr[got];
                first_bad_flags={flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact};
                first_bad_ref_flags=vf[got]; first_bad_valid=1;
              end
            end
            /* NaN payload selection is implementation-dependent: compare class,
               while still comparing all exception flags exactly. */
            if(is_nan(vr[got])) begin
              if(!is_nan(result)) nan_mismatch_count=nan_mismatch_count+1;
            end else if(result !== vr[got]) begin
              mismatch_count=mismatch_count+1;
              if(!first_bad_valid) begin
                first_bad_a=va[got]; first_bad_b=vb[got]; first_bad_z=vz[got];
                first_bad_got=result; first_bad_ref=vr[got];
                first_bad_flags={flag_invalid,flag_divzero,flag_overflow,flag_underflow,flag_inexact};
                first_bad_ref_flags=vf[got]; first_bad_valid=1;
              end
            end
            got=got+1;
          end
        end
      end
    join
    if(got!=N) begin $display("FAIL timeout sent=%0d got=%0d",sent,got); $fatal(1); end
    $display("FMA_DIFF vectors=%0d result_mismatches=%0d nan_class_mismatches=%0d flag_mismatches=%0d",
             N,mismatch_count,nan_mismatch_count,flag_mismatch_count);
    if(first_bad_valid)
      $display("FIRST_MISMATCH a=%h b=%h z=%h rtl=%h ref=%h rtl_flags=%b ref_flags=%b",
        first_bad_a,first_bad_b,first_bad_z,first_bad_got,first_bad_ref,
        first_bad_flags,first_bad_ref_flags);
    if(mismatch_count || nan_mismatch_count || flag_mismatch_count) $fatal(1,"IEEE FMA differential mismatch");
    $display("PASS IEEE FMA differential comparison: %0d vectors; result bits (NaN class) and flags matched.",N);
    $finish;
  end
endmodule
