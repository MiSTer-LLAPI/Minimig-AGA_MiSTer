`timescale 1ns/1ps
module db15_tb;
 reg clk=0,sys=0;always #10 clk=~clk;always #13 sys=~sys;
 wire [6:0] pins;wire [15:0] a,b;wire menu;
 reg [23:0] word=24'hffffff,serial=24'hffffff;
 always @(negedge pins[0]) serial<=word;
 always @(posedge pins[1]) if(!pins[0]) serial<=word;else serial<={1'b1,serial[23:1]};
 amiga_serial #(.MODE(2),.SETTLE_CYCLES(20)) dut(.clk50(clk),.clk_sys(sys),.reset(1'b0),
  .vblank(1'b0),.osd_active(1'b0),.user_in({1'b1,serial[0],5'b11111}),.user_out(pins),
  .usb1(16'd0),.usb2(16'd0),.joy1(a),.joy2(b),.osd_request(menu));
 task scan;begin repeat(15000) @(negedge clk);end endtask
 integer i;integer bitpos;reg [15:0] expected;
 initial begin
  scan();if(a||b||menu) $fatal(1,"DB15 idle");
  for(i=0;i<24;i=i+1) begin
   word=~(24'd1<<i);scan();expected=0;
   case(i)
    0:expected=16'h80;1:expected=16'h40;2:expected=16'h20;3:expected=16'h10;
    4,8:expected=1;5,9:expected=2;6,10:expected=4;7,11:expected=8;
    12,16:expected=16'h200;13,17:expected=16'h100;15,19:expected=16'h400;
    20:expected=16'h80;21:expected=16'h40;22:expected=16'h20;23:expected=16'h10;
   endcase
   if(i<8 || (i>=12 && i<=15)) begin
    if(a!==expected || b || menu) $fatal(1,"DB15 P1 bit%0d a=%h b=%h",i,a,b);
   end else if(b!==expected || a || menu) $fatal(1,"DB15 P2 bit%0d a=%h b=%h",i,a,b);
  end
  word=~((24'd1<<18)|(24'd1<<19));scan();if(!menu||a||b) $fatal(1,"DB15 P2 Select+Start OSD");
  $display("PASS original DB15 24-bit chain, full Amiga mappings both players, menu");$finish;
 end
endmodule
