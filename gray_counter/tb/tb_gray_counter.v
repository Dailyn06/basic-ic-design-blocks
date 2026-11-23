// ============================================================================
// gray_counter (Gray code counter) testbench
// ============================================================================
// License: MIT
// 
// test cases:
// 1. after reset gray=0, binary=0
// 2. increment 16 times, verify each time gray == binary ^ (binary >> 1)
// 3. adjacent Gray codes differ by only 1 bit (including 15→0 wraparound)
// ============================================================================

`timescale 1ns / 1ps

module tb_gray_counter;

    localparam WIDTH = 4;

    reg                   clk;
    reg                   rst_n;
    reg                   inc;
    wire [WIDTH-1:0]      gray;
    wire [WIDTH-1:0]      binary;

    // ---- DUT ----
    gray_counter #(
        .WIDTH(WIDTH)
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .inc   (inc),
        .gray  (gray),
        .binary(binary)
    );

    // ---- 100MHz clock ----
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_gray_counter);
    end

    // ---- helper function: Binary → Gray ----
    function [WIDTH-1:0] bin2gray;
        input [WIDTH-1:0] b;
        begin
            bin2gray = b ^ (b >> 1);
        end
    endfunction

    // ---- Helper function: count differing bits between two values ----
    function integer diff_bits;
        input [WIDTH-1:0] a;
        input [WIDTH-1:0] b;
        reg [WIDTH-1:0] x;
        begin
            x = a ^ b;
            diff_bits = x[0] + x[1] + x[2] + x[3];
        end
    endfunction

    // ========================================================================
    // main test sequence
    // ========================================================================
    reg [WIDTH-1:0] prev_gray;
    integer         pass, fail;
    integer         i;

    initial begin
        pass = 0;
        fail = 0;
        inc  = 1'b0;
        rst_n = 1'b0;

        // reset
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("============================================");
        $display("Gray Counter (WIDTH=%0d) test started", WIDTH);
        $display("============================================\n");

        // ---- Test 1: after reset gray=0, binary=0 ----
        @(negedge clk);
        if (gray === {WIDTH{1'b0}} && binary === {WIDTH{1'b0}}) begin
            $display("[PASS] Test 1: after reset gray=%b binary=%0d", gray, binary);
            pass = pass + 1;
        end else begin
            $display("[FAIL] Test 1: after reset gray=%b binary=%0d (both expected to be 0)", gray, binary);
            fail = fail + 1;
        end

        // ---- Test 2 & 3: increment 16 times ----
        // check each time: gray == binary ^ (binary >> 1)
        // check each time: adjacent gray differ by only 1 bit (including 15→0 wraparound)
        $display("\n--- Test 2 & 3: increment 16 times (including wraparound) ---");
        inc = 1'b1;
        prev_gray = gray;    // gray(0) = 0000

        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);

            // check Gray code formula
            if (gray !== bin2gray(binary)) begin
                $display("[FAIL] i=%0d: gray=%b, bin2gray(%b)=%b",
                         i, gray, binary, bin2gray(binary));
                fail = fail + 1;
            end else begin
                pass = pass + 1;
            end

            // check adjacent Gray codes differ by only 1 bit
            if (diff_bits(gray, prev_gray) !== 1) begin
                $display("[FAIL] i=%0d: gray=%b prev_gray=%b diff=%0d (expected 1)",
                         i, gray, prev_gray, diff_bits(gray, prev_gray));
                fail = fail + 1;
            end else begin
                pass = pass + 1;
            end

            prev_gray = gray;
        end

        // confirm that the final transition wraps around (15→0): gray(15)=1000, gray(0)=0000
        // At the end of iteration i=15, prev_gray is updated to gray(0)=0000,
        // The preceding value was gray(15)=1000; iteration i=15 already checked the difference.
        $display("[INFO] final step: gray(15)=1000 → gray(0)=0000, diff=1 bit (wraparound correct)\n");

        // ============================================================
        $display("============================================");
        $display("tests completed: PASS=%0d FAIL=%0d", pass, fail);
        if (fail == 0)
            $display("all tests passed!");
        else
            $display("%0d tests failed!", fail);
        $display("============================================");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
