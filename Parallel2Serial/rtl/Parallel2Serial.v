// ============================================================================
// Parallel-to-Serial Converter (6-bit)
// 
// Accepts a six-bit parallel word and transmits it LSB first.
// Both interfaces use valid/ready handshakes. Backpressure pauses transmission.
// 
// License: MIT
// ============================================================================

module Parallel2Serial (
    input           i_clk,
    input           i_rst_n,
    input           i_din_valid,
    input   [5:0]   i_din,
    output          o_din_ready,
    input           i_dout_ready,
    output          o_dout_valid,
    output          o_dout
);

    reg [2:0] shift_cnt;      // number of bits transmitted: 0(just load)→1→2→3→4→5→done
    reg [5:0] r_data;
    reg       r_dout_valid;

    assign o_din_ready  = !r_dout_valid;      // new data can be accepted only when idle
    assign o_dout       = r_data[0];          // LSB first
    assign o_dout_valid = r_dout_valid;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_data       <= 6'd0;
            shift_cnt    <= 3'd0;
            r_dout_valid <= 1'b0;
        end
        // accept new data → start transmission
        else if (i_din_valid && o_din_ready) begin
            r_data       <= i_din;
            shift_cnt    <= 3'd0;
            r_dout_valid <= 1'b1;
        end
        // transmitting, downstream ready
        else if (r_dout_valid && i_dout_ready) begin
            if (shift_cnt < 3'd5) begin          // more bits to send (bit1~bit5)
                r_data    <= {1'b0, r_data[5:1]};
                shift_cnt <= shift_cnt + 1'b1;
            end else begin                        // last bit(5) transmission complete
                r_dout_valid <= 1'b0;
            end
        end
    end

endmodule
