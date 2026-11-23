// ============================================================================
// Serial-to-Parallel Converter (6-bit)
// 
// Collects six serial bits into one parallel word, with valid/ready handshakes.
// Upstream handshake: i_din_valid / o_din_ready.
// Downstream handshake: o_dout_valid / i_dout_ready.
// Bits arrive LSB first: b0, b1, b2, b3, b4, b5.
// The parallel result is {b5, b4, b3, b2, b1, b0}.
// 
// License: MIT
// ============================================================================

module Serial_Parallel (
    input           i_clk,
    input           i_rst_n,
    // ---- Upstream interface (serial input) ----
    input           i_din_valid,
    input           i_din,
    output          o_din_ready,
    // ---- Downstream interface (parallel output) ----
    input           i_dout_ready,
    output          o_dout_valid,
    output  [5:0]   o_dout
);

    reg [2:0] cnt;              // collected bit count (0~5)
    reg [5:0] r_data_out;       // parallel output register
    reg [5:0] r_data_temp;      // shift buffer
    reg       r_dout_valid;     // output valid
    reg       r_din_ready;      // ready to accept new data

    assign o_din_ready  = r_din_ready;
    assign o_dout_valid = r_dout_valid;
    assign o_dout       = r_data_out;

    // ========================================================================
    // Counter: track the number of collected bits
    // ========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            cnt <= 3'd0;
        else if (i_din_valid && o_din_ready) begin
            if (cnt == 3'd5)
                cnt <= 3'd0;
            else
                cnt <= cnt + 1'b1;
        end
    end

    // ========================================================================
    // upstream ready: do not accept new data while downstream is not ready (backpressure)
    // ========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_din_ready <= 1'b0;
        // allow reception when downstream is ready; reject input while an assembled word awaits downstream consumption
        else
            r_din_ready <= i_dout_ready || !r_dout_valid;
    end

    // ========================================================================
    // shift buffer: LSB first, shift each new bit into the most significant position
    // ========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            r_data_temp <= 6'd0;
        else if (i_din_valid && o_din_ready)
            r_data_temp <= {i_din, r_data_temp[5:1]};   // shift right and insert the new bit at the MSB
    end

    // ========================================================================
    // parallel output + valid
    // ========================================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_data_out  <= 6'd0;
            r_dout_valid <= 1'b0;
        end
        // the sixth input bit arrives → output valid
        else if ((cnt == 3'd5) && i_din_valid && o_din_ready) begin
            r_data_out  <= {i_din, r_data_temp[5:1]};
            r_dout_valid <= 1'b1;
        end
        // downstream consumes data → clear valid
        else if (r_dout_valid && i_dout_ready) begin
            r_dout_valid <= 1'b0;
        end
    end

endmodule
