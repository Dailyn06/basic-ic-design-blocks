// ============================================================================
// Weighted Round-Robin Arbiter (A:B)
// 
// A single active requester receives the grant directly.
// When both request, grant A for A_ratio cycles, then B for B_ratio cycles.
// With no requests, neither grant is asserted.
// The default weight ratio is 3:1. The counter advances only under contention.
// 
// License: MIT
// ============================================================================

module arbiter#(
    parameter [7:0] A_ratio = 3,       // A channel weight (consecutive grant cycle count)
    parameter [7:0] B_ratio = 1        // B channel weight (consecutive grant cycle count)
)(
    input           clk,                // clock
    input           rst_n,              // reset (active low)
    input           reqA,               // request A
    input           reqB,               // request B
    output reg      grantA,             // grant A
    output reg      grantB              // grant B
);

    // ---- cyclic counter, range 0 ~ A_ratio+B_ratio-1 ----
    reg [7:0] cnt;

    // ========================================================================
    // Grant Output (synchronous reset, rising-edge triggered)
    // ========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            grantA <= 1'b0;
            grantB <= 1'b0;
        end
        else begin
            // only one side requests: grant directly
            if (reqA && !reqB) begin
                grantA <= 1'b1;
                grantB <= 1'b0;
            end
            else if (!reqA && reqB) begin
                grantA <= 1'b0;
                grantB <= 1'b1;
            end
            // both sides request: alternate according to weights
            else if (reqA && reqB) begin
                if (cnt <= A_ratio - 1) begin         // cnt is in the A interval
                    grantA <= 1'b1;
                    grantB <= 1'b0;
                end
                else begin                             // cnt is in the B interval
                    grantA <= 1'b0;
                    grantB <= 1'b1;
                end
            end
            // no requests: no grants
            else begin
                grantA <= 1'b0;
                grantB <= 1'b0;
            end
        end
    end

    // ========================================================================
    // cyclic counter (asynchronous reset)
    // advance only when both requests are asserted, reset to zero at the terminal count
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'b0;
        end
        else if (reqA && reqB) begin
            cnt <= cnt + 1'b1;
            if (cnt == A_ratio + B_ratio - 1) begin   // end of one arbitration cycle
                cnt <= 8'b0;
            end
        end
        else begin
            cnt <= cnt;                                 // hold when there is no contention
        end
    end

endmodule
