// ============================================================================
// Data Packet Detector
// 
// Packet format: 0xFF00 + payload (fewer than 256 bytes) + 0xFF01.
// The payload must not contain either marker.
// FSM states: IDLE, WAIT_START, IN_DATA, WAIT_END.
// Outputs: data_cnt is the payload byte count; data_cnt_vld marks a valid count.
// pkt_err pulses when an invalid packet is discarded.
// 
// License: MIT
// ============================================================================

module data(
    input           clk,
    input           rstn,
    input   [7:0]   din,
    input           din_vld,
    output  [7:0]   data_cnt,
    output          data_cnt_vld,
    output          pkt_err
);

    localparam CODE_FF = 8'hFF;
    localparam CODE_00 = 8'h00;
    localparam CODE_01 = 8'h01;

    localparam IDLE       = 2'd0;
    localparam WAIT_START = 2'd1;
    localparam IN_DATA    = 2'd2;
    localparam WAIT_END   = 2'd3;

    reg [1:0] state,      next_state;
    reg [7:0] byte_cnt,   next_byte_cnt;
    reg       pkt_err_r,  next_pkt_err;

    // ========================================================================
    // sequential logic
    // ========================================================================
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state     <= IDLE;
            byte_cnt  <= 8'd0;
            pkt_err_r <= 1'b0;
        end else begin
            state     <= next_state;
            byte_cnt  <= next_byte_cnt;
            pkt_err_r <= next_pkt_err;
        end
    end

    // ========================================================================
    // combinational logic: next state, next count, and error flag
    // ========================================================================
    always @(*) begin
        next_state    = state;
        next_byte_cnt = byte_cnt;
        next_pkt_err  = 1'b0;   // no error by default

        case (state)

            // ----------------------------------------------------------------
            // IDLE: wait for start marker 0xFF
            // ----------------------------------------------------------------
            IDLE: begin
                if (din_vld && din == CODE_FF)
                    next_state = WAIT_START;
            end

            // ----------------------------------------------------------------
            // WAIT_START: received 0xFF, wait for 0x00
            // ----------------------------------------------------------------
            WAIT_START: begin
                if (din_vld) begin
                    if (din == CODE_00) begin
                        next_state    = IN_DATA;
                        next_byte_cnt = 8'd0;
                    end else if (din == CODE_FF) begin
                        next_state = WAIT_START;
                    end else begin
                        next_state   = IDLE;
                        next_pkt_err = 1'b1;   // invalid start marker
                    end
                end
            end

            // ----------------------------------------------------------------
            // IN_DATA: collect payload bytes
            // ----------------------------------------------------------------
            IN_DATA: begin
                if (din_vld) begin
                    if (din == CODE_FF) begin
                        next_state = WAIT_END;
                    end else begin
                        if (byte_cnt == 8'd255) begin
                            next_state   = IDLE;
                            next_pkt_err = 1'b1;   // payload too long
                        end else begin
                            next_byte_cnt = byte_cnt + 1'd1;
                        end
                    end
                end
            end

            // ----------------------------------------------------------------
            // WAIT_END: received 0xFF within the payload, inspect the following byte
            // ----------------------------------------------------------------
            WAIT_END: begin
                if (din_vld) begin
                    case (din)
                        CODE_01: begin
                            // valid end marker 0xFF01
                            next_state = IDLE;
                        end

                        CODE_00: begin
                            // 0xFF00 embedded in the payload
                            next_state    = IN_DATA;
                            next_byte_cnt = 8'd0;
                            next_pkt_err  = 1'b1;
                        end

                        CODE_FF: begin
                            // previous 0xFF is payload, current 0xFF pending classification
                            if (byte_cnt == 8'd255) begin
                                next_state   = IDLE;
                                next_pkt_err = 1'b1;   // overflow
                            end else begin
                                next_byte_cnt = byte_cnt + 1'd1;
                                next_state    = WAIT_END;
                            end
                        end

                        default: begin
                            // previous 0xFF is payload, current byte is also payload (+2)
                            if (byte_cnt >= 8'd254) begin
                                next_state   = IDLE;
                                next_pkt_err = 1'b1;   // overflow
                            end else begin
                                next_byte_cnt = byte_cnt + 2'd2;
                                next_state    = IN_DATA;
                            end
                        end
                    endcase
                end
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // ========================================================================
    // Output
    // ========================================================================
    assign data_cnt_vld = (state == WAIT_END) && din_vld && (din == CODE_01);
    assign data_cnt     = byte_cnt;
    assign pkt_err      = pkt_err_r;

endmodule
