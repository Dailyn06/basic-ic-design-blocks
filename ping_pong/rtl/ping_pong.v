// ============================================================================
// Ping-Pong Buffer
// 
// Two banks, each BUF_SIZE words deep, allow reads and writes in separate banks.
// A completed write bank becomes ready for reading; a consumed bank becomes free.
// full_banks tracks readiness: 0 = both empty, 1 = one ready, 2 = both full.
// Reads use a registered output. A full buffer applies write backpressure.
// 
// License: MIT
// ============================================================================

module ping_pong #(
    parameter DATA_WIDTH = 8,
    parameter BUF_SIZE   = 4
)(
    input                           clk,
    input                           rst_n,
    input                           wr_en,
    input  [DATA_WIDTH-1:0]         wr_data,
    output                          wr_full,
    input                           rd_en,
    output [DATA_WIDTH-1:0]         rd_data,
    output                          rd_empty
);

    localparam ADDR_W = $clog2(BUF_SIZE);

    reg [DATA_WIDTH-1:0] buf0 [0:BUF_SIZE-1];
    reg [DATA_WIDTH-1:0] buf1 [0:BUF_SIZE-1];

    reg [ADDR_W:0]  wr_cnt;          // write pointer within the current bank
    reg [ADDR_W:0]  rd_cnt;          // read pointer within the current bank
    reg             wr_bank;         // 0=A, 1=B
    reg             rd_bank;         // read bank
    reg  [1:0]      full_banks;      // ready bank count (0/1/2)

    wire            wr_bank_full = (wr_cnt == BUF_SIZE - 1);   // switch banks when writing the final location

    // ---- Write ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_cnt     <= 0;
            wr_bank    <= 1'b0;
            full_banks <= 2'd0;
        end else if (wr_en && !wr_full) begin
            if (!wr_bank)
                buf0[wr_cnt[ADDR_W-1:0]] <= wr_data;
            else
                buf1[wr_cnt[ADDR_W-1:0]] <= wr_data;

            if (wr_bank_full) begin
                wr_cnt     <= 0;
                wr_bank    <= ~wr_bank;
                full_banks <= full_banks + 1'b1;   // one bank ready
            end else begin
                wr_cnt <= wr_cnt + 1'b1;
            end
        end
    end

    // ---- Read (registered output, avoid reading the wrong address after the read pointer advances) ----
    reg [DATA_WIDTH-1:0] rd_data_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_cnt       <= 0;
            rd_bank      <= 1'b0;
            rd_data_reg  <= 0;
        end else if (rd_en && !rd_empty) begin
            // capture data at the current address first, then increment the pointer
            rd_data_reg <= rd_bank ? buf1[rd_cnt[ADDR_W-1:0]] : buf0[rd_cnt[ADDR_W-1:0]];
            if (rd_cnt == BUF_SIZE - 1) begin
                rd_cnt     <= 0;
                rd_bank    <= ~rd_bank;
                full_banks <= full_banks - 1'b1;
            end else begin
                rd_cnt <= rd_cnt + 1'b1;
            end
        end
    end

    // ---- Output ----
    assign rd_data  = rd_data_reg;
    assign wr_full  = (full_banks == 2'd2);
    assign rd_empty = (full_banks == 2'd0);

endmodule
