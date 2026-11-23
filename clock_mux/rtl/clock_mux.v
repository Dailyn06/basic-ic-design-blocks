// ============================================================================
// Glitch-Free Clock Multiplexer
// 
// Switches between clk0 and clk1 using falling-edge clock enables and
// synchronized feedback. The current clock is disabled before the other is enabled.
// clk_sel selects the source: 0 = clk0, 1 = clk1.
// Reset selects clk0.
// 
// License: MIT
// ============================================================================

module clock_mux (
    input  clk0,
    input  clk1,
    input  rst_n,
    input  clk_sel,          // 0: clk0, 1: clk1
    output clk_out
);

    reg en0, en1;             // enables in their respective clock domains
    reg en0_sync, en1_sync;   // clock-domain synchronization

    // ---- clk0 domain: en0 control ----
    always @(negedge clk0 or negedge rst_n) begin
        if (!rst_n)
            en0 <= 1'b1;                     // Reset selects clk0
        else
            en0 <= !clk_sel && !en1_sync;    // select clk0 and clk1 is disabled
    end

    // ---- clk1 domain: en1 control ----
    always @(negedge clk1 or negedge rst_n) begin
        if (!rst_n)
            en1 <= 1'b0;
        else
            en1 <= clk_sel && !en0_sync;     // select clk1 and clk0 is disabled
    end

    // ---- cross-domain synchronization: en1 → clk0 ----
    reg en1_d1;
    always @(posedge clk0 or negedge rst_n) begin
        if (!rst_n) begin
            en1_d1   <= 1'b0;
            en1_sync <= 1'b0;
        end else begin
            en1_d1   <= en1;
            en1_sync <= en1_d1;
        end
    end

    // ---- cross-domain synchronization: en0 → clk1 ----
    reg en0_d1;
    always @(posedge clk1 or negedge rst_n) begin
        if (!rst_n) begin
            en0_d1   <= 1'b0;
            en0_sync <= 1'b0;
        end else begin
            en0_d1   <= en0;
            en0_sync <= en0_d1;
        end
    end

    // ---- gated clock output ----
    assign clk_out = (en0 && clk0) || (en1 && clk1);

endmodule
