`default_nettype none

module async_fifo
  #(parameter WIDTH=4,
    parameter DEPTH=4)
  (input logic rst,
   input logic wclk, we,
   output logic full,
   input logic[WIDTH-1:0] wdata,
   input logic rclk, re,
   output logic empty,
   output logic[WIDTH-1:0] rdata);

  parameter PTR_WIDTH = $clog2(DEPTH)+1;

  logic [PTR_WIDTH-1:0] wptr, wptr_gray, rptr, rptr_gray;
  logic [DEPTH-1:0][WIDTH-1:0] data;

  always_ff @(posedge wclk)
    if(we & ~full)
      data[wptr[PTR_WIDTH-2:0]] <= wdata;
  assign rdata = data[rptr[PTR_WIDTH-2:0]];

  write_half #(PTR_WIDTH) frontend
    (.rst, .wclk, .we,
     .rptr_gray,
     .wptr, .wptr_gray,
     .full);

  read_half #(PTR_WIDTH) backend
    (.rst, .rclk, .re,
     .wptr_gray,
     .rptr, .rptr_gray,
     .empty);
endmodule: async_fifo

module read_half
  #(parameter PTR_WIDTH)
  (input logic rst, rclk, re,
   input logic [PTR_WIDTH-1:0] wptr_gray,
   output logic [PTR_WIDTH-1:0] rptr, rptr_gray,
   output logic empty);

  logic [PTR_WIDTH-1:0] wptr_gray1, wptr_gray2, wptr_bin;

  always_ff @(posedge rclk, posedge rst)
    if(rst) begin
      rptr <= '0;
    end
    else if(re && ~empty) begin
      rptr <= rptr + (PTR_WIDTH-1)'(1);
    end

  always_ff @(posedge rclk, posedge rst)
    if(rst)
      {wptr_gray1, wptr_gray2} <= '0;
    else
      {wptr_gray1, wptr_gray2} <= {wptr_gray, wptr_gray1};

  bin2gray #(PTR_WIDTH) rptr_b2g
    (.binary(rptr), .gray(rptr_gray));

  assign empty = wptr_gray2 == rptr_gray;
endmodule

module write_half
  #(parameter PTR_WIDTH)
  (input logic rst, wclk, we,
   input logic [PTR_WIDTH-1:0] rptr_gray,
   output logic [PTR_WIDTH-1:0] wptr, wptr_gray,
   output logic full);

  logic [PTR_WIDTH-1:0] rptr_gray1, rptr_gray2, rptr_bin;

  always_ff @(posedge wclk, posedge rst)
    if(rst)
      wptr <= '0;
    else if(we && ~full)
      wptr <= wptr + (PTR_WIDTH-1)'(1);

  always_ff @(posedge wclk, posedge rst)
    if(rst)
      {rptr_gray1, rptr_gray2} <= '0;
    else
      {rptr_gray1, rptr_gray2} <= {rptr_gray, rptr_gray1};

  bin2gray #(PTR_WIDTH) wptr_b2g
    (.binary(wptr), .gray(wptr_gray));

   assign full = rptr_gray2[PTR_WIDTH-1:PTR_WIDTH-2] == ~wptr_gray[PTR_WIDTH-1:PTR_WIDTH-2]
                 && rptr_gray2[PTR_WIDTH-3:0] == wptr_gray[PTR_WIDTH-3:0];
endmodule

module gray2bin
  #(parameter WIDTH)
  (input logic[WIDTH-1:0] gray,
   output logic[WIDTH-1:0] binary);

  generate for(genvar i = 0; i < WIDTH-1; i++)
    assign binary[i] = gray[i] ^ binary[i+1];
  endgenerate
  assign binary[WIDTH-1] = gray[WIDTH-1];
endmodule // gray2bin

module bin2gray
  #(parameter WIDTH)
  (input logic[WIDTH-1:0] binary,
   output logic [WIDTH-1:0] gray);

  assign gray = binary ^ (binary >> 1);
endmodule // bin2gray

module gray2bin_test;

  logic [3:0] gray, binary_out;
  gray2bin #(4) DUT (.gray, .binary(binary_out));

  initial begin
    for(int i = 0; i < 16; i++) begin
      gray = 4'(i) ^ (4'(i) >> 1);
      #1 test_decode: assert(binary_out == 4'(i)) else
        $display("bin=%b gray=%b, got=%b", i, gray, binary_out);
    end
    #10 $finish;
  end // initial begin
endmodule // gray2bin_test

module async_fifo_test;
  parameter WIDTH=4;
  parameter DEPTH=4;

  logic [WIDTH-1:0] q[$];

  logic rst;
  logic wclk, we;
  logic full;
  logic[WIDTH-1:0] wdata;
  logic rclk, re;
  logic empty;
  logic[WIDTH-1:0] rdata;
  int wval,rval, vals_written, vals_read;
  logic rdone, wdone;

  async_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) DUT(.*);

  initial begin
    rclk = '0;
    forever #5 rclk = ~rclk;
  end

  initial begin
    wclk = '0;
    rst = '1;
    #10 rst = '0;
    forever #5 wclk = ~wclk;
  end

  parameter VALS=16;
  initial begin
    wdone = '0;
    vals_written = 0;
    wval = $urandom(240);
    we = '0;
    @(posedge wclk);
    while(vals_written < VALS) begin
      #1;
      if(~full) begin
        we <= '1;
        wval = vals_written % (2**WIDTH);// $urandom() % (2**WIDTH);
        wdata <= wval;
        q.push_front(wval);
        // vals_written++;
      end else begin
        we <= '0;
      end
      @(posedge wclk);
      if(we) vals_written++;

    end
    @(posedge wclk);
    we <= '0;
    repeat(10) @(posedge wclk);
    wdone <= '1;
  end

  initial begin
    rdone = '0;
    vals_read = 0;
    rval = -1;
    re = '0;
    @(posedge full);
    repeat(5) @(posedge rclk);
    while(vals_read < VALS)begin
      @(posedge rclk) #1;
      if(~empty) begin
        re <= '1;
        rval = q.pop_back();
        #1 assert(rdata == rval);
        vals_read++;
      end
      else begin
        re <= '0;
      end
    end
    rdone <= '1;
  end

  initial begin
    wait(rdone && wdone) $finish;
  end
endmodule
