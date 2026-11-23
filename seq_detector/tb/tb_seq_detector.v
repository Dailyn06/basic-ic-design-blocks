// ============================================================================
// seq_detector (Sequence Detector "1101") testbench
// ============================================================================
// License: MIT
// 
// sequence to detect: "1101" (supports overlapping matches)
// 
// test bitstream: 1 1 0 1 1 0 1
// expected match: at bit4 and bit7 each generate single-cycle pulse (overlap)
// first "1101": bit 1-4 → match@bit4
// Overlap: the 1 at bit 4 starts the next "1101" sequence.
// second "1101": bit 4-7 → match@bit7
// 
// match is a Mealy output: match=1 when state==S110 and din==1.
// din drive on the falling edge; match sample on the next falling edge,
// because match valid between the falling and rising edges (combinational logic uses the previous state + new din).
// Use a #1 delay to let combinational logic settle before sampling.
// ============================================================================

`timescale 1ns / 1ps

module tb_seq_detector;

    reg  clk;
    reg  rst_n;
    reg  din;
    wire match;

    // ---- Instantiate DUT ----
    seq_detector u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .din  (din),
        .match(match)
    );

    // ---- clock: 100MHz (cycle 10ns) ----
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_seq_detector);
    end

    // ---- Monitor (sample on the falling edge, plus #1 observe the settled combinational value) ----
    always @(negedge clk) begin
        #1;
        if (rst_n)
            $display("time=%0t | din=%b match=%b state=%0d",
                     $time, din, match, u_dut.state);
    end

    // ========================================================================
    // test
    // ========================================================================
    // bitstream: 1 1 0 1 1 0 1
    // expected: 0 0 0 1 0 0 1
    // index [6:0] — MSB first (bit6 transmitted first)
    // ========================================================================
    integer   i;
    integer   pass_cnt, fail_cnt;
    reg [6:0] bitstream;
    reg [6:0] exp_match;
    reg [6:0] got_match;

    initial begin
        din  = 1'b0;
        rst_n = 1'b0;

        // reset
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("============================================");
        $display("seq_detector (Sequence Detector) test started");
        $display("sequence to detect: 1101 (overlapping match)");
        $display("clock: 100MHz (cycle 10ns)");
        $display("============================================\n");

        bitstream = 7'b1101101;       // bit[6] transmitted first (MSB first)
        exp_match = 7'b0001001;       // expected match: bit4=1, bit7=1

        got_match = 7'd0;
        pass_cnt  = 0;
        fail_cnt  = 0;

        $display("--- send bitstream: 1 1 0 1 1 0 1 ---\n");

        for (i = 6; i >= 0; i = i - 1) begin
            // drive din on the falling edge (avoid races)
            @(negedge clk);
            din = bitstream[i];

            // wait for combinational logic to settle (Mealy Output: state=S110 + din update)
            // match valid during the half cycle after the falling edge
            #1;

            got_match[i] = match;

            if (match === exp_match[i]) begin
                $display("bit%0d: din=%b match=%b (exp %b) [PASS]",
                         7-i, din, match, exp_match[i]);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("bit%0d: din=%b match=%b (exp %b) [FAIL]",
                         7-i, din, match, exp_match[i]);
                fail_cnt = fail_cnt + 1;
            end
        end

        // ---- Summary ----
        $display("\n--- Results ---");
        $display("expected: %b", exp_match);
        $display("actual: %b", got_match);
        if (got_match === exp_match) begin
            $display("[PASS] sequence detection correct!");
        end else begin
            $display("[FAIL] sequence detection incorrect!");
            fail_cnt = fail_cnt + 1;
        end
        $display("bit comparison PASS: %0d / FAIL: %0d", pass_cnt, fail_cnt);

        // ---- additional: match should be zero while idle ----
        $display("\n--- idle check: hold din=0, match expected 0 ---");
        @(negedge clk);
        din = 1'b0;
        repeat (3) begin
            @(negedge clk);
            #1;
            if (match !== 1'b0) begin
                $display("[FAIL] when idle match=%b (time=%0t)", match, $time);
                fail_cnt = fail_cnt + 1;
            end
        end
        $display("idle checks completed");

        // ============================================================
        $display("\n============================================");
        $display("seq_detector all tests completed");
        if (fail_cnt == 0)
            $display("all tests passed!");
        else
            $display("total %0d failures!", fail_cnt);
        $display("============================================");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
