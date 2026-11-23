// ============================================================================
// edge_detect (edge detection) testbench
// ============================================================================
// License: MIT
// 
// test cases:
// 1. signal 0→1 rising-edge detection → pos_edge=1
// 2. signal 1→0 falling-edge detection → neg_edge=1
// 3. both-edge detection → both_edge=1 (pos_edge | neg_edge)
// 4. no pulses while the signal remains steady
// 
// signal sequence: 0 → 1 → 1 → 0 → 0 → 1 → 1 → 1 → 0
// | pos | | neg | | pos |... | neg
// ============================================================================

`timescale 1ns / 1ps

module tb_edge_detect;

    reg  clk;
    reg  rst_n;
    reg  signal;
    wire pos_edge;
    wire neg_edge;
    wire both_edge;

    // ---- Instantiate DUT ----
    edge_detect u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .signal   (signal),
        .pos_edge (pos_edge),
        .neg_edge (neg_edge),
        .both_edge(both_edge)
    );

    // ---- clock: 100MHz (cycle 10ns) ----
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_edge_detect);
    end

    // ---- Monitor (sample on the falling edge, avoid races) ----
    always @(negedge clk) begin
        if (rst_n)
            $display("time=%0t | signal=%b | pos=%b neg=%b both=%b",
                     $time, signal, pos_edge, neg_edge, both_edge);
    end

    // ========================================================================
    // check task: check edge outputs on the falling edge
    // ========================================================================
    task check_edges;
        input exp_pos;
        input exp_neg;
        input exp_both;
        begin
            @(negedge clk);
            if (pos_edge  !== exp_pos) begin
                $display("[FAIL] pos_edge=%b, expected %b (time=%0t)", pos_edge, exp_pos, $time);
            end else if (neg_edge !== exp_neg) begin
                $display("[FAIL] neg_edge=%b, expected %b (time=%0t)", neg_edge, exp_neg, $time);
            end else if (both_edge !== exp_both) begin
                $display("[FAIL] both_edge=%b, expected %b (time=%0t)", both_edge, exp_both, $time);
            end else begin
                $display("[PASS] pos=%b neg=%b both=%b", pos_edge, neg_edge, both_edge);
            end
        end
    endtask

    // ========================================================================
    // test
    // ========================================================================
    reg [7:0] pass_cnt, fail_cnt;
    integer    i;

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        signal = 1'b0;
        rst_n  = 1'b0;

        // reset
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("============================================");
        $display("edge_detect (edge detection) test started");
        $display("clock: 100MHz (cycle 10ns)");
        $display("============================================\n");

        // --------------------------------------------------
        // signal sequence: 0 → 1 → 1 → 0 → 0 → 1 → 1 → 1 → 0
        // hold each value for at least 2 cycles, ensure edge pulses are observable
        // --------------------------------------------------

        // --- Step 0: initial 0, no change ---
        $display("--- initial state: signal=0 (hold) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // --- Step 1: 0 → 1 (rising edge) ---
        $display("\n--- rising edge: signal 0→1 ---");
        @(negedge clk);
        signal = 1'b1;
        check_edges(1'b1, 1'b0, 1'b1);

        // --- Step 2: 1 hold ---
        $display("\n--- hold 1: signal=1 (no pulse expected) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // --- Step 3: 1 → 0 (falling edge) ---
        $display("\n--- falling edge: signal 1→0 ---");
        @(negedge clk);
        signal = 1'b0;
        check_edges(1'b0, 1'b1, 1'b1);

        // --- Step 4: 0 hold ---
        $display("\n--- hold 0: signal=0 (no pulse expected) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // --- Step 5: 0 → 1 (rising edge) ---
        $display("\n--- rising edge: signal 0→1 ---");
        @(negedge clk);
        signal = 1'b1;
        check_edges(1'b1, 1'b0, 1'b1);

        // --- Step 6: 1 hold ---
        $display("\n--- hold 1: signal=1 (no pulse expected) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // --- Step 7: 1 hold ---
        $display("\n--- hold 1: signal=1 (no pulse expected) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // --- Step 8: 1 → 0 (falling edge) ---
        $display("\n--- falling edge: signal 1→0 ---");
        @(negedge clk);
        signal = 1'b0;
        check_edges(1'b0, 1'b1, 1'b1);

        // --- Step 9: 0 hold ---
        $display("\n--- hold 0: signal=0 (no pulse expected) ---");
        check_edges(1'b0, 1'b0, 1'b0);

        // ============================================================
        $display("\n============================================");
        $display("edge_detect all tests completed");
        $display("============================================");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
