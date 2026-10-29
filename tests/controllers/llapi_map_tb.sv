`timescale 1ns/1ps
module llapi_map_tb;
 reg clk=0,sys=0;always #10 clk=~clk;always #13 sys=~sys;
 reg reset=0,osd=0;reg [31:0] a=0,b=0;reg e1=0,e2=0;
 wire [15:0] j1,j2;wire menu;wire [6:0] pins;
 amiga_serial #(.MODE(1),.SETTLE_CYCLES(20)) dut(.clk50(clk),.clk_sys(sys),.reset(reset),
 .vblank(1'b0),.osd_active(osd),.user_in(7'h7f),.user_out(pins),
 .usb1(16'h0101),.usb2(16'h0202),.joy1(j1),.joy2(j2),.osd_request(menu));
 task settle;begin repeat(100) @(negedge clk);end endtask
 integer i;reg [15:0] v;
 initial begin
  // Inject decoded protocol packets to verify mapping and CDC independently
  // of the unchanged MIT LLAPI wire protocol engine.
  force dut.llapi.b1=a;force dut.llapi.b2=b;force dut.llapi.t1=8'd27;force dut.llapi.t2=8'd27;
  force dut.llapi.e1=e1;force dut.llapi.e2=e2;
  settle();if(j1!==16'h101 || j2!==16'h202) $fatal(1,"USB fallback");
  e1=1;settle();if(j1 || j2!==16'h101) $fatal(1,"single LLAPI fallback");
  e2=1;settle();if(j1 || j2) $fatal(1,"dual LLAPI idle");
  for(i=0;i<32;i=i+1) begin
   a=32'd1<<i;b=0;v=0;
   case(i) 0:v=16'h10;1:v=16'h20;2:v=16'h40;3:v=16'h80;
    5:v=16'h400;6:v=16'h200;7:v=16'h100;
    24:v=1;25:v=2;26:v=4;27:v=8;endcase
   settle();if(j1!==v || j2) $fatal(1,"LLAPI P1 bit%0d j=%h",i,j1);
   b=a;a=0;settle();if(j2!==v || j1) $fatal(1,"LLAPI P2 bit%0d j=%h",i,j2);
  end
  a=0;b=(1<<26)|(1<<5)|1;settle();if(!menu || j1 || j2) $fatal(1,"P2 OSD inhibit");
  b=0;a=1;osd=1;settle();if(j1 || j2) $fatal(1,"OSD active");
  osd=0;e1=0;e2=0;settle();if(j1!==16'h101 || j2!==16'h202) $fatal(1,"disconnect");
  $display("PASS LLAPI decoded packets, all mappings both players, USB fallback, CDC, OSD");$finish;
 end
endmodule
