module name_diff(
    clk_i, rst_i,
    a_i, b_i, vld_i,
    mem_raddr_o, mem_rdat_i,
    rdy_o, done_o, almost_match_o);
  input clk_i;
  input rst_i;
  input [13:0] a_i, b_i;
  input vld_i;
  output reg [13:0] mem_raddr_o;
  input [7:0] mem_rdat_i;
  output rdy_o;
  output done_o;
  output almost_match_o;

  reg [2:0] state_r, state_next;
  localparam IDLE = 0;
  localparam LOAD_A = 1;
  localparam LOAD_B = 2;
  localparam COMPARE = 3;
  localparam DONE = 4;
  assign rdy_o = (state_r == IDLE);
  assign done_o = (state_r == DONE);

  reg [2:0] mismatches_r, mismatches_next;
  assign almost_match_o = (mismatches_r == 1);

  reg [13:0] aptr_r, aptr_next;
  reg [13:0] bptr_r, bptr_next;

  reg [7:0] tmp_r, tmp_next;

  initial begin
    state_r = IDLE;
    mismatches_r = 0;
    aptr_r = 0;
    bptr_r = 0;
    tmp_r = 0;
  end

  always @(*) begin
    mem_raddr_o = 0;
    case (state_r)
      LOAD_A: mem_raddr_o = aptr_r;
      LOAD_B: mem_raddr_o = bptr_r;
    endcase
  end

  always @(*) begin
    state_next = state_r;
    if (rst_i) begin
      state_next = IDLE;
    end else
      case (state_r)
        IDLE:
          if (vld_i) begin
            state_next = LOAD_A;
          end
        LOAD_A: state_next = LOAD_B;
        LOAD_B:
          if (mem_rdat_i == 0)
            state_next =  DONE;
          else
            state_next = COMPARE;
        COMPARE:
          if (mem_rdat_i == 0)
            state_next = DONE;
          else
            state_next = LOAD_A;
        DONE: begin
          $display("mismatches %x", mismatches_r);
          if (vld_i == 0)
            state_next = IDLE;
        end
      endcase
  end

  always @(*) begin
    aptr_next = aptr_r;
    bptr_next = bptr_r;
    if (rst_i) begin
      aptr_next = 0;
      bptr_next = 0;
    end else
      case (state_r)
        IDLE: begin
          aptr_next = a_i;
          bptr_next = b_i;
        end
        LOAD_A:
          aptr_next = aptr_r + 1;
        LOAD_B:
          bptr_next = bptr_r + 1;
      endcase
  end

  always @(*) begin
    tmp_next = tmp_r;
    if (state_r == LOAD_B)
      tmp_next = mem_rdat_i;
  end

  always @(*) begin
    mismatches_next = mismatches_r;
    if (rst_i || (state_r == IDLE)) begin
      mismatches_next = 0;
    end else if (state_r == COMPARE) begin
      if ((mem_rdat_i != 0) && (mem_rdat_i != tmp_r)) begin
        //$display("mismatch %x", mismatches_r);
        case (mismatches_r)
          0: mismatches_next = 1;
          1: mismatches_next = 2;
          2: mismatches_next = 3;
          3: mismatches_next = 3;
        endcase
      end
    end
  end

  always @(posedge clk_i) begin
    state_r <= state_next;
    aptr_r <= aptr_next;
    bptr_r <= bptr_next;
    tmp_r <= tmp_next;
    mismatches_r <= mismatches_next;
  end

endmodule

module mem (clk_i, raddr_i, rdat_o, waddr_i, wdat_i, wen_i);
  parameter ADDR_WIDTH = 14;
  parameter DATA_WIDTH = 8;
  parameter MEM_SIZE = 1 << ADDR_WIDTH;

  input clk_i;
  input [ADDR_WIDTH-1:0] raddr_i;
  output reg [DATA_WIDTH-1:0] rdat_o;

  input [ADDR_WIDTH-1:0] waddr_i;
  input [DATA_WIDTH-1:0] wdat_i;
  input wen_i;

  reg [DATA_WIDTH-1:0] data[MEM_SIZE-1:0];
  always @(posedge(clk_i)) begin
    rdat_o <= data[raddr_i];
    if (wen_i)
      data[waddr_i] <= wdat_i;
  end
