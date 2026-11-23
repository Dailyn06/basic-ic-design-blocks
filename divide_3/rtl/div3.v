// ============================================================================
// Divide-by-3 Clock Divider (50% Duty Cycle)
// 
// A modulo-3 counter controls rising-edge and falling-edge registers.
// ORing their outputs produces a high interval of 1.5 input clock periods
// and a low interval of 1.5 input clock periods.
// 
// License: MIT
// ============================================================================

module div3 (
    input  i_clk,       // input clock
    input  i_rst_n,     // reset (active low)
    output o_clk        // Divide-by-3 clock output, 50% duty cycle
);

    reg [1:0] cnt;
    reg       clk_pos;
    reg       clk_neg;

    // ---- modulo 3 counter (rising edge) ----
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            cnt <= 2'd0;
        else if (cnt == 2'd2)
            cnt <= 2'd0;
        else
            cnt <= cnt + 2'd1;
    end

    // ---- rising-edge triggered: cnt=0 set high, cnt=1 set low (pulse width one cycle) ----
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            clk_pos <= 1'b0;
        else if (cnt == 2'd0)
            clk_pos <= 1'b1;
        else
            clk_pos <= 1'b0;
    end

    // ---- falling-edge triggered: same logic, delay 0.5 cycles ----
    always @(negedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            clk_neg <= 1'b0;
        else if (cnt == 2'd0)
            clk_neg <= 1'b1;
        else
            clk_neg <= 1'b0;
    end

    // ---- OR combined output, obtain 50% duty cycle ----
    assign o_clk = clk_pos | clk_neg;

endmodule
