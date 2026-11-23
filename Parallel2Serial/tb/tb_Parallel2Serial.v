// ============================================================================
// Parallel2Serial (6-bit parallel-to-serial conversion) testbench
// ============================================================================
// License: MIT
// 
// test cases:
// 1. basic parallel-to-serial conversion: parallel input 6'b101101, serial output LSB first
// 2. back-to-back transfers: 0x2A then 0x15
// 3. backpressure test: o_dout holds when i_dout_ready=0
// 
// Notes:
// - i_dout_ready defaults to 1 (downstream always ready)
// - all stimulus is driven on the falling edge
// - during backpressure o_dout_valid remains 1 (the module does not deassert it internally), only o_dout value holds
// ============================================================================

`timescale 1ns / 1ps

module tb_Parallel2Serial;

    reg         i_clk;
    reg         i_rst_n;
    reg         i_din_valid;
    reg  [5:0]  i_din;
    reg         i_dout_ready;
    wire        o_din_ready;
    wire        o_dout_valid;
    wire        o_dout;

    // ---- DUT ----
    Parallel2Serial u_dut (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_din_valid  (i_din_valid),
        .i_din        (i_din),
        .o_din_ready  (o_din_ready),
        .i_dout_ready (i_dout_ready),
        .o_dout_valid (o_dout_valid),
        .o_dout       (o_dout)
    );

    // ---- 100MHz clock ----
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_Parallel2Serial);
    end

    // ========================================================================
    // task: send parallel data, receive serial data, compare
    // ========================================================================
    task send_and_check;
        input [5:0] data;
        reg   [5:0] r;
        integer      j;
        begin
            // wait for DUT idle, send parallel data
            @(negedge i_clk);
            i_din_valid = 1'b1;
            i_din       = data;
            @(negedge i_clk);          // next cycle: DUT has loaded the word; bit 0 is ready
            i_din_valid = 1'b0;

            // receive 6-bit serial data LSB first (bit 0 is already on o_dout)
            r = 6'd0;
            for (j = 0; j < 6; j = j + 1) begin
                if (o_dout_valid !== 1'b1) begin
                    $display("[FAIL] bit %0d: o_dout_valid=%b (expected 1)", j, o_dout_valid);
                end
                r[j] = o_dout;
                @(negedge i_clk);
            end

            // compare
            if (r === data)
                $display("[PASS] Sent=0x%h (%b), Recv=0x%h (%b)",
                         data, data, r, r);
            else
                $display("[FAIL] Sent=0x%h (%b), Recv=0x%h (%b)",
                         data, data, r, r);
        end
    endtask

    // ========================================================================
    // main test sequence
    // ========================================================================
    integer k;
    reg [5:0] recv;
    reg       dout_held;

    initial begin
        i_din_valid  = 1'b0;
        i_din        = 6'd0;
        i_dout_ready = 1'b1;     // default: downstream always ready

        // reset
        i_rst_n = 1'b0;
        repeat (2) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat (2) @(posedge i_clk);

        $display("============================================");
        $display("Parallel2Serial (6-bit parallel-to-serial conversion) test started");
        $display("clock: 100MHz, LSB first");
        $display("i_dout_ready defaults to 1");
        $display("============================================\n");

        // --------------------------------------------------
        // Test 1: basic parallel-to-serial conversion — send 6'b10_1101
        // --------------------------------------------------
        $display("--- Test 1: basic parallel-to-serial conversion (6'b10_1101) ---");
        send_and_check(6'b10_1101);

        // --------------------------------------------------
        // Test 2: back-to-back transfers — 0x2A then 0x15
        // --------------------------------------------------
        $display("\n--- Test 2: back-to-back transfers (0x2A, 0x15) ---");
        send_and_check(6'h2A);
        send_and_check(6'h15);

        // --------------------------------------------------
        // Test 3: backpressure test — o_dout holds when i_dout_ready=0
        // send 6'b00_1111, receive two bits, then deassert ready for two cycles,
        // verify o_dout unchanged, resume reception after recovery
        // --------------------------------------------------
        $display("\n--- Test 3: backpressure test (i_dout_ready=0 two-cycle stall midway) ---");

        // send data (negedge 0: send, negedge 1: loaded, bit0 ready)
        @(negedge i_clk);
        i_din_valid = 1'b1;
        i_din       = 6'b00_1111;
        @(negedge i_clk);
        i_din_valid = 1'b0;

        // receive bit 0-1
        recv = 6'd0;
        for (k = 0; k < 2; k = k + 1) begin
            recv[k] = o_dout;
            @(negedge i_clk);
        end

        // deassert i_dout_ready, hold for two cycles, verify o_dout unchanged
        i_dout_ready = 1'b0;
        dout_held = o_dout;
        $display("deassert i_dout_ready, o_dout should remain at %b", dout_held);
        repeat (2) begin
            @(negedge i_clk);
            if (o_dout !== dout_held)
                $display("[FAIL] during backpressure o_dout change");
        end

        // reassert i_dout_ready; o_dout still holds bit 2 (DUT has not advanced yet)
        i_dout_ready = 1'b1;
        recv[2] = o_dout;                     // sample bit 2 immediately
        @(negedge i_clk);                     // DUT advances one cycle and outputs bit 3
        for (k = 3; k < 6; k = k + 1) begin
            recv[k] = o_dout;
            @(negedge i_clk);
        end

        if (recv === 6'b00_1111)
            $display("[PASS] backpressure test: Sent=001111 Recv=%b (data intact)", recv);
        else
            $display("[FAIL] backpressure test: Sent=001111 Recv=%b (data corrupted)", recv);

        // ============================================================
        $display("\n============================================");
        $display("Parallel2Serial all tests completed");
        $display("============================================");

        repeat (4) @(posedge i_clk);
        $finish;
    end

endmodule
