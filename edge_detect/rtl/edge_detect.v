// ============================================================================
// Edge Detector
// 
// Two pipeline registers retain consecutive samples of the input.
// pos_edge detects 0-to-1 transitions; neg_edge detects 1-to-0 transitions.
// both_edge is the XOR of the samples. Each detected edge produces a pulse.
// 
// License: MIT
// ============================================================================

module edge_detect (
    input  clk,
    input  rst_n,
    input  signal,
    output pos_edge,
    output neg_edge,
    output both_edge
);

    reg signal_d1;    // delayed one cycle
    reg signal_d2;    // delayed two cycles

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            signal_d1 <= 1'b0;
            signal_d2 <= 1'b0;
        end else begin
            signal_d1 <= signal;
            signal_d2 <= signal_d1;
        end
    end

    assign pos_edge  = signal_d1 && !signal_d2;    // rising edge: d1=1, d2=0
    assign neg_edge  = !signal_d1 && signal_d2;    // falling edge: d1=0, d2=1
    assign both_edge = signal_d1 ^  signal_d2;     // both edges: d1 XOR d2

endmodule
