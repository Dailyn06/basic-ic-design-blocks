// ============================================================================
// round_robin_arbiter testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_round_arbiter;

    parameter CHANNEL = 4;

    reg                 clk;
    reg                 rst_n;
    reg  [CHANNEL-1:0]  req;
    wire [CHANNEL-1:0]  grant;

    // ---- Instantiate DUT ----
    round_robin_arbiter #(
        .CHANNEL(CHANNEL)
    ) u_dut (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (req),
        .grant (grant)
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

    // Print on each falling edge (signals are stable at this point)
    always @(negedge clk) begin
        if (rst_n)
            $display("time=%0t | req=%b grant=%b", $time, req, grant);
    end

    // ========================================================================
    // helper: update stimulus on falling edges to avoid rising-edge races
    // ========================================================================
    task set_req;
        input [CHANNEL-1:0] val;
        begin
            @(negedge clk);
            req = val;
        end
    endtask

    task do_reset;
        begin
            req   = 4'b0000;
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);             // wait one cycle for rst_n to settle
        end
    endtask

    // ========================================================================
    // test
    // ========================================================================
    initial begin
        do_reset();

        $display("============================================");
        $display("round_robin_arbiter test started (CHANNEL=%0d)", CHANNEL);
        $display("============================================\n");

        // --- Test 1: single request → continuously grant the same channel ---
        $display("--- Test 1: single request req=0010 (should continuously grant=0010) ---");
        set_req(4'b0010);
        repeat (4) @(posedge clk);

        // --- Test 2: all requests active → round-robin grants ---
        $display("\n--- Test 2: all requests active req=1111, check round-robin order ---");
        $display("expected: 0001 → 0010 → 0100 → 1000 →...");
        set_req(4'b1111);
        repeat (8) @(posedge clk);

        // --- Test 3: subset of requests → skip channels with no requests ---
        $display("\n--- Test 3: subset of requests req=1010 ---");
        $display("expected: grant alternates only between 0010 and 1000");
        set_req(4'b1010);
        repeat (6) @(posedge clk);

        // --- Test 4: dynamic request changes ---
        $display("\n--- Test 4: dynamic request changes ---");
        set_req(4'b0000);  repeat (2) @(posedge clk);
        set_req(4'b1111);  repeat (4) @(posedge clk);
        set_req(4'b0101);  repeat (4) @(posedge clk);
        set_req(4'b1111);  repeat (4) @(posedge clk);

        // --- Test 5: switch active channel ---
        $display("\n--- Test 5: alternate single active channel ---");
        set_req(4'b0001);  repeat (2) @(posedge clk);
        set_req(4'b1000);  repeat (2) @(posedge clk);
        set_req(4'b0010);  repeat (2) @(posedge clk);
        set_req(4'b0000);  repeat (2) @(posedge clk);

        // ============================================================
        $display("\n============================================");
        $display("all tests completed");
        $display("============================================");
        repeat (2) @(posedge clk);
        $finish;
    end

    // ========================================================================
    // automatic check: with multiple requests, the same channel should not receive consecutive grants
    // ========================================================================
    reg [CHANNEL-1:0] prev_grant;
    always @(posedge clk) begin
        if (!rst_n)
            prev_grant <= '0;
        else
            prev_grant <= grant;
    end

    always @(posedge clk) begin
        if (rst_n && (grant != '0) && (prev_grant != '0)) begin
            if ( (req & (req - 1)) != '0 ) begin
                if (grant == prev_grant) begin
                    $display("[WARN] time=%0t: with multiple requests, the same channel received consecutive grants grant=%b", $time, grant);
                end
            end
        end
    end

endmodule
