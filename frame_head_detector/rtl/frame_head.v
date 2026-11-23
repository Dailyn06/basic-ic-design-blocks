// ============================================================================
// Frame Header Detector
// 
// Asserts head_vld for one cycle after three consecutive valid 8'h23 bytes.
// A different valid byte resets the match count. Invalid cycles hold the count.
// The count restarts after every group of three matches.
// 
// License: MIT
// ============================================================================

module frame_head(
    input           clk,
    input           rstn,
    input   [7:0]   frame,
    input           frame_vld,
    output          head_vld
);

    // frame header pattern
    localparam HEADER = 8'h23;
    localparam N_MATCH = 2'd3;   // consecutive-match threshold

    // consecutive-match counter (0~3, count to 3 reset to zero)
    reg [1:0] match_cnt, next_match_cnt;

    // ========================================================================
    // Timing
    // ========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn)
            match_cnt <= 2'd0;
        else
            match_cnt <= next_match_cnt;
    end

    // ========================================================================
    // combinational: counting logic
    // ========================================================================
    always @(*) begin
        next_match_cnt = match_cnt;

        if (frame_vld) begin
            if (frame == HEADER) begin
                if (match_cnt == N_MATCH - 1)
                    next_match_cnt = 2'd0;   // three consecutive matches, reset to zero and restart
                else
                    next_match_cnt = match_cnt + 1'd1;
            end else begin
                next_match_cnt = 2'd0;        // sequence interrupted, restart counting
            end
        end
    end

    // ========================================================================
    // Output: pulse for one cycle on the third match
    // ========================================================================
    assign head_vld = frame_vld && (frame == HEADER) && (match_cnt == N_MATCH - 1);

endmodule
