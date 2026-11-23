// ============================================================================
// Round-Robin Arbiter (Prefix-OR Mask Method)
// 
// req_power masks channels already scheduled in the current round.
// Prefix-OR masks select the lowest active request after applying req_power.
// If no masked request remains, selection restarts from the original queue_i.
// sche_en advances the priority mask. DEEP_NUM sets the channel count (default: 8).
// pointer_o is a binary channel index; it is zero when queue_i is empty.
// The subtraction-based alternative returns a one-hot grant instead.
// 
// License: MIT
// ============================================================================

module round_robin_arbiter #(
    parameter DEEP_NUM = 8                          // number of channels
)(
    input  wire                            clk,      // clock
    input  wire                            rst_n,    // reset (active low)
    input  wire [DEEP_NUM        -1 : 0]   queue_i,  // request vector
    input  wire                            sche_en,  // scheduling enable
    output wire [$clog2(DEEP_NUM) - 1 : 0] pointer_o // granted channel binary index
);

    // ---- priority register: initially all ones, after scheduling, mask the granted channel and lower bits ----
    reg  [DEEP_NUM - 1 : 0] req_power;
    wire [DEEP_NUM - 1 : 0] req_after_power = queue_i & req_power;

    // ---- old_mask: prefix-OR of req_after_power ----
    // Build the next mask when requests remain after the current mask.
    // recurrence: old_mask[i] = old_mask[i-1] | req_after_power[i-1]
    // old_mask[0] = 1'b0
    wire [DEEP_NUM - 1 : 0] old_mask =
        {req_after_power[DEEP_NUM - 2 : 0] | old_mask[DEEP_NUM - 2 : 0],
         1'b0};

    // ---- new_mask: prefix-OR of original queue_i ----
    // Fallback mask when req_after_power is empty: restart from queue_i.
    wire [DEEP_NUM - 1 : 0] new_mask =
        {queue_i[DEEP_NUM - 2 : 0] | new_mask[DEEP_NUM - 2 : 0],
         1'b0};

    // ---- whether any requests remain after masking ----
    wire old_grant_work = (|req_after_power);

    // ---- Grant generation ----
    // old_grant: isolate the first set bit in req_after_power
    // new_grant: isolate the first set bit in queue_i (fallback)
    wire [DEEP_NUM - 1 : 0] old_grant = ~old_mask & req_after_power;
    wire [DEEP_NUM - 1 : 0] new_grant = ~new_mask & queue_i;
    wire [DEEP_NUM - 1 : 0] grant     = old_grant_work ? old_grant : new_grant;

    // ---- One-hot → Binary index encoding ----
    function automatic [$clog2(DEEP_NUM) - 1 : 0] onehot_to_index;
        input [DEEP_NUM - 1 : 0] onehot;
        integer i;
        begin
            onehot_to_index = {$clog2(DEEP_NUM){1'b0}};
            for (i = 0; i < DEEP_NUM; i = i + 1) begin
                if (onehot[i])
                    onehot_to_index = i;
            end
        end
    endfunction

    assign pointer_o = (|queue_i) ? onehot_to_index(grant)
                                  : {$clog2(DEEP_NUM){1'b0}};

    // ---- req_power update ----
    // reset: all ones (all channels have equal priority)
    // When sche_en is asserted:
    // if a masked request remains → req_power = old_mask (mask the granted bit and all lower bits)
    // otherwise pending requests require a new arbitration round → req_power = new_mask (rebuild from the original requests)
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            req_power <= {DEEP_NUM{1'b1}};
        end
        else if (sche_en) begin
            if (old_grant_work)
                req_power <= old_mask;
            else if (|queue_i)
                req_power <= new_mask;
        end
    end

endmodule
