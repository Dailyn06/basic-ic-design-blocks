// ============================================================================
// Round-Robin Arbiter (Subtraction Method)
// 
// Uses fix_base_arbiter to find the first request starting at base.
// After each grant, rotate the grant left by one bit to form the next base.
// Reset selects channel 0. The pointer holds when no requests are active.
// CHANNEL sets the number of channels (default: 4). The grant is one-hot.
// 
// License: MIT
// ============================================================================

module round_robin_arbiter #(
    parameter CHANNEL = 4               // number of channels
)(
    input           clk,                // clock
    input           rst_n,              // reset (active low)
    input   [CHANNEL-1:0] req,          // request
    output  [CHANNEL-1:0] grant         // grant (one-hot)
);

    reg  [CHANNEL-1:0] base;            // priority starting point (one-hot)
    wire [CHANNEL-1:0] grant_comb;      // combinational grant

    // ---- Core: reuse fix_base_arbiter for priority selection ----
    fix_base_arbiter #(
        .CHANNEL(CHANNEL)
    ) u_arb (
        .req   (req),
        .base  (base),
        .grant (grant_comb)
    );

    // ---- Advance the round-robin pointer to the bit after the current grant ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            base <= {{CHANNEL-1{1'b0}}, 1'b1};              // Reset: start from the LSB
        else if (|req) begin                                 // advance only when requests are active
            // circular left shift by one bit: grant[bit2→bit3, bit1→bit2, bit0→bit1, bit3→bit0]
            base <= {grant_comb[CHANNEL-2:0],
                      grant_comb[CHANNEL-1]};
        end
    end

    assign grant = grant_comb;

endmodule
