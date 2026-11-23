// ============================================================================
// Data Packet Detector testbench (plain Verilog-2001)
// ============================================================================

`timescale 1ns / 1ps

module tb_data;

    reg         clk;
    reg         rstn;
    reg  [7:0]  din;
    reg         din_vld;
    wire [7:0]  data_cnt;
    wire        data_cnt_vld;
    wire        pkt_err;

    data u_data (
        .clk          (clk),
        .rstn         (rstn),
        .din          (din),
        .din_vld      (din_vld),
        .data_cnt     (data_cnt),
        .data_cnt_vld (data_cnt_vld),
        .pkt_err      (pkt_err)
    );

    // clock
    always #5 clk = ~clk;

    // test variables
    integer i;
    reg [7:0] test_data [0:255];

    // ========================================================================
    // task
    // ========================================================================
    task send_byte;
        input [7:0] b;
        begin
            din     = b;
            din_vld = 1'b1;
            @(posedge clk);
        end
    endtask

    task idle_cycle;
        input integer n;
        begin
            din_vld = 1'b0;
            din     = 8'h00;
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    // send start marker
    task send_start;
        begin
            send_byte(8'hFF);
            send_byte(8'h00);
        end
    endtask

    // send end marker
    task send_end;
        begin
            send_byte(8'hFF);
            send_byte(8'h01);
        end
    endtask

    // ========================================================================
    // main test sequence
    // ========================================================================
    initial begin
        clk     = 0;
        rstn    = 0;
        din     = 8'h00;
        din_vld = 1'b0;

        repeat(5) @(posedge clk);
        rstn = 1;
        repeat(2) @(posedge clk);

        $display("============================================================");
        $display("Data Packet Detector test started");
        $display("============================================================");

        // ================================================================
        // Test 1: basic valid packet n=5
        // ================================================================
        $display("\n--- Test 1: basic valid packet n=5 ---");
        send_start;
        send_byte(8'hAA); send_byte(8'hBB); send_byte(8'hCC);
        send_byte(8'hDD); send_byte(8'hEE);
        send_end;
        idle_cycle(3);

        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 2: empty packet n=0
        // ================================================================
        $display("\n--- Test 2: empty packet n=0 ---");
        send_start;
        // empty payload,  send end marker immediately
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 3: payload contains a single 0xFF (n=3)
        // ================================================================
        $display("\n--- Test 3: payload contains 0xFF (n=3) ---");
        send_start;
        send_byte(8'hAA);
        send_byte(8'hFF);
        send_byte(8'hBB);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 4: payload contains consecutive 0xFF 0xFF (n=4)
        // ================================================================
        $display("\n--- Test 4: two consecutive 0xFF (n=4) ---");
        send_start;
        send_byte(8'hAA);
        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hBB);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 5: payload consists entirely of 0xFF (n=5)
        // ================================================================
        $display("\n--- Test 5: all bytes are 0xFF (n=5) ---");
        send_start;
        send_byte(8'hFF); send_byte(8'hFF); send_byte(8'hFF);
        send_byte(8'hFF); send_byte(8'hFF);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 6: standalone 0x00/0x01 (n=3, valid)
        // ================================================================
        $display("\n--- Test 6: standalone 0x00/0x01 (n=3, valid) ---");
        send_start;
        send_byte(8'h00);
        send_byte(8'hAA);
        send_byte(8'h01);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 7: error - within the payload 0xFF00
        // ================================================================
        $display("\n--- Test 7: within the payload 0xFF00 (pkt_err should =1) ---");
        send_start;
        send_byte(8'hAA);   // data[0]
        send_byte(8'hFF);   // -> WAIT_END
        send_byte(8'h00);   // 0xFF00! pkt_err=1, also resynchronize to IN_DATA
        send_byte(8'hBB);   // new packet data[0]
        send_end;            // end of new packet
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 8: error - invalid start marker
        // ================================================================
        $display("\n--- Test 8: invalid start marker (pkt_err should =1) ---");
        send_byte(8'hFF);
        send_byte(8'hAB);   // other than 0x00 -> pkt_err, IDLE
        idle_cycle(2);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);
        // verify recovery: send a valid packet
        send_start;
        send_byte(8'h55);
        send_end;
        idle_cycle(3);
        $display("-> after recovery: data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 9: consecutive bytes before the start marker 0xFF
        // ================================================================
        $display("\n--- Test 9: consecutive 0xFF followed by start marker ---");
        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'hFF);
        send_byte(8'h00);   // start marker confirmed
        send_byte(8'h12);
        send_byte(8'h34);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 10: two back-to-back packets
        // ================================================================
        $display("\n--- Test 10: two back-to-back packets ---");
        send_start;
        send_byte(8'hA1); send_byte(8'hA2);
        send_end;
        // no idle cycles,  immediately followed by the second packet
        send_start;
        send_byte(8'hB1); send_byte(8'hB2); send_byte(8'hB3);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 11: maximum-length packet n=255
        // ================================================================
        $display("\n--- Test 11: maximum-length packet n=255 ---");
        send_start;
        for (i = 0; i < 255; i = i + 1)
            send_byte(8'hAA);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 12: data stream with idle cycles (n=2)
        // ================================================================
        $display("\n--- Test 12: data stream with idle cycles (n=2) ---");
        send_byte(8'hFF);
        idle_cycle(2);
        send_byte(8'h00);
        idle_cycle(1);
        send_byte(8'h11);
        idle_cycle(3);
        send_byte(8'h22);
        idle_cycle(1);
        send_byte(8'hFF);
        idle_cycle(2);
        send_byte(8'h01);
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // Test 13: oversized packet n=256 (error)
        // ================================================================
        $display("\n--- Test 13: oversized packet n=256 (pkt_err should =1) ---");
        send_start;
        for (i = 0; i < 256; i = i + 1)
            send_byte(8'hAA);
        send_end;
        idle_cycle(3);
        $display("-> data_cnt_vld=%b, data_cnt=%0d, pkt_err=%b",
                 data_cnt_vld, data_cnt, pkt_err);

        // ================================================================
        // end of tests
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
        if (rstn && data_cnt_vld)
            $display("[%0t] *** VALID: data_cnt=%0d ***", $time, data_cnt);
        if (rstn && pkt_err)
            $display("[%0t] *** ERROR ***", $time);
    end

    // ========================================================================
    // Waveform
    // ========================================================================
    initial begin
        $dumpfile("tb_data.vcd");
        $dumpvars(0, tb_data);
    end

endmodule
