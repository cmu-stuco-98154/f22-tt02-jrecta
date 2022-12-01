module jonpaolo02_async_fifo (
                              input [7:0] io_in,
                              output [7:0] io_out
                              );


  async_fifo #(.WIDTH(3), .DEPTH(4)) top
    (.rst(io_in[2]),

     .wclk(io_in[0]), .we(io_in[3]),
     .full(io_out[3]),
     .wdata(io_in[5:7]),

     .rclk(io_in[1]), .re(io_in[4])
     .empty(io_out[4]),
     .rdata(io_out[5:7]));
endmodule