endmodule

module diff_fsm(
  clk_i, rst_i, vld_i,
  diff_a_o, diff_b_o, diff_vld_o, diff_rdy_i, diff_done_i, diff_match_i,
  index_raddr_o, index_rdat_i,
  max_idx_i,
  rdy_o, done_o, a_o, b_o);
  input clk_i;
  input rst_i;
  input vld_i;

  output reg [13:0] diff_a_o, diff_b_o;
  output diff_vld_o;
  input diff_rdy_i;
  input diff_done_i;
  input diff_match_i;

  output reg [7:0] index_raddr_o;
  input [13:0] index_rdat_i;

  input [7:0] max_idx_i;

  output rdy_o;
  output done_o;
  output [7:0] a_o;
  output [7:0] b_o;

  reg [7:0] acount_r, acount_next;
  reg [7:0] bcount_r, bcount_next;

  assign a_o = acount_r;
  assign b_o = bcount_r;

  reg [3:0] state_r, state_next;
  localparam IDLE = 0;
  localparam LOAD_A_IDX = 1;
  localparam LOAD_B_IDX = 2;
  localparam RUN_DIFF = 3;
  localparam WAIT_DIFF_DONE = 4;
  localparam INCREMENT = 5;
  localparam DONE = 6;
  
  assign rdy_o = (state_r == IDLE);
  assign done_o = (state_r == DONE);

  initial begin
    acount_r <= 1;
    bcount_r <= 0;
    state_r <= 0;

    diff_a_o <= 0;
    diff_b_o <= 0;
  end

  always @(*) begin
    state_next = state_r;
    if (rst_i)
      state_next = IDLE;
    else
      case (state_r)
        IDLE:
          if (vld_i)
            state_next = LOAD_A_IDX;
        LOAD_A_IDX:
          state_next = LOAD_B_IDX;
        LOAD_B_IDX:
          state_next = RUN_DIFF;
        RUN_DIFF:
          if (diff_rdy_i)
            state_next = WAIT_DIFF_DONE;
        WAIT_DIFF_DONE:
          if (diff_done_i) begin
            if (diff_match_i) begin
              state_next = DONE;
            end else begin
              state_next = INCREMENT;
            end
          end
        INCREMENT: begin
          $display("increment; a=%d b=%d max=%d", acount_r, bcount_r, max_idx_i);
          if ((acount_r == (max_idx_i-1)) && (bcount_r == (acount_r - 1)))
            state_next = DONE;
          else
            state_next = LOAD_A_IDX;
        end
        DONE:
          if (!vld_i)
            state_next = IDLE;
      endcase
  end

  always @(*) begin
    acount_next = acount_r;
    bcount_next = bcount_r;
    if ((state_r == IDLE) || rst_i) begin
      acount_next = 1;
      bcount_next = 0;
    end else if ((state_r == INCREMENT) && (state_next != DONE)) begin
      if (bcount_r == (acount_r - 1)) begin
        acount_next = acount_r + 1;
        bcount_next = 0;
      end else
        bcount_next = bcount_r + 1;
    end
  end

  always @(*) begin
    // needs to default to bcount_r so that
    // the memory doesn't get messed up if the FSM stalls
    // on RUN_DIFF; otherwise diff_b_o would get overwritten
    // on the second or later clock cycle in that state
    index_raddr_o = bcount_r;
    if (state_r == LOAD_A_IDX)
      index_raddr_o = acount_r;
    if (state_r == LOAD_B_IDX)
      index_raddr_o = bcount_r;
  end

  always @(posedge clk_i) begin
    if (rst_i) begin
      diff_a_o <= 0;
      diff_b_o <= 0;
    end else begin
      if (state_r == LOAD_B_IDX)
        diff_a_o <= index_rdat_i;
      if (state_r == RUN_DIFF)
        diff_b_o <= index_rdat_i;
    end
  end

  assign diff_vld_o = (state_r == WAIT_DIFF_DONE);

  always @(posedge clk_i) begin
    acount_r <= acount_next;
    bcount_r <= bcount_next;
    state_r <= state_next;
  end
