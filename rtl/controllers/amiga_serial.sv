// SPDX-License-Identifier: GPL-3.0-or-later
// Fixed USER-port variants for Minimig. No custom Main is required.
// MODE: 1 LLAPI 2P, 2 original Jotego DB15 2P, 3 SNES 2P,
//       4 Mega Drive DB9 1P, 5 NES 2P, 6 Saturn digital 1P.
module amiga_serial #(parameter MODE=1, TICK_CYCLES=500, SCAN_TICKS=250,
                     SETTLE_CYCLES=7500)(
 input clk50,clk_sys,reset,vblank,osd_active,
 input [6:0] user_in, output [6:0] user_out,
 input [15:0] usb1,usb2, output [15:0] joy1,joy2,
 output osd_request
);
 reg [12:0] settle=SETTLE_CYCLES;
 always @(posedge clk50) if(settle!=0) settle<=settle-1'b1;
 wire ready=settle==0;
 wire [15:0] pad1,pad2;
 wire valid1,valid2;
 wire [6:0] drive;
 wire menu1,menu2;
 generate if(MODE==1) begin: llapi
  wire [31:0] b1,b2; wire [7:0] t1,t2;
  wire e1,e2,l1,l2,d1,d2;
  (* async_reg="true" *) reg osd_meta=0,osd_sync=0;
  reg seen1=0,seen2=0;
  always @(posedge clk50) begin
   osd_meta<=osd_active; osd_sync<=osd_meta;
   if(!e1) seen1<=0; else if(t1!=255 && |b1) seen1<=1;
   if(!e2) seen2<=0; else if(t2!=255 && |b2) seen2<=1;
  end
  LLAPI p1(.CLK_50M(clk50),.ENABLE(ready && !osd_sync),.LLAPI_SYNC(vblank),
   .IO_LATCH_IN(user_in[0]),.IO_LATCH_OUT(l1),.IO_DATA_IN(user_in[1]),.IO_DATA_OUT(d1),
   .LLAPI_EN(e1),.LLAPI_TYPE(t1),.LLAPI_MODES(),.LLAPI_BUTTONS(b1),.LLAPI_ANALOG());
  LLAPI p2(.CLK_50M(clk50),.ENABLE(ready && !osd_sync),.LLAPI_SYNC(vblank),
   .IO_LATCH_IN(user_in[4]),.IO_LATCH_OUT(l2),.IO_DATA_IN(user_in[5]),.IO_DATA_OUT(d2),
   .LLAPI_EN(e2),.LLAPI_TYPE(t2),.LLAPI_MODES(),.LLAPI_BUTTONS(b2),.LLAPI_ANALOG());
  function automatic [15:0] map_llapi(input [31:0] b);
   // Common LLAPI face buttons 0..3, R/L 7/6, Start 5.
   map_llapi={5'd0,b[5],b[6],b[7],b[3:0],b[27:24]};
  endfunction
  assign pad1=map_llapi(b1); assign pad2=map_llapi(b2);
  assign menu1=b1[26] && b1[5] && b1[0];
  assign menu2=b2[26] && b2[5] && b2[0];
  assign valid1=ready && e1 && t1!=255 && (t1!=0 || seen1);
  assign valid2=ready && e2 && t2!=255 && (t2!=0 || seen2);
  assign drive={1'b1,d2,l2,1'b1,osd_sync,d1,l1};
 end else if(MODE==2) begin: db15
  wire dc,dl; wire [15:0] a,b;
  joy_db15 reader(.clk(clk50),.JOY_CLK(dc),.JOY_LOAD(dl),.JOY_DATA(user_in[5]),
                  .joystick1(a),.joystick2(b));
  assign pad1={5'd0,a[10],a[9:0]}; assign pad2={5'd0,b[10],b[9:0]};
  assign menu1=a[11] && a[10]; assign menu2=b[11] && b[10];
  assign valid1=ready; assign valid2=ready;
  assign drive={5'h1f,dc,dl};
 end else begin: snac
  amiga_snac #(.MODE(MODE),.TICK_CYCLES(TICK_CYCLES),.SCAN_TICKS(SCAN_TICKS)) reader(
   .clk50(clk50),.enable(ready),.user_in(user_in),.user_out(drive),
   .pad1(pad1),.pad2(pad2),.menu1(menu1),.menu2(menu2));
  assign valid1=ready;
  assign valid2=ready && (MODE==3 || MODE==5);
 end endgenerate
 assign user_out=ready ? drive : 7'h7f;
 // Only the first stages receive CDC exceptions. The two sampling stages
 // remain timed; controller levels change much more slowly than clk_sys.
 (* async_reg="true" *) reg [15:0] p1_meta=0,p1_sync=0,p2_meta=0,p2_sync=0;
 (* async_reg="true" *) reg [3:0] flags_meta=0,flags_sync=0;
 always @(posedge clk_sys) begin
  if(reset) begin p1_meta<=0;p1_sync<=0;p2_meta<=0;p2_sync<=0;flags_meta<=0;flags_sync<=0;end
  else begin
   p1_meta<=pad1;p1_sync<=p1_meta;p2_meta<=pad2;p2_sync<=p2_meta;
   flags_meta<={valid2,valid1,menu2,menu1};flags_sync<=flags_meta;
  end
 end
 assign osd_request=(flags_sync[2] && flags_sync[0]) || (flags_sync[3] && flags_sync[1]);
 wire inhibit=osd_active || osd_request;
 assign joy1=flags_sync[2] ? (inhibit ? 16'd0 : p1_sync) : usb1;
 // A single physical controller reserves P1; USB P1 then fills P2.
 assign joy2=flags_sync[3] ? (inhibit ? 16'd0 : p2_sync) : flags_sync[2] ? usb1 : usb2;
endmodule

module amiga_snac #(parameter MODE=3,TICK_CYCLES=500,SCAN_TICKS=250)(
 input clk50,enable,input [6:0] user_in,output reg [6:0] user_out=7'h7f,
 output reg [15:0] pad1=0,pad2=0,output reg menu1=0,menu2=0
);
 (* async_reg="true" *) reg [6:0] in_meta=7'h7f,in_sync=7'h7f;
 always @(posedge clk50) begin in_meta<=user_in;in_sync<=in_meta;end
 reg [15:0] count=0; reg [8:0] phase=0;
 reg [15:0] sh1=16'hffff,sh2=16'hffff;
 reg [5:0] md_high=6'h3f; reg [1:0] md_as=3;
 reg md_valid=0,md_six=0;reg [3:0] md_extra=15;
 reg [3:0] sat_extra=15,sat_main=15,sat_dir=15;
 wire [5:0] md_in={in_sync[6],in_sync[2],in_sync[3],in_sync[5],in_sync[0],in_sync[1]};
 wire [3:0] sat_in={in_sync[3],in_sync[5],in_sync[0],in_sync[1]};
 function automatic [15:0] serial_map(input [15:0] s);
  begin
   serial_map=0;
   serial_map[3:0]=~{s[4],s[5],s[6],s[7]};
   serial_map[4]=~s[0];serial_map[5]=~s[1];serial_map[10]=~s[3];
   if(MODE==3) begin serial_map[6]=~s[8];serial_map[7]=~s[9];serial_map[8]=~s[11];serial_map[9]=~s[10];end
  end
 endfunction
 always @(posedge clk50) begin
  if(!enable) begin
   count<=0;phase<=0;user_out<=7'h7f;pad1<=0;pad2<=0;menu1<=0;menu2<=0;
   sh1<=16'hffff;sh2<=16'hffff;md_valid<=0;md_six<=0;
  end else if(count==TICK_CYCLES-1) begin
   count<=0;phase<=phase==SCAN_TICKS-1 ? 0 : phase+1'b1;
   if(MODE==3 || MODE==5) begin
    // Official SNES: P1 clock USER1; NES: P1 clock USER3.
    // Both: latch USER0, P1 data USER5, P2 data USER6.
    if(phase<=1) begin user_out<=7'h7f;sh1<=16'hffff;sh2<=16'hffff;end
    if(phase==2) user_out[0]<=0;
    if(phase>=3 && phase<=33 && phase[0]) begin
     sh1[(phase-3)>>1]<=in_sync[5];sh2[(phase-3)>>1]<=in_sync[6];
     user_out[1]<=0;user_out[3]<=0;
    end
    if(phase>=4 && phase<=34 && !phase[0]) begin user_out[1]<=1;user_out[3]<=1;end
    if(phase==35) begin
     // SNES has four released tail bits; NES has eight. Reject a stuck
     // data line instead of treating it as every button being held.
     if((MODE==3 && sh1[15:12]==15) || (MODE==5 && sh1[15:8]==255)) begin
      pad1<=serial_map(sh1);menu1<=!sh1[2] && !sh1[3];end
     else begin pad1<=0;menu1<=0;end
     if((MODE==3 && sh2[15:12]==15) || (MODE==5 && sh2[15:8]==255)) begin
      pad2<=serial_map(sh2);menu2<=!sh2[2] && !sh2[3];end
     else begin pad2<=0;menu2<=0;end
    end
   end else if(MODE==4) begin
    case(phase)
     0:begin user_out<=7'h6f;md_six<=0;md_extra<=15;end
     1:user_out[4]<=1;
     2:begin md_high<=md_in;user_out[4]<=0;end
     3:begin md_as<=md_in[5:4];md_valid<=md_in[3:2]==0;user_out[4]<=1;end
     4:user_out[4]<=0;
     5:begin md_six<=md_in[3:0]==0;user_out[4]<=1;end
     6:begin md_extra<=md_in[3:0];user_out[4]<=0;end
     7:begin
      user_out[4]<=1;pad1<=0;menu1<=0;
      if(md_valid) begin
       pad1[3:0]<=~{md_high[0],md_high[1],md_high[2],md_high[3]};
       pad1[6:4]<=~{md_as[0],md_high[5],md_high[4]}; // A,C,B
       pad1[10]<=~md_as[1];
       if(md_six) begin pad1[7]<=~md_extra[2];pad1[8]<=~md_extra[0];pad1[9]<=~md_extra[1];end
       menu1<=!md_high[1] && !md_as[1] && !md_high[4];
      end
     end
    endcase
   end else if(MODE==6) begin
    case(phase)
     0:user_out<=7'h2f;
     1:begin sat_extra<=sat_in;user_out[4]<=1;end
     2:begin sat_main<=sat_in;user_out[4]<=0;user_out[6]<=1;end
     3:begin sat_dir<=sat_in;user_out[4]<=1;end
     4:begin
      pad1<=0;menu1<=0;
      if(sat_in[2:0]==3'b100) begin
       pad1[3:0]<=~{sat_dir[0],sat_dir[1],sat_dir[2],sat_dir[3]};
       pad1[6:4]<=~{sat_main[2],sat_main[1],sat_main[0]}; // A,C,B
       pad1[7]<=~sat_extra[2];pad1[8]<=~sat_extra[3];pad1[9]<=~sat_in[3];
       pad1[10]<=~sat_main[3];menu1<=!sat_dir[1] && !sat_main[3] && !sat_main[0];
      end
     end
    endcase
   end
  end else count<=count+1'b1;
 end
endmodule
