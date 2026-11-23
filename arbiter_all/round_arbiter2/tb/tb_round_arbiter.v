// ============================================================================
// round_robin_arbiter (mask method) testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_round_arbiter;

    parameter DEEP_NUM = 8;

    reg                         clk;
    reg                         rst_n;
    reg  [DEEP_NUM - 1 : 0]     queue_i;
    reg                         sche_en;
    wire [$clog2(DEEP_NUM)-1:0] pointer_o;

    // ---- Instantiate DUT ----
    round_robin_arbiter #(
        .DEEP_NUM(DEEP_NUM)
    ) u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .queue_i   (queue_i),
        .sche_en   (sche_en),
        .pointer_o (pointer_o)
    );

    // ---- clock ----
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_round_arbiter);
    end

    // ---- print each cycle ----
    always @(negedge clk) begin
        if (rst_n)
            $display("time=%0t | queue=%b sche_en=%b pointer=%0d",
                     $time, queue_i, sche_en, pointer_o);
    end

    // ========================================================================
    // helper: stimulus is applied on negedge update
    // ========================================================================
    task set_queue;
        input [DEEP_NUM-1:0] val;
        begin
            @(negedge clk);
            queue_i = val;
        end
    endtask

    task set_sche;
        input val;
        begin
            @(negedge clk);
            sche_en = val;
        end
    endtask

    task do_reset;
        begin
            queue_i = 0;
            sche_en = 0;
            rst_n   = 1'b0;
            repeat (2) @(posedge clk);
            rst_n   = 1'b1;
            @(posedge clk);
            sche_en = 1'b1;              // enable scheduling
            @(negedge clk);
        end
    endtask

    // ========================================================================
    // test
    // ========================================================================
    initial begin
        do_reset();

        $display("============================================");
        $display("round_robin_arbiter (mask method) test started");
        $display("DEEP_NUM = %0d", DEEP_NUM);
        $display("============================================\n");

        // --- Test 1: single-request queue ---
        $display("--- Test 1: single request queue=0000_0100 ---");
        $display("expected: each cycle pointer=2");
        set_queue(8'b0000_0100);
        repeat (4) @(posedge clk);

        // --- Test 2: all requests active → round-robin scheduling ---
        $display("\n--- Test 2: all requests active queue=1111_1111, check round-robin order ---");
        $display("expected: 0→1→2→3→4→5→6→7→0→...");
        set_queue(8'b1111_1111);
        repeat (12) @(posedge clk);

        // --- Test 3: subset of requests ---
        $display("\n--- Test 3: subset of requests queue=1010_1010 (even-numbered channels) ---");
        $display("expected: 1→3→5→7→1→3→...");
        set_queue(8'b1010_1010);
        repeat (8) @(posedge clk);

        // --- Test 4: sche_en pause ---
        $display("\n--- Test 4: sche_en pause, pointer should remain unchanged ---");
        set_queue(8'b1111_1111);
        repeat (3) @(posedge clk);              // advance 3 cycles
        set_sche(1'b0);
        $display("sche_en -> 0 (pause)");
        repeat (3) @(posedge clk);              // pause 3 cycles, pointer unchanged
        set_sche(1'b1);
        $display("sche_en -> 1 (resume)");
        repeat (3) @(posedge clk);              // resume round-robin scheduling

        // --- Test 5: dynamic request changes ---
        $display("\n--- Test 5: dynamic request changes ---");
        set_sche(1'b1);
        set_queue(8'b0000_0000);  repeat (2) @(posedge clk);
        set_queue(8'b1111_0000);  repeat (4) @(posedge clk);
        set_queue(8'b0000_1111);  repeat (4) @(posedge clk);
        set_queue(8'b0000_0001);  repeat (2) @(posedge clk);

        // --- Test 6: DEEP_NUM=4 smaller width ---
        // because DUT is parameterized for 8, use only the lower 4 bits for this test

        // ============================================================
        $display("\n============================================");
        $display("all tests completed");
        $display("============================================");
        repeat (2) @(posedge clk);
        $finish;
    end

    // ========================================================================
    // automatic check: the same channel should not receive consecutive grants (with multiple requests)
    // ========================================================================
    reg [$clog2(DEEP_NUM)-1:0] prev_pointer;
    wire                      prev_valid;
    always @(posedge clk) begin
        if (!rst_n)
            prev_pointer <= '0;
        else if (sche_en)
            prev_pointer <= pointer_o;
    end

    assign prev_valid = (|queue_i);

    always @(posedge clk) begin
        if (rst_n && sche_en && prev_valid && (|queue_i)) begin
            // more than 1 requests: perform check
            if ((queue_i & (queue_i - 1)) != '0) begin
                if (pointer_o == prev_pointer) begin
                    $display("[WARN] time=%0t: same channel granted twice consecutively pointer=%0d",
                             $time, pointer_o);
                end
            end
        end
    end

endmodule
