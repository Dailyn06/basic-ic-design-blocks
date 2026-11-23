// ============================================================================
// Serial2Parallel (6-bit serial-to-parallel conversion) testbench
// ============================================================================

`timescale 1ns / 1ps

module tb_Serial2Parallel;

    reg         i_clk;
    reg         i_rst_n;
    reg         i_din_valid;
    reg         i_din;
    reg         i_dout_ready;
    wire        o_din_ready;
    wire        o_dout_valid;
    wire [5:0]  o_dout;

    // ---- Instantiate DUT ----
    Serial_Parallel u_dut (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_din_valid  (i_din_valid),
        .i_din        (i_din),
        .i_dout_ready (i_dout_ready),
        .o_din_ready  (o_din_ready),
        .o_dout_valid (o_dout_valid),
        .o_dout       (o_dout)
    );

    // ---- clock ----
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    // ---- Waveform ----
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_Serial2Parallel);
    end

    // ---- Monitor ----
    always @(negedge i_clk) begin
        if (i_rst_n)
            $display("time=%0t | din_vld=%b din=%b din_rdy=%b | dout_vld=%b dout=%b dout_rdy=%b",
                     $time, i_din_valid, i_din, o_din_ready,
                     o_dout_valid, o_dout, i_dout_ready);
    end

    // ---- Task: send one six-bit word ----
    task send_bits;
        input [5:0] data;
        integer i;
        begin
            for (i = 0; i < 6; i = i + 1) begin
                @(negedge i_clk);
                i_din_valid = 1'b1;
                i_din       = data[i];          // LSB first
                @(negedge i_clk);               // wait one cycle to confirm the handshake
            end
            @(negedge i_clk);
            i_din_valid = 1'b0;
        end
    endtask

    // ---- wait for parallel output ----
    task wait_output;
        input [5:0] expected;
        begin
            // wait for o_dout_valid
            while (!o_dout_valid) @(negedge i_clk);
            if (o_dout == expected)
                $display("[PASS] o_dout = %b (expected)", o_dout);
            else
                $display("[FAIL] o_dout = %b, expected %b", o_dout, expected);
            // consume data
            @(negedge i_clk);
            i_dout_ready = 1'b1;
            @(negedge i_clk);
            i_dout_ready = 1'b0;
        end
    endtask

    // ========================================================================
    // test
    // ========================================================================
    initial begin
        i_din_valid  = 1'b0;
        i_din        = 1'b0;
        i_dout_ready = 1'b0;

        // reset
        i_rst_n = 1'b0;
        repeat (2) @(posedge i_clk);
        i_rst_n = 1'b1;
        repeat (2) @(posedge i_clk);

        $display("============================================");
        $display("Serial2Parallel (6-bit) test started");
        $display("============================================\n");

        // --- Test 1: basic serial-to-parallel conversion ---
        $display("--- Test 1: send 6'b10_1101 (MSB..LSB) ---");
        send_bits(6'b10_1101);
        wait_output(6'b10_1101);

        // --- Test 2: all ones ---
        $display("\n--- Test 2: send 6'b11_1111 ---");
        send_bits(6'b11_1111);
        wait_output(6'b11_1111);

        // --- Test 3: all zeros ---
        $display("\n--- Test 3: send 6'b00_0000 ---");
        send_bits(6'b00_0000);
        wait_output(6'b00_0000);

        // --- Test 4: continuous back-to-back transfers ---
        $display("\n--- Test 4: back-to-back transfers 0x2A, 0x15 ---");
        send_bits(6'b10_1010);
        wait_output(6'b10_1010);
        send_bits(6'b01_0101);
        wait_output(6'b01_0101);

        // --- Test 5: downstream busy, test backpressure ---
        $display("\n--- Test 5: downstream not ready, backpressure test ---");
        i_dout_ready = 1'b0;
        send_bits(6'b00_1111);
        // at this point o_dout_valid=1, but i_dout_ready=0, upstream should be stalled
        $display("output data pending... (o_din_ready=%b)", o_din_ready);
        repeat (3) @(negedge i_clk);               // wait 3 cycles
        $display("after waiting three cycles, o_din_ready=%b (expected 0)", o_din_ready);
        // downstream ready, consume data
        @(negedge i_clk);
        i_dout_ready = 1'b1;
        @(negedge i_clk);
        i_dout_ready = 1'b0;
        $display("downstream consumes data: o_dout=%b", o_dout);

        // ============================================================
        $display("\n============================================");
        $display("all tests completed");
        $display("============================================");
        repeat (4) @(posedge i_clk);
        $finish;
    end

endmodule
