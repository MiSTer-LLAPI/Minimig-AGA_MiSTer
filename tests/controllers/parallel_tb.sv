`timescale 1ns/1ps
module parallel_case #(parameter MODE=4)(output reg done=0);
 reg clk=0;always #10 clk=~clk;
 reg enable=0;wire [1:0] mode=MODE==4 ? 2 : 3;
 wire [6:0] pins;wire [15:0] pad,pad2;wire menu,menu2;
 reg unplug=0,six=0;reg [15:0] snes_pressed=0;integer snes_bit=0;
 reg [5:0] md_pressed=0;reg [1:0] md_as_pressed=0;
 reg [3:0] md_extra_pressed=0;integer md_count=0,idle=0;
 reg [3:0] sat_main_pressed=0,sat_dir_pressed=0,sat_extra_pressed=0;
 reg sat_l=0;reg [6:0] input_pins;
 amiga_snac #(.MODE(MODE),.TICK_CYCLES(8),.SCAN_TICKS(80)) dut(
  .clk50(clk),.enable(enable),.user_in(input_pins),.user_out(pins),
  .pad1(pad),.pad2(pad2),.menu1(menu),.menu2(menu2));
    // Independent pin-level controller models, active-low electrical inputs.
    always @(negedge pins[0]) snes_bit=0;
    always @(negedge pins[1]) if(mode==1 && !pins[0] && snes_bit<15) snes_bit=snes_bit+1;
    always @(negedge pins[4]) if(mode==2) md_count=md_count+1;
    always @(posedge clk) begin
        if(mode!=2 || !enable) begin idle=0;md_count=0;end
        else if(pins[4]) begin
            idle=idle+1;
            if(idle>100) md_count=0;
        end else idle=0;
    end
    reg [5:0] md_data;
    reg [3:0] sat_data;
    always @* begin
        input_pins=7'h7f;
        md_data=~md_pressed;
        if(!pins[4]) begin
            md_data={~md_as_pressed,2'b00,~md_pressed[1:0]};
            if(six && md_count==3) md_data[3:0]=0;
        end else if(six && md_count==3) md_data={2'b11,~md_extra_pressed};
        case({pins[6],pins[4]})
            0: sat_data=~sat_extra_pressed;
            1: sat_data=~sat_main_pressed;
            2: sat_data=~sat_dir_pressed;
            3: sat_data={~sat_l,3'b100};
        endcase
        if(mode==1) input_pins[5]=pins[0] ? ~snes_pressed[0] : ~snes_pressed[snes_bit];
        if(mode==2) begin
            input_pins[6]=md_data[5];input_pins[2]=md_data[4];
            input_pins[3]=md_data[3];input_pins[5]=md_data[2];
            input_pins[0]=md_data[1];input_pins[1]=md_data[0];
        end
        if(mode==3) begin
            begin
                input_pins[3]=sat_data[3];input_pins[5]=sat_data[2];
                input_pins[0]=sat_data[1];input_pins[1]=sat_data[0];
            end
        end
        if(unplug) input_pins=7'h7f;
    end

 task scan;begin repeat(1500) @(negedge clk);end endtask
 task check(input [15:0] v);begin
  if(pad!==v || pad2 || menu2) $fatal(1,"mode %d expected %h got %h/%h",MODE,v,pad,pad2);
 end endtask
 integer i;
 initial begin
  repeat(10) @(negedge clk);if(pins!==7'h7f || pad) $fatal(1,"disabled output");
  enable=1;scan();check(0);
  if(MODE==4) begin
   for(i=0;i<6;i=i+1) begin
    md_pressed=1<<i;scan();case(i)
     0:check(8);1:check(4);2:check(2);3:check(1);4:check(16);5:check(32);
    endcase
   end
   md_pressed=0;md_as_pressed=1;scan();check(64);
   md_as_pressed=2;scan();check(1024);
   md_as_pressed=0;six=1;
   for(i=0;i<3;i=i+1) begin md_extra_pressed=1<<i;scan();case(i)
    0:check(256);1:check(512);2:check(128);endcase end
   md_extra_pressed=0;md_pressed=18;md_as_pressed=2;scan();if(!menu) $fatal(1,"MD OSD");
  end else begin
   for(i=0;i<4;i=i+1) begin
    sat_dir_pressed=1<<i;scan();case(i) 0:check(8);1:check(4);2:check(2);3:check(1);endcase
   end
   sat_dir_pressed=0;
   for(i=0;i<4;i=i+1) begin
    sat_main_pressed=1<<i;scan();case(i) 0:check(16);1:check(32);2:check(64);3:check(1024);endcase
   end
   sat_main_pressed=0;sat_extra_pressed=4;scan();check(128);
   sat_extra_pressed=8;scan();check(256);
   sat_extra_pressed=0;sat_l=1;scan();check(512);
   sat_l=0;sat_dir_pressed=2;sat_main_pressed=9;scan();if(!menu) $fatal(1,"Saturn OSD");
  end
  unplug=1;scan();check(0);if(menu) $fatal(1,"stale menu");
  enable=0;repeat(5) @(negedge clk);if(pins!==7'h7f || pad || menu) $fatal(1,"disabled release");
  $display("PASS parallel MODE=%0d pin-level buttons, handshake, disconnect, menu",MODE);done=1;
 end
endmodule
module parallel_tb;
 wire a,b;parallel_case #(.MODE(4)) md(a);parallel_case #(.MODE(6)) sat(b);
 initial begin wait(a&&b);$finish;end
 initial begin #3000000;$fatal(1,"timeout");end
endmodule