endmodule

module run_diff;
  reg clk_r;
  reg rst_r;

  reg fsm_vld_r;
  wire [13:0] char_raddr;
  wire [7:0] char_rdat;

  reg [13:0] char_waddr_r;
  reg [7:0] char_wdat_r;
  reg char_wen_r;

  wire [7:0] idx_raddr;
  wire [13:0] idx_rdat;

  reg [7:0] idx_waddr_r;
  reg [13:0] idx_wdat_r;
  reg idx_wen_r;

  wire [13:0] diff_a, diff_b;
  wire diff_vld;

  wire diff_rdy, diff_done, diff_almost_match;

  reg [7:0] max_idx;
  wire fsm_rdy, fsm_done;
  wire [7:0] fsm_a, fsm_b;

  mem #(14, 8) char_mem(
    clk_r, char_raddr, char_rdat, char_waddr_r, char_wdat_r, char_wen_r);
  mem #(8, 14) idx_mem(
    clk_r, idx_raddr, idx_rdat, idx_waddr_r, idx_wdat_r, idx_wen_r);
  name_diff diff0(
    clk_r, rst_r, 
    diff_a, diff_b, diff_vld,
    char_raddr, char_rdat,
    diff_rdy, diff_done, diff_almost_match);
  diff_fsm fsm0(
    clk_r, rst_r, fsm_vld_r,
    diff_a, diff_b, diff_vld, diff_rdy, diff_done, diff_almost_match,
    idx_raddr, idx_rdat,
    max_idx,
    fsm_rdy, fsm_done, fsm_a, fsm_b);

  integer char, addr, word, start;

  wire [7:0] data;
  assign data = char[7:0];

  localparam STDIN =  32'h8000_0000;

  initial begin
    $dumpfile("test.vcd");
    $dumpvars(0, diff0);
    $dumpvars(0, fsm0);
    $dumpvars(0, idx_mem);
    clk_r = 0;
    rst_r = 1;

    char_waddr_r = 0;
    char_wdat_r = 0;
    char_wen_r = 0;

    idx_waddr_r = 0;
    idx_wdat_r = 0;
    idx_wen_r = 0;

    fsm_vld_r = 0;
    max_idx = 0;

    start = 0;
    addr = 0;
    word = 0;

    #1 clk_r = 1;
    #1 clk_r = 0;

    rst_r = 0;
    while (!$feof(STDIN)) begin
      char = $fgetc(STDIN);
      idx_wen_r = 0;
      if (char == 8'h0a) begin
        $display("end of word; start = %x", start);
        idx_waddr_r = word;
        idx_wdat_r = start;
        idx_wen_r = 1;

        // write a null character into memory
        char_waddr_r = addr;
        char_wdat_r = 0;
        char_wen_r = 1;

        word = word + 1;
        start = addr + 1;
      end else begin
        char_waddr_r = addr;
        char_wdat_r = data;
        char_wen_r = 1;
      end
      #1 clk_r = 1;
      #1 clk_r = 0;

      addr = addr + 1;
    end

    $display("waiting for fsm");
    // wait for the fsm to be ready
    while (!fsm_rdy) begin
      #1 clk_r = 1;
      #1 clk_r = 0;
    end
    fsm_vld_r = 1;
    max_idx = word;
    $display("running fsm");
    while (!fsm_done) begin
      #1 clk_r = 1;
      #1 clk_r = 0;
    end
    $display("a = %d b = %d", fsm_a, fsm_b);
  end

endmodule
