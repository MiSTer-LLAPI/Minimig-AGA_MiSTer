`timescale 1ns/1ps
module serial_case #(parameter MODE=3)(output reg done=0);
 reg clk=0;always #10 clk=~clk;
 wire [6:0] pins;reg [15:0] word1=16'hffff,word2=16'hffff;
 reg [15:0] sh1=16'hffff,sh2=16'hffff;
 wire [6:0] data={sh2[0],sh1[0],5'b11111};
 wire [15:0] p1,p2;wire m1,m2;
 amiga_snac #(.MODE(MODE),.TICK_CYCLES(8),.SCAN_TICKS(40)) dut(
  .clk50(clk),.enable(1'b1),.user_in(data),.user_out(pins),
  .pad1(p1),.pad2(p2),.menu1(m1),.menu2(m2));
 // Independent serial shift-register controller models; sample before
 // falling clock edges, advance output on those edges.
 always @(posedge pins[0]) begin sh1<=word1;sh2<=word2;end
 always @(negedge pins[0]) begin sh1<=word1;sh2<=word2;end
 always @(negedge pins[MODE==3 ? 1 : 3]) if(!pins[0]) sh1<={1'b1,sh1[15:1]};
 always @(negedge pins[MODE==3 ? 3 : 1]) if(!pins[0]) sh2<={1'b1,sh2[15:1]};
 task scan;begin repeat(900) @(negedge clk);end endtask
 function [15:0] expected(input integer n);
  begin expected=0;
   case(n)
    0:expected=16'h10;1:expected=16'h20;3:expected=16'h400;
    4:expected=8;5:expected=4;6:expected=2;7:expected=1;
    8:if(MODE==3) expected=16'h40;
    9:if(MODE==3) expected=16'h80;
    10:if(MODE==3) expected=16'h200;
    11:if(MODE==3) expected=16'h100;
   endcase
  end
 endfunction
 integer i;
 initial begin
  scan();if(p1 || p2 || m1 || m2) $fatal(1,"serial idle mode %d",MODE);
  for(i=0;i<(MODE==3?12:8);i=i+1) begin
   word1=~(16'd1<<i);word2=16'hffff;scan();
   if(p1!==expected(i) || p2 || m1 || m2) $fatal(1,"mode %d P1 bit %d got %h/%h",MODE,i,p1,p2);
   word1=16'hffff;word2=~(16'd1<<i);scan();
   if(p2!==expected(i) || p1 || m1 || m2) $fatal(1,"mode %d P2 bit %d got %h/%h",MODE,i,p1,p2);
  end
  word1=16'hfffe;word2=16'hfff7;scan();
  if(p1!==16'h10 || p2!==16'h400) $fatal(1,"independent players");
  word2=16'hffff;scan();if(p1!==16'h10 || p2) $fatal(1,"P2 release alters P1");
  word1=16'hffff;word2=16'hfff3;scan();if(m1 || !m2) $fatal(1,"P2 menu");
  word1=0;word2=0;scan();if(p1 || p2 || m1 || m2) $fatal(1,"stuck lines rejected");
  $display("PASS serial MODE=%0d independent players, all buttons, menu, stuck lines",MODE);done=1;
 end
endmodule
module serial_tb;
 wire a,b;serial_case #(.MODE(3)) snes(a);serial_case #(.MODE(5)) nes(b);
 initial begin wait(a&&b);$finish;end
 initial begin #3000000;$fatal(1,"timeout");end
endmodule
