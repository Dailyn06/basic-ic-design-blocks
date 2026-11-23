// ============================================================================
// Sequence Detector (FSM)
// 
// Detects the input sequence "1101" using states IDLE, S1, S11, and S110.
// match is combinational and asserted when state is S110 and din is high.
// After a match the implementation returns to S11 to continue detection.
// 
// License: MIT
// ============================================================================

module seq_detector (
    input  clk,
    input  rst_n,
    input  din,
    output reg match
);

    localparam IDLE = 3'd0;
    localparam S1   = 3'd1;
    localparam S11  = 3'd2;
    localparam S110 = 3'd3;

    reg [2:0] state, next_state;

    // ---- state register ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ---- next state + Output ----
    always @(*) begin
        next_state = state;
        match = 1'b0;

        case (state)
            IDLE: begin
                if (din) next_state = S1;
                else     next_state = IDLE;
            end
            S1: begin
                if (din) next_state = S11;
                else     next_state = IDLE;
            end
            S11: begin
                if (!din) next_state = S110;
                else      next_state = S11;     // hold S11 (consecutive 1)
            end
            S110: begin
                if (din) begin
                    next_state = S11;            // Continue detection from S11 after a match
                    match      = 1'b1;          // detected 1101
                end else
                    next_state = IDLE;           // 1100 → restart
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
