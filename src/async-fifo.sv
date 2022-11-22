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
    if(we)
      data[wptr] <= wdata;
  assign rdata = data[rptr];

  write_half #(PTR_WIDTH) frontend
    (.rst, .wclk, .we,
     .rptr_gray,
     .wptr, .wptr_gray,
     .full);

  // read_half #($clog2(DEPTH)+1) backend
  // (.rclk, .re,
  // .wptr_gray,
  // .rptr, .rpt_gray,
  // .empty);
endmodule: async_fifo

module write_half
  #(parameter PTR_WIDTH)
  (input logic rst, wclk, we,
   input logic [PTR_WIDTH-1:0] rptr_gray,
   output logic [PTR_WIDTH-1:0] wptr, wptr_gray,
   output logic full);

  logic [PTR_WIDTH-1:0] rptr_bin;

  gray2bin #(PTR_WIDTH) rptr_g2b
    (.gray(rptr_gray), .binary(rptr_bin));

  assign full = rptr_bin[PTR_WIDTH-2:0] == wptr[PTR_WIDTH-2:0] &&
                rptr_bin[PTR_WIDTH-1] == ~wptr[PTR_WIDTH-1];

  always_ff @(posedge wclk, posedge rst)
    if(rst)
      wptr <= '0;
    else if(we && ~full)
      wptr <= wptr + (PTR_WIDTH-1)'(1);

  bin2gray #(PTR_WIDTH) wptr_b2g
    (.binary(wptr), .gray(wptr_gray));
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
