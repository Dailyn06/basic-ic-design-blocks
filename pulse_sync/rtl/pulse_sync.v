// ============================================================================
// Pulse Synchronizer (CDC)
// 
// Each source pulse toggles a bit. A two-stage destination synchronizer samples
// that bit, and edge detection reconstructs a destination-domain pulse.
// Allow sufficient spacing for each toggle transition to cross the synchronizer;
// closely spaced source pulses can be lost.
// 
// License: MIT
// ============================================================================

module pulse_sync (
    input  src_clk,       // source clock
    input  src_rst_n,
    input  src_pulse,     // source-domain pulse (one cycle)
    input  dst_clk,       // destination clock
    input  dst_rst_n,
    output dst_pulse      // destination-domain pulse (one cycle)
);

    // ---- source clock domain: pulse → toggle toggle ----
    reg toggle;
    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            toggle <= 1'b0;
        else if (src_pulse)
            toggle <= ~toggle;
    end

    // ---- destination clock domain: two-stage synchronizer ----
    reg toggle_d1, toggle_d2, toggle_d3;
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            toggle_d1 <= 1'b0;
            toggle_d2 <= 1'b0;
            toggle_d3 <= 1'b0;
        end else begin
            toggle_d1 <= toggle;
            toggle_d2 <= toggle_d1;
            toggle_d3 <= toggle_d2;
        end
    end

    // ---- destination clock domain: edge detection to reconstruct pulses ----
    assign dst_pulse = toggle_d2 ^ toggle_d3;

endmodule
