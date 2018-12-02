module checksum(clk_i, rst_i, data_i, vld_i, repeated2_o, repeated3_o);
  input clk_i;
  input rst_i;
  input [7:0] data_i;
  input vld_i;
  output rdy_o;
  output repeated2_o;
  output repeated3_o;

  reg [255:0] counts_r[2:0];

  assign repeated2_o = |counts_r[1];
  assign repeated3_o = |counts_r[2];

  initial begin
    counts_r[0] <= 0;
    counts_r[1] <= 0;
    counts_r[2] <= 0;
  end

  wire [2:0] counts;
  assign counts[0] = counts_r[0][data_i];
  assign counts[1] = counts_r[1][data_i];
  assign counts[2] = counts_r[2][data_i];

  always @(posedge clk_i) begin
    if (rst_i) begin
      counts_r[0] <= 0;
      counts_r[1] <= 0;
      counts_r[2] <= 0;
    end else begin
      if (vld_i) begin
        if (counts) begin
          counts_r[0][data_i] <= 0;
          counts_r[1][data_i] <= counts[0];
          counts_r[2][data_i] <= counts[1];
        end else begin
          counts_r[0][data_i] <= 1;
        end
      end
    end
  end
endmodule

module run_checksum;
  reg clk_r;
  reg rst_r;
  reg vld_r;
  wire [7:0] data;
  wire repeated2, repeated3;

  checksum checksum0(clk_r, rst_r, data, vld_r, repeated2, repeated3);

  integer char;
  integer count2;
  integer count3;

  assign data = char[7:0];

  localparam STDIN =  32'h8000_0000;

  initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, run_checksum);
    $dumpvars(0, checksum0);
    clk_r = 0;
    rst_r = 1;
    vld_r = 1;

    count2 = 0;
    count3 = 0;
    char = 0;

    #1 clk_r = 1;
    #1 clk_r = 0;

    rst_r = 0;
    while (!$feof(STDIN)) begin
      char = $fgetc(STDIN);
      if ((char == 8'h0d) || (char == 8'h0a)) begin
        rst_r = 1;
        vld_r = 0;
        $display("%d %d", repeated2, repeated3);
        count2 = count2 + repeated2;
        count3 = count3 + repeated3;
      end else begin
        rst_r = 0;
        vld_r = 1;
      end
      #1 clk_r = 1;
      #1 clk_r = 0;
    end

    $display("count2 = %d, count3 = %d, checksum = %d", count2, count3, count2*count3);
  end
endmodule
