// ============================================================================
// Gray Code Counter
// 
// Configurable-width binary counter with a combinational Gray-code output.
// gray = binary ^ (binary >> 1). Adjacent counts differ by one Gray-code bit,
// including wraparound. inc enables counting.
// 
// License: MIT
// ============================================================================

module gray_counter #(
    parameter WIDTH = 4
)(
    input                   clk,
    input                   rst_n,
    input                   inc,           // increment enable
    output [WIDTH-1:0]      gray,
    output [WIDTH-1:0]      binary
);

    reg [WIDTH-1:0] bin_cnt;

    // ---- Binary counter ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bin_cnt <= {WIDTH{1'b0}};
        else if (inc)
            bin_cnt <= bin_cnt + 1'b1;
    end

    // ---- Binary → Gray (combinational logic) ----
    assign binary = bin_cnt;
    assign gray   = bin_cnt ^ (bin_cnt >> 1);

endmodule
