// ============================================================================
// fix_base_arbiter testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_fix_arbiter;

    parameter CHANNEL = 4;

    reg  [CHANNEL-1 : 0] req;
    reg  [CHANNEL-1 : 0] base;
    wire [CHANNEL-1 : 0] grant;

    // ---- Instantiate DUT ----
    fix_base_arbiter #(
        .CHANNEL(CHANNEL)
    ) u_dut (
        .req   (req),
        .base  (base),
        .grant (grant)
    );

    // ---- Waveform + Monitor ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_fix_arbiter);
        $monitor("time=%0t | req=%b base=%b grant=%b", $time, req, base, grant);
    end

    // ---- helper task: test a set of req+base and check grant ----
    reg [CHANNEL-1 : 0] expected;

    task check;
        input [CHANNEL-1 : 0] r;       // req
        input [CHANNEL-1 : 0] b;       // base
        input [CHANNEL-1 : 0] exp;      // expected grant
        begin
            req  = r;
            base = b;
            #10;
            if (grant !== exp) begin
                $display("[FAIL] req=%b base=%b | grant=%b expected=%b",
                         req, base, grant, exp);
            end else begin
                $display("[PASS] req=%b base=%b | grant=%b",
                         req, base, grant);
            end
        end
    endtask

    // ========================================================================
    // test
    // ========================================================================
    initial begin
        $display("============================================");
        $display("fix_base_arbiter test started (CHANNEL=%0d)", CHANNEL);
        $display("============================================\n");

        // --- Test 1: no requests ---
        $display("--- Test 1: no requests ---");
        check(4'b0000, 4'b0001, 4'b0000);
        check(4'b0000, 4'b1000, 4'b0000);

        // --- Test 2: single request, various base ---
        $display("\n--- Test 2: single request (req[2]=1) ---");
        check(4'b0100, 4'b0001, 4'b0100);  // base=1→ start from 0, find 2
        check(4'b0100, 4'b0010, 4'b0100);  // base=2→ start from 1, find 2
        check(4'b0100, 4'b0100, 4'b0100);  // base=4→ start from 2, find 2 (itself)
        check(4'b0100, 4'b1000, 4'b0100);  // base=8→ start from 3, wrap to 2

        // --- Test 3: multiple requests, base=0001 (default priority starts at channel 0) ---
        $display("\n--- Test 3: multiple requests, base=0001 ---");
        check(4'b1010, 4'b0001, 4'b0010);  // req[1],[3]=1 → grant[1]
        check(4'b1110, 4'b0001, 4'b0010);  // req[1],[2],[3]=1 → grant[1]
        check(4'b1001, 4'b0001, 4'b0001);  // req[0],[3]=1 → grant[0]

        // --- Test 4: multiple requests, base is not at 0001 ---
        $display("\n--- Test 4: multiple requests, base=0100 (starting at req[2]) ---");
        // priority: req[2] > req[1] > req[0] > req[3]
        check(4'b1010, 4'b0100, 4'b1000);  // req[1],[3]=1 → find [2],[1],[0],[3], the first is [3]
        check(4'b1110, 4'b0100, 4'b0100);  // req[1],[2],[3]=1 → [2] matches itself
        check(4'b0111, 4'b0100, 4'b0100);  // req[0],[1],[2]=1 → [2] match

        $display("\n--- Test 5: multiple requests, base=1000 (starting at req[3]) ---");
        // priority: req[3] > req[2] > req[1] > req[0]
        check(4'b1010, 4'b1000, 4'b1000);  // req[1],[3]=1 → [3] match
        check(4'b0111, 4'b1000, 4'b0001);  // req[0],[1],[2]=1 → wrap, [0] match
        check(4'b1111, 4'b1000, 4'b1000);  // all requests active → base is [3]

        $display("\n--- Test 6: multiple requests, base=0010 (starting at req[1]) ---");
        // priority: req[1] > req[0] > req[3] > req[2]
        check(4'b1111, 4'b0010, 4'b0010);  // [1] match
        check(4'b1001, 4'b0010, 4'b1000);  // req[0],[3]=1 → [1],[0],[3] find [3]
        check(4'b0001, 4'b0010, 4'b0001);  // req[0]=1 → [1],[0],[3],[2] find [0]

        // --- Test 7: all requests active, iterate over all base ---
        $display("\n--- Test 7: req=1111, iterate over base ---");
        check(4'b1111, 4'b0001, 4'b0001);  // start from 0 → grant[0]
        check(4'b1111, 4'b0010, 4'b0010);  // start from 1 → grant[1]
        check(4'b1111, 4'b0100, 4'b0100);  // start from 2 → grant[2]
        check(4'b1111, 4'b1000, 4'b1000);  // start from 3 → grant[3]

        // --- Test 8: consecutive single bit request, base=0001 ---
        $display("\n--- Test 8: consecutive single bit request ---");
        check(4'b0001, 4'b0001, 4'b0001);
        check(4'b0010, 4'b0001, 4'b0010);
        check(4'b0100, 4'b0001, 4'b0100);
        check(4'b1000, 4'b0001, 4'b1000);

        // ============================================================
        $display("\n============================================");
        $display("all tests completed");
        $display("============================================");
        #20;
        $finish;
    end

endmodule
