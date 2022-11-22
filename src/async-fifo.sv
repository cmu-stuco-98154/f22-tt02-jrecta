`default_nettype none

module async_fifo
  #(parameter WIDTH=4,
    parameter DEPTH=4)
  (input logic rst,
   input logic wclk, we, full,
   input logic[WIDTH-1:0] wdata,
   input logic rclk, re, empty,
   output logic[WIDTH-1:0] rdata);
  logic [$clog2(DEPTH)-1:0] wptr, wptr_gray, rptr, rptr_gray;
  logic [DEPTH-1:0][WIDTH-1:0] data;

  always_ff @(posedge wclk)
    if(we)
      data[wptr] <= wdata;
  assign rdata = data[rptr];

  write_half #(DEPTH) frontend
    (.wclk, .we,
     .rptr_gray,
     .wptr, .wptr_gray,
     .full);

  read_half #(DEPTH) backend
    (.rclk, .re,
     .wptr_gray,
     .rptr, .rpt_gray,
     .empty);
endmodule: cdc_fifo

module write_half
  #(parameter DEPTH=4)
  (input logic rst, wclk, we,
   input logic [$clog2(DEPTH):0] rptr_gray,
   output logic [$clog2(DEPTH):0] wptr, wptr_gray,
   output logic full);
  parameter PTR_WIDTH = $clog(DEPTH);

  logic [PTR_WIDTH:0] rptr_bin;

  gray2bin #(PTR_WIDTH) rptr_g2b
    (.gray(rptr_gray), .binary(rptr_bin));

  assign full = rptr_bin[PTR_WIDTH-1:0] == wptr[PTR_WIDTH-1:0] &&
                rptr_bin[PTR_WIDTH] == ~wptr[PTR_WIDTH];
  always_ff @(posedge wclk, posedge rst)
    if(rst)
      wptr <= '0;
    else if(we && ~full)
      wptr <= wptr + PTR_WIDTH'b1;
endmodule

module gray2bin
  #(parameter WIDTH=4)
  (input logic[WIDTH-1:0] gray,
   output logic[WIDTH-1:0] binary);

  generate for(genvar i = 0; i < WIDTH-1; i++)
    assign binary[i] = gray[i] ^ binary[i+1];
  endgenerate
  assign binary[WIDTH-1] = gray[WIDTH-1];
endmodule // gray2bin

module gray2bin_test;

  logic [3:0] gray, binary_out;
  gray2bin #(4) DUT (.gray, .binary(binary_out));

  initial begin
    for(int i = 0; i < 16; i++) begin
      gray = i ^ (i >> 1);
      #1 test_decode: assert(binary_out == i) else
        $display("bin=%b gray=%b, got=%b", i, gray, binary_out);
    end
    #10 $finish;
  end // initial begin
endmodule // gray2bin_test
