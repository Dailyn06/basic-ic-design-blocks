// ============================================================================
// Fixed-Base Priority Arbiter
// 
// Grants the first active request at or above the one-hot base, wrapping around.
// Duplicate req as {req, req}, apply X & ~(X - base), then OR the two halves.
// CHANNEL sets the request count (default: 4). Inputs and output are one-hot
// for base and grant; multiple request bits may be asserted simultaneously.
// 
// License: MIT
// ============================================================================

module fix_base_arbiter #(
    parameter CHANNEL = 4              // number of channels
)(
    input           [CHANNEL-1 : 0]   req,    // request vector (multiple bits may be asserted)
    input           [CHANNEL-1 : 0]   base,   // priority starting point (one-hot)
    output  wire    [CHANNEL-1 : 0]   grant   // grant output (one-hot)
);

    // ---- Duplicate req to enable circular search ----
    // upper bits = req, lower bits = req, to allow searching from base across the boundary
    wire [2 * CHANNEL - 1 : 0] double_req = {req, req};

    // ---- Core algorithm: find the first set bit starting at base ----
    // X & ~(X - base) isolates the first set bit at or above base
    // Subtracting base propagates a borrow up to the first set bit.
    // Invert the subtraction result and AND with X to isolate that bit.
    wire [2 * CHANNEL - 1 : 0] double_gnt = double_req & ~(double_req - base);

    // ---- fold the double-width result back to CHANNEL bits ----
    // upper half OR lower half, because the request may cross the duplication boundary
    assign grant = double_gnt[CHANNEL - 1 : 0]
                 | double_gnt[2 * CHANNEL - 1 : CHANNEL];

endmodule
