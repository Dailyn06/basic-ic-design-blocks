// ============================================================================
// Frame Header Detector testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_frame_head;

    reg         clk;
    reg         rstn;
    reg  [7:0]  frame;
    reg         frame_vld;
    wire        head_vld;

    frame_head u_frame_head (
        .clk       (clk),
        .rstn      (rstn),
        .frame     (frame),
        .frame_vld (frame_vld),
        .head_vld  (head_vld)
    );

    always #5 clk = ~clk;

    integer i;

    task send_byte(input [7:0] b);
        begin
            frame     = b;
            frame_vld = 1'b1;
            @(posedge clk);
        end
    endtask

    task idle_cycle(input integer n);
        begin
            frame_vld = 1'b0;
            frame     = 8'h00;
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // cleanup between tests: send a byte other than 0x23 to interrupt the match count
    task test_break;
        begin
            send_byte(8'h00);
            idle_cycle(2);
        end
    endtask

    initial begin
        clk      = 0;
        rstn     = 0;
        frame    = 8'h00;
        frame_vld = 1'b0;

        repeat(5) @(posedge clk);
        rstn = 1;
        repeat(2) @(posedge clk);

        $display("============================================================");
        $display("Frame Header Detector test started");
        $display("============================================================");

        // ================================================================
        // Test 1: basic - three consecutive bytes 0x23
        // ================================================================
        $display("\n--- Test 1: three consecutive bytes 0x23 ---");
        send_byte(8'h23);
        send_byte(8'h23);
        send_byte(8'h23);   // third occurrence, should output pulse
        idle_cycle(3);

        // ================================================================
        test_break;

        // ================================================================
        // Test 2: four consecutive bytes 0x23 (third occurrence outputs pulse)
        // ================================================================
        $display("\n--- Test 2: four consecutive bytes 0x23 ---");
        send_byte(8'h23);
        send_byte(8'h23);
        send_byte(8'h23);   // pulse (third occurrence)
        send_byte(8'h23);   // new group: first occurrence
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 3: six consecutive bytes 0x23 (third occurrence, 6 outputs)
        // ================================================================
        $display("\n--- Test 3: six consecutive bytes 0x23 ---");
        send_byte(8'h23);   // new group: second occurrence (continuing the previous group)
        send_byte(8'h23);   // third occurrence (continuing the earlier group) → pulse
        send_byte(8'h23);   // new group: first occurrence
        send_byte(8'h23);   // second occurrence
        send_byte(8'h23);   // third occurrence → pulse
        send_byte(8'h23);   // new group: first occurrence
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 4: interrupt the sequence (2 items + other byte +3 items)
        // ================================================================
        $display("\n--- Test 4: interrupt the sequence ---");
        send_byte(8'h23);   // first occurrence
        send_byte(8'h23);   // second occurrence
        send_byte(8'hAB);   // interrupt! cnt reset to 0
        send_byte(8'h23);   // first occurrence
        send_byte(8'h23);   // second occurrence
        send_byte(8'h23);   // third occurrence → pulse
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 5: consecutive bytes with idle cycles 0x23
        // ================================================================
        $display("\n--- Test 5: with idle cycles (frame_vld=0 do not count when) ---");
        send_byte(8'h23);   // first occurrence
        send_byte(8'h23);   // second occurrence
        idle_cycle(2);      // idle: frame_vld=0, count unchanged
        send_byte(8'h23);   // third occurrence → pulse
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 6: full 3 matches followed immediately by another transfer (back-to-back)
        // ================================================================
        $display("\n--- Test 6: two back-to-back groups ---");
        // first group
        send_byte(8'h23);
        send_byte(8'h23);
        send_byte(8'h23);   // pulse
        // second group, no gap
        send_byte(8'h23);
        send_byte(8'h23);
        send_byte(8'h23);   // pulse
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 7: 1+1+1 nonconsecutive, no output
        // ================================================================
        $display("\n--- Test 7: nonconsecutive 0x23 (no output expected pulse) ---");
        send_byte(8'h23);
        send_byte(8'hAA);
        send_byte(8'h23);
        send_byte(8'hBB);
        send_byte(8'h23);
        send_byte(8'hCC);
        idle_cycle(3);

        test_break;

        // ================================================================
        // Test 8: mixed with other bytes
        // ================================================================
        $display("\n--- Test 8: mixed with other bytes ---");
        send_byte(8'hAA);
        send_byte(8'h23);
        send_byte(8'h23);
        send_byte(8'h23);   // pulse
        send_byte(8'hBB);
        idle_cycle(3);

        // ================================================================
        // End
        // ================================================================
        $display("\n============================================================");
        $display("All tests done.");
        $display("============================================================");
        repeat(5) @(posedge clk);
        $finish;
    end

    // ========================================================================
    // live monitor
    // ========================================================================
    always @(posedge clk) begin
        if (rstn && head_vld)
            $display("[%0t] *** HEAD_VLD pulse ***", $time);
    end

    // print every valid byte (for debugging)
    always @(posedge clk) begin
        if (rstn && frame_vld)
            $display("[%0t] frame=0x%02h", $time, frame);
    end

    initial begin
        $dumpfile("tb_frame_head.vcd");
        $dumpvars(0, tb_frame_head);
    end

endmodule
