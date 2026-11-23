// ============================================================================
// div3 (50% duty cycle divide-by-3) testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_div3;

    reg  i_clk;
    reg  i_rst_n;
    wire o_clk;

    // ---- Instantiate DUT ----
    div3 u_dut (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),
        .o_clk   (o_clk)
    );

    // ---- clock: 100MHz (cycle 10ns) ----
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_div3);
    end

    // ---- print each cycle (falling edge) ----
    always @(negedge i_clk) begin
        if (i_rst_n)
            $display("time=%0t | cnt=%0d clk_pos=%b clk_neg=%b o_clk=%b",
                     $time, u_dut.cnt, u_dut.clk_pos, u_dut.clk_neg, o_clk);
    end

    // ========================================================================
    // automatic duty-cycle measurement
    // ========================================================================
    realtime rise_time, fall_time;
    realtime high_width, period;

    always @(posedge o_clk) begin
        if (i_rst_n) begin
            rise_time = $realtime;
            if (fall_time > 0) begin
                period     = rise_time - fall_time + high_width;  // fall→rise + rise→fall
                $display("\n[MEASURE] rising edge @%0t falling edge @%0t", rise_time, fall_time);
            end
        end
    end

    always @(negedge o_clk) begin
        if (i_rst_n) begin
            fall_time  = $realtime;
            high_width = fall_time - rise_time;
            $display("[MEASURE] high pulse width = %.1fns, cycle ≈ %.1fns (3 × 10ns = 30ns), duty cycle ≈ %.0f%%",
                     high_width,
                     high_width / 0.5,
                     high_width / 0.3);
        end
    end

    // ========================================================================
    // test
    // ========================================================================
    initial begin
        i_rst_n = 1'b0;
        #20;
        i_rst_n = 1'b1;

        $display("============================================");
        $display("div3 (50%% duty cycle divide-by-3) test started");
        $display("input clock period: 10ns (100MHz)");
        $display("expected: output period 30ns, high level 15ns (50%%)");
        $display("============================================\n");

        #300;

        $display("\n============================================");
        $display("tests completed");
        $display("============================================");
        #20;
        $finish;
    end

endmodule
